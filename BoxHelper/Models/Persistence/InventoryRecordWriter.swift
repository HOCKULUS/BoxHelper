import Foundation
import SwiftData

/// Schreibt ausschließlich betroffene UUIDs. Nutzdatenlöschung und logisches
/// Löschjournal gehören immer zum selben ModelContext-Commit des aufrufenden Stores.
@MainActor
enum InventoryRecordWriter {
    static func synchronize<Value: Identifiable & Equatable, Record: InventoryRecord>(
        _ values: [Value], records: [Record], in context: ModelContext,
        deleteMissing: Bool, writingIDs: Set<UUID>, deletingIDs: Set<UUID>, reindex: Bool,
        startingPosition: Int? = nil, deletionVersions: [UUID: Date] = [:],
        make: (Value, Int) -> Record, update: (Record, Value, Int) -> Void
    ) throws where Value.ID == UUID, Record.Value == Value {
        guard deleteMissing || !writingIDs.isEmpty || !deletingIDs.isEmpty else { return }
        let groups = Dictionary(grouping: records, by: \.id)
        let winners = Dictionary(uniqueKeysWithValues: try InventoryRecordSelection.winners(records).map { ($0.id, $0) })
        let desiredIDs = Set(values.map(\.id))
        let kind = InventoryNativeDeletion.kind(for: Record.self)
        let keys = Array(Set(records.map { $0.id.uuidString }).union(values.map { $0.id.uuidString }).union(deletingIDs.map(\.uuidString)))
        let states = try InventoryDeletionLedger.states(in: context, kind: kind, keys: keys.count > 100 ? nil : keys)
        let active = try InventoryNativeDeletion.active(records, in: context)
        var nextPosition = startingPosition ?? ((active.map(\.position).max() ?? -1) + 1)
        let removals = deletingIDs.union(deleteMissing ? Set(groups.keys).subtracting(desiredIDs) : [])

        for id in removals {
            let group = groups[id] ?? []
            let state = states[id.uuidString] ?? .init()
            if !deletingIDs.contains(id), state.restoredAt > state.deletedAt,
               group.allSatisfy({ InventoryNativeDeletion.revision($0) <= state.deletedAt }) {
                // Eine vollständige Listen-Speicherung darf einen noch ausstehenden
                // Restore nicht löschen, nur weil dessen alte Payload unsichtbar ist.
                // Ein ausdrücklich ausgewählter Delete darf den Restore hingegen überholen.
                continue
            }
            let previous = group.map(InventoryNativeDeletion.revision) + [state.revision]
            let legacy = winners[id].map(InventoryNativeDeletion.isLegacyDeletion) == true
            let alreadyDeleted = state.isDeleted && previous.allSatisfy { $0 <= state.deletedAt }
            let version: Date
            if alreadyDeleted { version = state.deletedAt }
            else if legacy, let winner = winners[id] { version = InventoryNativeDeletion.revision(winner) }
            else { version = deletionVersions[id] ?? InventoryDeletionLedger.nextVersion(after: previous) }
            try InventoryDeletionLedger.recordDeletion(kind: kind, key: id.uuidString, at: version, in: context)
            // SwiftData/CloudKit exportiert eine echte Delete-Operation für jede bekannte
            // physische Zeile. Es bleibt keine geleerte Kiste als Nutzdatenzeile zurück.
            for record in group { context.delete(record) }
        }

        for (desiredPosition, value) in values.enumerated()
        where !deletingIDs.contains(value.id) && (deleteMissing || writingIDs.contains(value.id)) {
            let state = states[value.id.uuidString] ?? .init()
            let group = groups[value.id] ?? []
            let winner = winners[value.id]
            let outdated = winner.map { InventoryNativeDeletion.revision($0) <= state.deletedAt } ?? true
            let restoring = state.isDeleted || winner.map(InventoryNativeDeletion.isLegacyDeletion) == true
                || (state.deletedAt > .distantPast && outdated)
            let position = reindex ? desiredPosition : (winner == nil || restoring ? nextPosition : winner!.position)
            if !reindex && (winner == nil || restoring) { nextPosition += 1 }
            let changed = restoring || winner == nil || winner!.value != value || winner!.position != position
            let previous = group.map(InventoryNativeDeletion.revision) + [state.revision]
            let version = changed ? InventoryDeletionLedger.nextVersion(after: previous) : previous.max()!
            if group.isEmpty {
                let record = make(value, position)
                // Historische DTO-Zeitstempel sind kein neuer Synczeitpunkt. Eine explizite
                // Wiederherstellung muss nach ihrem getrennten Löschjournal liegen.
                if restoring { record.syncChangedAt = version }
                context.insert(record)
            } else {
                for record in group {
                    update(record, value, position)
                    if record.isTombstoned { record.isTombstoned = false }
                    if record.syncChangedAt != version { record.syncChangedAt = version }
                }
            }
            if restoring {
                try InventoryDeletionLedger.recordRestore(kind: kind, key: value.id.uuidString, at: version, in: context)
            }
        }
    }
}

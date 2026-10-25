import Foundation
import SwiftData

/// Gemeinsame Auswahlregeln für native Löschungen und historische Inhalts-Tombstones.
/// Das Journal überlebt die entfernte Nutzdatenzeile; unbekannte Eltern bleiben unbekannt.
enum InventoryNativeDeletion {
    /// Papierkorbfristen beginnen beim bekannten Cloud-Löschzeitpunkt, auch wenn
    /// die App den Delete erst Wochen später empfängt.
    static func trashDates(in context: ModelContext, boxIDs: Set<UUID>? = nil,
                           itemIDs: Set<UUID>? = nil, locationIDs: Set<UUID>? = nil) throws -> [String: Date] {
        var dates: [String: Date] = [:]
        for (kind, selected) in [("box", boxIDs), ("item", itemIDs), ("location", locationIDs)] {
            if let selected, selected.isEmpty { continue }
            let states = try InventoryDeletionLedger.states(in: context, kind: kind, keys: selected.map { $0.map(\.uuidString) })
            for (key, state) in states where state.isDeleted { dates["\(kind):\(key)"] = state.deletedAt }
        }
        return dates
    }
    static func kind<Record: InventoryRecord>(for type: Record.Type) -> String {
        if type == StoredBox.self { return "box" }
        if type == StoredItem.self { return "item" }
        if type == StoredLocation.self { return "location" }
        preconditionFailure("Unbekannter Inventarmodelltyp")
    }

    static func revision<Record: InventoryRecord>(_ record: Record) -> Date {
        max(record.updatedAt, record.syncChangedAt)
    }

    static func isLegacyDeletion<Record: InventoryRecord>(_ record: Record) -> Bool {
        // Ein leerer Inhalt ist kein Löschbeweis: Auch ein bewusst leer importierter
        // und später umsortierter Datensatz kann dieselben Werte besitzen.
        record.isTombstoned
    }

    static func deletedVersions<Record: InventoryRecord>(for records: [Record], in context: ModelContext,
                                                         includeAll: Bool = false,
                                                         including ids: Set<UUID> = []) throws -> [UUID: Date] {
        let keys = Set(records.map { $0.id.uuidString }).union(ids.map(\.uuidString))
        let states = try InventoryDeletionLedger.states(in: context, kind: kind(for: Record.self),
            keys: includeAll || keys.count > 100 ? nil : Array(keys))
        return selectedDeletionVersions(try InventoryRecordSelection.winners(records), states: states)
    }

    static func active<Record: InventoryRecord>(_ records: [Record], in context: ModelContext) throws -> [Record] {
        let keys = Array(Set(records.map { $0.id.uuidString }))
        let states = try InventoryDeletionLedger.states(in: context, kind: kind(for: Record.self), keys: keys.count > 100 ? nil : keys)
        let selected = try InventoryRecordSelection.winners(records)
        let deleted = selectedDeletionVersions(selected, states: states)
        return selected.filter { record in
            guard !isLegacyDeletion(record), deleted[record.id] == nil else { return false }
            // Restore-Journal und Nutzdaten treffen getrennt ein. Ein Restore-Marker
            // allein macht vor der Löschung gespeicherte alte Payloads nicht wieder gültig.
            let cutoff = states[record.id.uuidString]?.deletedAt ?? .distantPast
            return cutoff == .distantPast || revision(record) > cutoff
        }
    }

    private static func selectedDeletionVersions<Record: InventoryRecord>(
        _ selected: [Record], states: [String: InventoryDeletionLedger.State]
    ) -> [UUID: Date] {
        var result: [UUID: Date] = [:]
        for (key, state) in states where state.isDeleted {
            if let id = UUID(uuidString: key) { result[id] = state.deletedAt }
        }
        for record in selected {
            if isLegacyDeletion(record) {
                // Ein älterer Inhaltsmarker darf eine bereits empfangene spätere
                // Wiederherstellung nicht wieder zum logischen Delete erklären.
                if let state = states[record.id.uuidString], state.restoredAt > revision(record) { continue }
                result[record.id] = max(result[record.id] ?? .distantPast, revision(record))
            } else if let deletion = result[record.id], revision(record) > deletion {
                // Eine jüngere, ausdrücklich wiederhergestellte Zeile kann vor ihrem
                // Journal-Ereignis eintreffen. Ihre spätere Version darf bereits gelten.
                result.removeValue(forKey: record.id)
            }
        }
        return result
    }

    static func deletedVersions<Record: InventoryRecord>(for type: Record.Type, ids: Set<UUID>,
                                                         in context: ModelContext) throws -> [UUID: Date] {
        guard !ids.isEmpty else { return [:] }
        let keys = ids.map(\.uuidString)
        let states = try InventoryDeletionLedger.states(in: context, kind: kind(for: type), keys: keys)
        return Dictionary(uniqueKeysWithValues: states.compactMap { key, value in
            guard value.isDeleted, let id = UUID(uuidString: key) else { return nil }
            return (id, value.deletedAt)
        })
    }
}

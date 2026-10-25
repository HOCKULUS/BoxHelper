import Foundation
import SwiftData

/// Zwischen dem UI und dem Datenbank-Actor reisen ausschließlich kopierte Werte.
/// Ein Receipt bezeichnet den zuletzt abgeglichenen lokalen Wert eines Schlüssels.
enum InventoryCloudPreferencesReconciliation {
    struct Receipt: Codable, Sendable {
        var local: Data?
        var remoteVersion: Date?
    }

    struct Value: Sendable, Equatable { var data: Data? }

    struct Input: Sendable {
        var values: [String: Value]
        var receipts: [String: Receipt]
    }

    struct Result: Sendable {
        var receipts: [String: Receipt]
        var apply: [String: Value]
        var encodedReceipts: Data
        var hasChanges: Bool
    }

    /// Derselbe Algorithmus bleibt für isolierte, synchrone Migrationstests nutzbar.
    /// Im laufenden Programm führt ausschließlich der Hintergrund-Actor ihn aus.
    static func reconcile(context: ModelContext, input: Input) throws -> Result {
        try Task.checkCancellation()
        context.autosaveEnabled = false
        let records = try context.fetch(FetchDescriptor<StoredCloudPreference>())
        let grouped = Dictionary(grouping: records, by: \.key)
        let states = try InventoryDeletionLedger.states(in: context, kind: "preference", keys: Array(input.values.keys))
        var remote: [String: StoredCloudPreference] = [:]
        for record in records where input.values[record.key] != nil {
            if let old = remote[record.key], old.updatedAt > record.updatedAt
                || (old.updatedAt == record.updatedAt && (old.isTombstoned
                    || (old.value ?? Data()).lexicographicallyPrecedes(record.value ?? Data()))) { continue }
            remote[record.key] = record
        }

        var next = input.receipts
        var apply: [String: Value] = [:]
        for key in input.values.keys.sorted() {
            guard let capturedValue = input.values[key] else { continue }
            let local = capturedValue.data
            let record = remote[key]
            let matching = grouped[key] ?? []
            let state = states[key]
            // Ein neuer ausdrücklich gesetzter Wert kann vor seinem Restore-Ereignis
            // eintreffen. Nur Zeilen bis zur Löschversion gehören noch zum alten Reset.
            let isDeleted = record?.isTombstoned == true
                || state.map { $0.isDeleted && (record?.updatedAt ?? .distantPast) <= $0.deletedAt } == true
            let awaitsRestoredValue = state.map {
                $0.deletedAt > .distantPast && $0.restoredAt > $0.deletedAt
                    && (record?.updatedAt ?? .distantPast) <= $0.deletedAt
            } == true
            let remoteValue = isDeleted ? nil : record?.value
            if let receipt = input.receipts[key], local != receipt.local {
                let version = InventoryDeletionLedger.nextVersion(after: matching.map(\.updatedAt)
                    + [state?.revision ?? .distantPast, receipt.remoteVersion ?? .distantPast])
                if let local {
                    try store(local, key: key, version: version, matching: matching, context: context)
                } else {
                    try remove(key: key, version: version, matching: matching, context: context)
                }
                next[key] = Receipt(local: local, remoteVersion: version)
            } else if awaitsRestoredValue {
                // Restore-Journal und Werte-Asset reisen getrennt. Alte Zeilen bis
                // zur Löschversion bleiben ungültig, ohne einen neuen Reset zu erzeugen.
                continue
            } else if isDeleted {
                let version = max(state?.deletedAt ?? .distantPast,
                                  record?.isTombstoned == true ? record?.updatedAt ?? .distantPast : .distantPast)
                // Auch spät importierte Duplikate werden nativ entfernt. Der Reset
                // bleibt unabhängig von der Importreihenfolge als kleiner Schlüssel erhalten.
                try remove(key: key, version: version, matching: matching, context: context)
                next[key] = Receipt(local: nil, remoteVersion: version)
                if local != nil { apply[key] = Value(data: nil) }
            } else if let record {
                next[key] = Receipt(local: remoteValue, remoteVersion: record.updatedAt)
                if local != remoteValue { apply[key] = Value(data: remoteValue) }
            } else if let state, state.restoredAt > (input.receipts[key]?.remoteVersion ?? .distantPast) {
                // Restore-Historie und Werte-Asset reisen getrennt. Bis die neuere
                // Inhaltszeile eintrifft, weder den lokalen Standard hochladen noch löschen.
                continue
            } else if input.receipts[key] != nil {
                // Eine echte Cloud-Löschung kann vor ihrer ergänzenden Schlüsselhistorie
                // eintreffen, ebenso kann gerade eine Restore-Payload fehlen. Bis zum
                // eindeutigen Journal weder neu hochladen noch eine Löschung erfinden.
                continue
            } else {
                if let local {
                    let version = InventoryDeletionLedger.nextVersion(after: [state?.revision ?? .distantPast])
                    try store(local, key: key, version: version, matching: [], context: context)
                    next[key] = Receipt(local: local, remoteVersion: version)
                } else { next[key] = Receipt(local: nil, remoteVersion: nil) }
            }
        }

        let encoded = try encodeReceipts(next)
        let hasChanges = context.hasChanges
        do {
            // Ein ausgeschalteter oder zurückgesetzter Abgleich schreibt keine weitere Transaktion.
            try Task.checkCancellation()
            if hasChanges { try context.save() }
        } catch {
            context.rollback()
            throw error
        }
        return Result(receipts: next, apply: apply, encodedReceipts: encoded, hasChanges: hasChanges)
    }

    /// Nur ein ausdrücklich geänderter lokaler Wert hebt einen früheren Reset auf.
    /// Alle lokalen Cloud-Duplikate erhalten dabei dieselbe bestätigte Version.
    private static func store(_ data: Data, key: String, version: Date,
                              matching: [StoredCloudPreference], context: ModelContext) throws {
        try InventoryDeletionLedger.recordRestore(kind: "preference", key: key, at: version, in: context)
        if matching.isEmpty {
            let value = StoredCloudPreference(key: key, value: data)
            value.updatedAt = version
            context.insert(value)
        } else {
            for value in matching {
                value.value = data
                value.isTombstoned = false
                value.updatedAt = version
            }
        }
    }

    private static func remove(key: String, version: Date, matching: [StoredCloudPreference],
                               context: ModelContext) throws {
        try InventoryDeletionLedger.recordDeletion(kind: "preference", key: key, at: version, in: context)
        for value in matching { context.delete(value) }
    }

    static func encodeReceipts(_ receipts: [String: Receipt]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(receipts)
    }
}

/// SwiftData bindet den Context-Executor an dessen Erzeugungsumgebung. Deshalb wird
/// dieser Actor in einem detached Task erzeugt, nicht in einem geerbten UI-Task.
@ModelActor
actor InventoryCloudPreferencesWorker {
    func reconcile(_ input: InventoryCloudPreferencesReconciliation.Input) throws
        -> InventoryCloudPreferencesReconciliation.Result {
        try autoreleasepool {
            try Task.checkCancellation()
            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            return try InventoryCloudPreferencesReconciliation.reconcile(context: context, input: input)
        }
    }

    nonisolated static func reconcile(container: ModelContainer,
                                      input: InventoryCloudPreferencesReconciliation.Input) async throws
        -> InventoryCloudPreferencesReconciliation.Result {
        try await InventoryStoreAccess.shared.perform {
            try await InventoryBackgroundExecution.shared.perform(name: "Inventory Cloud Preferences") {
                let work = Task.detached(priority: .utility) {
                    try Task.checkCancellation()
                    let worker = InventoryCloudPreferencesWorker(modelContainer: container)
                    let result = try await worker.reconcile(input)
                    try Task.checkCancellation()
                    return result
                }
                // Detached Tasks erben den Abbruch nicht automatisch vom aufrufenden UI-Task.
                return try await withTaskCancellationHandler {
                    try await work.value
                } onCancel: { work.cancel() }
            }
        }
    }
}

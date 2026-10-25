import Foundation
import SwiftData

/// Native Löschungen entfernen die Nutzdaten. Dieses getrennte Journal enthält nur
/// logische Schlüssel, damit verspätete UUID-Duplikate und Freigabe-Replays erkannt werden.
/// Keines seiner persistenten Felder überschreibt einen Core-Data-Lebenszyklusnamen.
enum InventoryDeletionLedger {
    struct State: Equatable, Sendable {
        var deletedAt: Date = .distantPast
        var restoredAt: Date = .distantPast
        var isDeleted: Bool { deletedAt > .distantPast && deletedAt >= restoredAt }
        var revision: Date { max(deletedAt, restoredAt) }
    }

    static func states(in context: ModelContext, kind: String, keys: [String]? = nil) throws -> [String: State] {
        let records: [StoredInventoryDeletion]
        if let keys {
            guard !keys.isEmpty else { return [:] }
            records = try context.fetch(FetchDescriptor<StoredInventoryDeletion>(
                predicate: #Predicate { $0.kind == kind && keys.contains($0.logicalKey) }))
        } else {
            records = try context.fetch(FetchDescriptor<StoredInventoryDeletion>(predicate: #Predicate { $0.kind == kind }))
        }
        var result: [String: State] = [:]
        for record in records {
            var state = result[record.logicalKey] ?? State()
            // Beide monotonen Ereignisse separat vereinigen: Eine spätere Wiederherstellung
            // bleibt auch bei anderer Importreihenfolge und physischen Duplikaten erhalten.
            state.deletedAt = max(state.deletedAt, record.deletedAt)
            state.restoredAt = max(state.restoredAt, record.restoredAt)
            result[record.logicalKey] = state
        }
        return result
    }

    static func deletedVersion(kind: String, key: String, in context: ModelContext) throws -> Date? {
        guard let state = try states(in: context, kind: kind, keys: [key])[key], state.isDeleted else { return nil }
        return state.deletedAt
    }

    static func recordDeletion(kind: String, key: String, at version: Date, in context: ModelContext) throws {
        try record(kind: kind, key: key, version: version, restoring: false, in: context)
    }

    static func recordRestore(kind: String, key: String, at version: Date, in context: ModelContext) throws {
        try record(kind: kind, key: key, version: version, restoring: true, in: context)
    }

    static func nextVersion(after previous: [Date], proposed: Date = Date()) -> Date {
        max(proposed, (previous.max() ?? .distantPast).addingTimeInterval(0.001))
    }

    static func draftPhotoKey(_ draftID: UUID, filename: String) -> String { draftID.uuidString + "|" + filename }

    private static func record(kind: String, key: String, version: Date, restoring: Bool, in context: ModelContext) throws {
        let records = try context.fetch(FetchDescriptor<StoredInventoryDeletion>(
            predicate: #Predicate { $0.kind == kind && $0.logicalKey == key }))
        let deletedAt = max(records.map(\.deletedAt).max() ?? .distantPast, restoring ? .distantPast : version)
        let restoredAt = max(records.map(\.restoredAt).max() ?? .distantPast, restoring ? version : .distantPast)
        if records.isEmpty {
            context.insert(StoredInventoryDeletion(kind: kind, logicalKey: key, deletedAt: deletedAt, restoredAt: restoredAt))
        } else {
            for record in records {
                if record.deletedAt != deletedAt { record.deletedAt = deletedAt }
                if record.restoredAt != restoredAt { record.restoredAt = restoredAt }
            }
        }
        // Der Aufrufer speichert Journal und ModelContext.delete gemeinsam atomar.
    }
}

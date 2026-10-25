import Foundation
import SwiftData

/// Der alte Feldname darf nicht über Core Datas KVC-Lesepfad migriert werden: Dort
/// bezeichnet `isDeleted` den internen Status und liefert für gespeicherte Zeilen false.
/// SwiftDatas historische Getter lesen hingegen das gespeicherte fachliche Kennzeichen.
enum InventorySchemaV4Migration {
    private static let capturePrefix = "nativeDeletionMigrationV4:"

    private struct Deletion: Codable {
        let kind: String
        let logicalKey: String
        let deletedAt: Date
    }

    static func captureLegacyDeletions(_ context: ModelContext) throws {
        context.autosaveEnabled = false
        var deletions: [Deletion] = []
        for row in try context.fetch(FetchDescriptor<InventorySchemaV3.StoredBox>()) {
            // Auch vollständig leere Zeilen mit neuer Syncrevision können legitime
            // Nutzdaten nach einer Umsortierung sein. Nur das gespeicherte Flag belegt
            // eine alte Löschung; Form und Zeitstempel allein rechtfertigen sie nicht.
            if row.isDeleted {
                deletions.append(.init(kind: "box", logicalKey: row.id.uuidString,
                                       deletedAt: max(row.updatedAt, row.syncChangedAt)))
            }
        }
        for row in try context.fetch(FetchDescriptor<InventorySchemaV3.StoredItem>()) {
            if row.isDeleted {
                deletions.append(.init(kind: "item", logicalKey: row.id.uuidString,
                                       deletedAt: max(row.updatedAt, row.syncChangedAt)))
            }
        }
        for row in try context.fetch(FetchDescriptor<InventorySchemaV3.StoredLocation>()) {
            if row.isDeleted {
                deletions.append(.init(kind: "location", logicalKey: row.id.uuidString,
                                       deletedAt: max(row.updatedAt, row.syncChangedAt)))
            }
        }
        for row in try context.fetch(FetchDescriptor<InventorySchemaV3.StoredInventoryImage>()) where row.isDeleted {
            deletions.append(.init(kind: "photo", logicalKey: row.filename, deletedAt: row.updatedAt))
        }
        for row in try context.fetch(FetchDescriptor<InventorySchemaV3.StoredFormDraft>()) where row.isDeleted {
            deletions.append(.init(kind: "draft", logicalKey: row.id.uuidString, deletedAt: row.updatedAt))
        }
        for row in try context.fetch(FetchDescriptor<InventorySchemaV3.StoredDraftPhoto>()) where row.isDeleted {
            deletions.append(.init(kind: "draft-photo", logicalKey: row.draftID.uuidString + "|" + row.filename,
                                   deletedAt: row.updatedAt))
        }
        for row in try context.fetch(FetchDescriptor<InventorySchemaV3.StoredCloudPreference>()) where row.isDeleted {
            deletions.append(.init(kind: "preference", logicalKey: row.key, deletedAt: row.updatedAt))
        }

        // Ein kurzer Datenbankmarker überlebt auch einen Prozessabbruch zwischen den
        // beiden Migrationcallbacks. Es gibt keinen globalen, kontextübergreifenden Cache.
        for marker in try context.fetch(FetchDescriptor<InventorySchemaV3.InventoryMigrationMarker>())
            where marker.key.hasPrefix(capturePrefix) {
            context.delete(marker)
        }
        if !deletions.isEmpty {
            let encoded = try JSONEncoder().encode(deletions).base64EncodedString()
            context.insert(InventorySchemaV3.InventoryMigrationMarker(key: capturePrefix + encoded))
        }
        if context.hasChanges { try context.save() }
    }

    static func finishMigration(_ context: ModelContext) throws {
        context.autosaveEnabled = false
        let markers = try context.fetch(FetchDescriptor<InventoryMigrationMarker>())
            .filter { $0.key.hasPrefix(capturePrefix) }
        let deletions = try markers.flatMap { marker -> [Deletion] in
            guard let data = Data(base64Encoded: String(marker.key.dropFirst(capturePrefix.count))) else {
                throw MigrationError.invalidCapture
            }
            return try JSONDecoder().decode([Deletion].self, from: data)
        }
        var histories: [String: [String: StoredInventoryDeletion]] = [:]
        for deletion in deletions {
            if let previous = histories[deletion.kind]?[deletion.logicalKey] {
                previous.deletedAt = max(previous.deletedAt, deletion.deletedAt)
            } else {
                let history = StoredInventoryDeletion(kind: deletion.kind, logicalKey: deletion.logicalKey,
                                                      deletedAt: deletion.deletedAt)
                histories[deletion.kind, default: [:]][deletion.logicalKey] = history
                context.insert(history)
            }
        }

        removeLegacyCopies(try context.fetch(FetchDescriptor<StoredBox>()), kind: "box", context: context,
                           histories: histories, key: { $0.id.uuidString }, version: { max($0.updatedAt, $0.syncChangedAt) })
        removeLegacyCopies(try context.fetch(FetchDescriptor<StoredItem>()), kind: "item", context: context,
                           histories: histories, key: { $0.id.uuidString }, version: { max($0.updatedAt, $0.syncChangedAt) })
        removeLegacyCopies(try context.fetch(FetchDescriptor<StoredLocation>()), kind: "location", context: context,
                           histories: histories, key: { $0.id.uuidString }, version: { max($0.updatedAt, $0.syncChangedAt) })
        removeLegacyCopies(try context.fetch(FetchDescriptor<StoredInventoryImage>()), kind: "photo", context: context,
                           histories: histories, key: { $0.filename }, version: { $0.updatedAt })
        removeLegacyCopies(try context.fetch(FetchDescriptor<StoredFormDraft>()), kind: "draft", context: context,
                           histories: histories, key: { $0.id.uuidString }, version: { $0.updatedAt })
        removeLegacyCopies(try context.fetch(FetchDescriptor<StoredDraftPhoto>()), kind: "draft-photo", context: context,
                           histories: histories, key: { $0.draftID.uuidString + "|" + $0.filename }, version: { $0.updatedAt })
        removeLegacyCopies(try context.fetch(FetchDescriptor<StoredCloudPreference>()), kind: "preference", context: context,
                           histories: histories, key: { $0.key }, version: { $0.updatedAt })
        for marker in markers { context.delete(marker) }
        // Native Löschungen und Schutzverlauf werden gemeinsam bestätigt. Eine neuere
        // explizite Wiederherstellung bleibt erhalten; ältere physische Zwillinge entfallen.
        if context.hasChanges { try context.save() }
    }

    private static func removeLegacyCopies<Record: PersistentModel>(
        _ records: [Record], kind: String, context: ModelContext,
        histories: [String: [String: StoredInventoryDeletion]],
        key: (Record) -> String, version: (Record) -> Date
    ) {
        guard let histories = histories[kind] else { return }
        for record in records {
            guard let history = histories[key(record)] else { continue }
            let changedAt = version(record)
            if changedAt <= history.deletedAt {
                context.delete(record)
            } else {
                history.restoredAt = max(history.restoredAt, changedAt)
            }
        }
    }

    private enum MigrationError: LocalizedError {
        case invalidCapture
        var errorDescription: String? {
            "Die bisherigen Löschkennzeichen konnten nicht sicher übernommen werden. Die Migration wurde abgebrochen."
        }
    }
}

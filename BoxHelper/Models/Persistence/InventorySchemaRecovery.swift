import CoreData
import Foundation
import SwiftData

/// Ein Zwischenbuild kann dieselbe Versionsnummer mit anderen Feldern gespeichert haben.
/// Staged Migration erkennt dessen Checksum nicht. Nur eine geprüfte automatische
/// Migration auf einer Kopie darf in diesem Fall den bestehenden Store ersetzen.
@MainActor
enum InventorySchemaRecovery {
    static func prepareIfNeeded(at url: URL, schema: Schema) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: url, options: [NSReadOnlyPersistentStoreOption: true])
        let versions = [InventorySchemaV1.models, InventorySchemaV2.models, InventorySchemaV3.models, InventorySchemaV4.models]
        if versions.contains(where: { models in
            NSManagedObjectModel.makeManagedObjectModel(for: models)?
                .isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) == true
        }) { return }

        guard let hashes = metadata[NSStoreModelVersionHashesKey] as? [String: Data],
              let destination = NSManagedObjectModel.makeManagedObjectModel(for: InventorySchemaV3.models) else {
            throw RecoveryError.unsupported
        }
        let entities = Set(hashes.keys)
        let required: Set<String> = ["StoredBox", "StoredItem", "StoredLocation", "InventoryMigrationMarker"]
        // Keine fremden Datenbanken und keine neueren Schemata mit zusätzlichen Entitäten
        // durch einen älteren Appstand verkleinern. Entfernte Felder prüft der Wertevergleich.
        guard required.isSubset(of: entities), entities.isSubset(of: Set(destination.entities.compactMap(\.name))) else {
            throw RecoveryError.unsupported
        }

        let directory = url.deletingLastPathComponent().appendingPathComponent("MigrationBackups", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let original = directory.appendingPathComponent("Original", isDirectory: true).appendingPathComponent(url.lastPathComponent)
        let working = directory.appendingPathComponent("Working", isDirectory: true).appendingPathComponent(url.lastPathComponent)
        try FileManager.default.createDirectory(at: original.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: working.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            // Core Datas Kopier-API berücksichtigt WAL, Dateisperren und externe Binärdaten.
            // Einzelnes Kopieren nur der SQLite-Datei könnte bestätigte Daten auslassen.
            try copyStore(from: url, to: original)
            try copyStore(from: original, to: working)
            let before = try InventoryDatabaseContents.capture(at: original, entities: entities)
            // Erst den unveränderten V3-Zustand prüfen. Die anschließende native
            // Löschmigration darf den Originalvergleich nicht als Datenverlust aussehen lassen.
            let recoverySchema = Schema(versionedSchema: InventorySchemaV3.self)
            let preferences = try autoreleasepool {
                let configuration = ModelConfiguration("Inventory", schema: recoverySchema, url: working, cloudKitDatabase: .none)
                // Alle bisherigen Änderungen sind additive Lightweight-Migrationen. Ohne
                // Stufenplan kann Core Data das tatsächlich gespeicherte Quellmodell nutzen.
                let container = try ModelContainer(for: recoverySchema, configurations: configuration)
                let context = ModelContext(container)
                context.autosaveEnabled = false
                _ = try context.fetchCount(FetchDescriptor<InventorySchemaV3.StoredBox>())
                _ = try context.fetchCount(FetchDescriptor<InventorySchemaV3.StoredItem>())
                _ = try context.fetchCount(FetchDescriptor<InventorySchemaV3.StoredLocation>())
                try InventoryDatabaseContents.restoreNilPreferences(in: context, from: original)
                return try InventoryDatabaseContents.capturePlainPreferences(in: context)
            }
            let after = try InventoryDatabaseContents.capture(at: working, entities: entities, matching: before)
            try InventoryDatabaseContents.requireEqual(before, after, plainPreferences: preferences)
            // Auch eine zwischenzeitliche Änderung am Original verhindert das Ersetzen.
            try InventoryDatabaseContents.requireEqual(before, InventoryDatabaseContents.capture(at: url, entities: entities, matching: before))
            try copyStore(from: working, to: url)
            try? FileManager.default.removeItem(at: working.deletingLastPathComponent())
            // Original samt Assets bleibt für eine mögliche Wiederherstellung erhalten.
        } catch {
            throw RecoveryError.failed(error.localizedDescription)
        }
    }

    private static func copyStore(from source: URL, to destination: URL) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
        try coordinator.replacePersistentStore(at: destination,
                                              destinationOptions: [NSPersistentHistoryTrackingKey: true],
                                              withPersistentStoreFrom: source,
                                              sourceOptions: [NSReadOnlyPersistentStoreOption: true, NSPersistentHistoryTrackingKey: true],
                                              ofType: NSSQLiteStoreType)
    }

    private enum RecoveryError: LocalizedError {
        case unsupported, failed(String)
        var errorDescription: String? {
            switch self {
            case .unsupported: "Die vorhandene Datenbank gehört zu einer nicht unterstützten Modellversion. Die Originaldaten bleiben erhalten."
            case .failed(let message): "Die vorhandene Datenbank konnte nicht automatisch übernommen werden. Die Originaldaten bleiben erhalten. \(message)"
            }
        }
    }
}

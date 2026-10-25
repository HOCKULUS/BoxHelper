import CloudKit
import CoreData
import Foundation
import SwiftData

/// Die Initialisierung ist ein ausdrücklich angeforderter Entwicklungsschritt für CloudKit.
/// Release-Builds und normale Appstarts können das Serverschema damit nicht ändern.
@MainActor
enum InventoryCloudDevelopmentSchema {
    static func initializeIfRequested() throws {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-InitializeInventoryCloudKitSchema"),
              CloudSyncPreferences.supportsCloudKit else { return }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BoxHelper.CloudSchema.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        // Core Data muss vollständig freigegeben sein, bevor der Live-SwiftData-Store startet.
        // Die separate SQLite-Datei schützt gleichzeitig alle vorhandenen Inventardaten.
        try autoreleasepool {
            guard let model = NSManagedObjectModel.makeManagedObjectModel(for: InventorySchemaV4.models) else {
                throw InitializationError.invalidModel
            }
            let description = NSPersistentStoreDescription(url: directory.appendingPathComponent("Schema.store"))
            let options = NSPersistentCloudKitContainerOptions(containerIdentifier: CloudSyncPreferences.containerIdentifier)
            options.databaseScope = .private
            description.cloudKitContainerOptions = options
            description.shouldAddStoreAsynchronously = false

            let container = NSPersistentCloudKitContainer(name: "InventorySchemaInitialization", managedObjectModel: model)
            container.persistentStoreDescriptions = [description]
            // Auch nach einem Fehler wird der temporäre Store vor der Freigabe entladen.
            defer {
                for store in container.persistentStoreCoordinator.persistentStores {
                    try? container.persistentStoreCoordinator.remove(store)
                }
            }

            let loadResult = StoreLoadResult()
            container.loadPersistentStores { _, error in loadResult.record(error) }
            try loadResult.requireSuccess()
            try container.initializeCloudKitSchema(options: [])

            // Auf dem Erfolgsweg sollen auch Entladefehler beim Aufrufer ankommen.
            for store in container.persistentStoreCoordinator.persistentStores {
                try container.persistentStoreCoordinator.remove(store)
            }
        }
        #endif
    }

    #if DEBUG
    private enum InitializationError: LocalizedError {
        case invalidModel, storeNotLoaded

        var errorDescription: String? {
            switch self {
            case .invalidModel: "Das Inventarschema konnte nicht für CloudKit erstellt werden."
            case .storeNotLoaded: "Die temporäre Datenbank zur CloudKit-Schemainitialisierung wurde nicht geladen."
            }
        }
    }

    /// Die Core-Data-Completion darf Fehler melden, ohne Actorzustand zu verändern.
    /// Der Lock schützt den Callback auch unter der strikten Swift-6-Concurrencyprüfung.
    private final class StoreLoadResult: @unchecked Sendable {
        private let lock = NSLock()
        private var completed = false
        private var failure: Error?

        func record(_ error: Error?) {
            lock.withLock {
                completed = true
                failure = error
            }
        }

        func requireSuccess() throws {
            let result = lock.withLock { (completed, failure) }
            guard result.0 else { throw InitializationError.storeNotLoaded }
            if let error = result.1 { throw error }
        }
    }
    #endif
}

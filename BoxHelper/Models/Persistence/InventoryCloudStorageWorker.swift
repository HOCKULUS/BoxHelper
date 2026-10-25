import Foundation
import SwiftData

/// Näherungswert der bekannten Sync-Nutzdaten. Zusätzliche serverseitige Metadaten
/// und noch nicht auf dieses Gerät geladene Daten sind darin nicht enthalten.
/// Der Papierkorb und lokale ZIP-Backups gehören ausdrücklich nicht zu diesem Bestand.
@ModelActor
actor InventoryCloudStorageWorker {
    func estimate() throws -> Int {
        try autoreleasepool {
            try Task.checkCancellation()
            let context = ModelContext(modelContainer)
            let inventory = InventorySnapshot(
                boxes: try InventoryNativeDeletion.active(context.fetch(FetchDescriptor<StoredBox>()), in: context).map(\.value),
                items: try InventoryNativeDeletion.active(context.fetch(FetchDescriptor<StoredItem>()), in: context).map(\.value),
                locations: try InventoryNativeDeletion.active(context.fetch(FetchDescriptor<StoredLocation>()), in: context).map(\.value))
            var bytes = 0
            if inventory != .empty { bytes = try JSONEncoder().encode(inventory).count }
            // Kleine Batches begrenzen den Speicher beim Zählen großer Foto-Assets.
            try context.enumerate(FetchDescriptor<StoredInventoryImage>(), batchSize: 25) { image in
                try Task.checkCancellation()
                if !image.isTombstoned { bytes += image.data?.count ?? 0 }
            }
            try context.enumerate(FetchDescriptor<StoredFormDraft>(), batchSize: 25) { draft in
                try Task.checkCancellation()
                if !draft.isTombstoned { bytes += draft.payload?.count ?? 0 }
            }
            try context.enumerate(FetchDescriptor<StoredDraftPhoto>(), batchSize: 25) { photo in
                try Task.checkCancellation()
                if !photo.isTombstoned { bytes += photo.data?.count ?? 0 }
            }
            try context.enumerate(FetchDescriptor<StoredCloudPreference>(), batchSize: 25) { preference in
                try Task.checkCancellation()
                if !preference.isTombstoned { bytes += preference.value?.count ?? 0 }
            }
            return bytes
        }
    }

    @MainActor
    static func load(container: ModelContainer) async throws -> Int {
        try await InventoryStoreAccess.shared.perform {
            try await InventoryBackgroundExecution.shared.perform(name: "Inventory Cloud Storage Size") {
                let task = Task.detached(priority: .utility) {
                    try Task.checkCancellation()
                    let worker = InventoryCloudStorageWorker(modelContainer: container)
                    return try await worker.estimate()
                }
                return try await withTaskCancellationHandler {
                    try await task.value
                } onCancel: { task.cancel() }
            }
        }
    }
}

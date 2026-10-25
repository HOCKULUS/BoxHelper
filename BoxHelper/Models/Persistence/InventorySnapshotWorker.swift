import Foundation
import SwiftData

/// Der Executor wird außerhalb des MainActors erzeugt. SwiftData-Modelle bleiben
/// vollständig in diesem Actor; die UI erhält ausschließlich unveränderliche Wertkopien.
@ModelActor
actor InventorySnapshotWorker {
    func read() throws -> InventoryRemoteSnapshot {
        // Autoreleased SwiftData-/SQLite-Objekte dürfen die Hintergrund-Assertion
        // nicht überleben. Nur die fertigen Sendable-Werte verlassen diesen Pool.
        try autoreleasepool { try readSnapshot() }
    }

    private func readSnapshot() throws -> InventoryRemoteSnapshot {
        try Task.checkCancellation()
        // Ein frischer Context sieht auch spätere Cloud-Importe und Intent-Commits.
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        let boxRows = try context.fetch(FetchDescriptor<StoredBox>())
        try Task.checkCancellation()
        let itemRows = try context.fetch(FetchDescriptor<StoredItem>())
        try Task.checkCancellation()
        let locationRows = try context.fetch(FetchDescriptor<StoredLocation>())
        try Task.checkCancellation()
        let boxes = try InventoryNativeDeletion.active(boxRows, in: context)
        let items = try InventoryNativeDeletion.active(itemRows, in: context)
        let locations = try InventoryNativeDeletion.active(locationRows, in: context)
        return InventoryRemoteSnapshot(
            inventory: InventorySnapshot(boxes: boxes.map(\.value),
                                         items: items.map(\.value),
                                         locations: locations.map(\.value)),
            deletedIDs: InventoryDeletedIDs(boxes: Set(try InventoryNativeDeletion.deletedVersions(for: boxRows, in: context, includeAll: true).keys),
                                           locations: Set(try InventoryNativeDeletion.deletedVersions(for: locationRows, in: context, includeAll: true).keys)),
            integrityCandidates: try InventoryIntegritySelection.candidates(boxes: boxRows, items: itemRows, locations: locationRows, context: context),
            trashDeletionDates: try InventoryNativeDeletion.trashDates(in: context))
    }

    static func load(container: ModelContainer) async throws -> InventoryRemoteSnapshot {
        try await InventoryStoreAccess.shared.perform {
            try await InventoryBackgroundExecution.shared.perform(name: "Inventory Snapshot") {
                let task = Task.detached(priority: .utility) {
                    try Task.checkCancellation()
                    let worker = InventorySnapshotWorker(modelContainer: container)
                    let result = try await worker.read()
                    try Task.checkCancellation()
                    return result
                }
                return try await withTaskCancellationHandler {
                    try await task.value
                } onCancel: { task.cancel() }
            }
        }
    }
}

import Foundation
import Combine

/// Kleiner UI-Adapter: Fehler behalten die Sicherungen im Papierkorb. Erst nach
/// bestätigtem Restore aller Datensätze und Fotos werden die Einträge entfernt.
@MainActor
final class InventoryTrashController: ObservableObject {
    @Published private(set) var entries: [InventoryTrashEntry] = []
    @Published private(set) var photos: [String: Data] = [:]
    @Published private(set) var retentionDays = 30
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    func reload() {
        do {
            let trash = try InventoryPersistence.prepare().trash
            let archive = try trash.read()
            entries = archive.entries.sorted { $0.deletedAt > $1.deletedAt }
            photos = archive.photos
            retentionDays = trash.retentionDays
        } catch { errorMessage = error.localizedDescription }
    }

    func setRetention(_ days: Int) {
        perform { try InventoryPersistence.prepare().trash.setRetentionDays(days) }
    }

    func delete(_ ids: Set<UUID>) {
        perform { try InventoryPersistence.prepare().trash.remove(ids) }
    }

    func restore(_ ids: Set<UUID>) {
        guard !isBusy else { return }
        isBusy = true
        Task { @MainActor in
            defer { isBusy = false; reload() }
            do {
                let store = try InventoryPersistence.prepare()
                try store.trash.cleanup()
                let current = try store.snapshot()
                let archive = try store.trash.read()
                let selection = InventoryTrashRestoration.make(archive: archive, selecting: ids, current: current)
                let documents = store.trash.documents
                let photoPlan = try await Task.detached(priority: .utility) {
                    try InventoryTrashPhotoRestoration.prepare(entries: selection.entries, photos: archive.photos, documents: documents)
                }.value
                let plan = InventoryTrashRestoration.make(archive: archive, selecting: ids, current: current, filenames: photoPlan.names)
                // Rechte vor Dateiarbeit prüfen. Der eigentliche Merge prüft erneut.
                try InventorySharingService.shared.validateChanges(from: current,
                    to: InventoryCommit.merge(plan.inventory).applying(to: current)!)
                let transaction = try await Task.detached(priority: .utility) {
                    try InventoryPhotoTransaction.prepare(photoPlan.changes)
                }.value
                try await transaction.apply(finalCommit: {
                    let activeStore = try InventoryPersistence.prepare()
                    guard activeStore.container === store.container else { throw InventoryCloudSyncError.changing }
                    let remaining = Set(try store.trash.read().entries.map(\.id))
                    guard Set(plan.entries.map(\.id)).isSubset(of: remaining) else { throw InventorySharingError.conflict }
                    // Während der Fotovorbereitung bleiben Formulare bedienbar.
                    // Deren inzwischen geänderte Felder frisch in den Plan übernehmen.
                    let fresh = try store.snapshot()
                    let finalPlan = InventoryTrashRestoration.make(archive: archive, selecting: ids,
                        current: fresh, filenames: photoPlan.names)
                    try InventoryPersistence.mergeInventory(boxes: finalPlan.inventory.boxes,
                        items: finalPlan.inventory.items, locations: finalPlan.inventory.locations)
                    try InventoryCloudMediaStore.restore(photos: photoPlan.photos, container: store.container)
                })
                if !photoPlan.photos.isEmpty { InventoryPersistence.mediaDidChange() }
                try store.trash.remove(Set(plan.entries.map(\.id)))
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action(); reload() }
        catch { errorMessage = error.localizedDescription }
    }
}

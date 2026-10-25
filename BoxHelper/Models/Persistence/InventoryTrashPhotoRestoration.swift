import Foundation

/// Liest Fotos und löst Namenskollisionen außerhalb des MainActors. Gleichnamige
/// neue Dateien behalten ihre Bytes; restaurierte Besitzer erhalten den neuen Namen.
enum InventoryTrashPhotoRestoration {
    struct Plan: Sendable {
        var names: [String: String] = [:]
        var photos: [String: Data] = [:]
        var changes: [InventoryPhotoTransaction.Change] = []
    }

    static func prepare(entries: [InventoryTrashEntry], photos: [String: Data], documents: URL) throws -> Plan {
        var plan = Plan()
        for name in Set(entries.flatMap(\.images)) {
            try Task.checkCancellation()
            guard let bytes = photos[name] else { continue }
            let originalURL = try InventoryDeletionPlan.photoURL(name, documents: documents)
            let existing = try InventoryPhotoFileCoordinator.read(originalURL).data
            let restoredName = existing != nil && existing != bytes
                ? "restored_\(UUID().uuidString).\(originalURL.pathExtension)" : name
            plan.names[name] = restoredName
            plan.photos[restoredName] = bytes
            if restoredName != name || existing != bytes {
                let url = try InventoryDeletionPlan.photoURL(restoredName, documents: documents)
                plan.changes.append(.init(url: url, original: restoredName == name ? existing : nil, replacement: bytes))
            }
        }
        return plan
    }
}

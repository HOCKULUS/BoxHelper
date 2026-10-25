import Foundation

/// Keep existing-item assignment separate from the action that creates a new item in a box.
@MainActor
enum IntentItemAssignment {
    static func assign(item reference: String, to boxReference: String) throws {
        let baseline = try InventoryPersistence.loadItems()
        var items = baseline
        let item = try IntentInventoryLookup.resolve(reference, in: items, name: { $0.name })
        let box = try IntentInventoryLookup.resolve(boxReference, in: try InventoryPersistence.loadBoxes(), name: { $0.name })
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { throw IntentInventoryError.notFound }
        // Both references must resolve before any write; an unchanged assignment is also a success.
        if items[index].box_uuid != box.id {
            items[index].box_uuid = box.id
            try InventoryPersistence.applyItemChanges(from: baseline, to: items)
        }
    }
}

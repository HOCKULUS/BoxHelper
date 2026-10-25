import Foundation

/// Bilderlose Freigaben bekommen eigene DTO-Kopien. Die Originale des Eigentümers
/// behalten ihre Bilder, während CloudKit weder Dateinamen noch Assets erhält.
enum InventoryShareImages {
    static func removing(from inventory: InventorySnapshot) -> InventorySnapshot {
        var result = inventory
        for index in result.boxes.indices {
            let date = result.boxes[index].updatedAt
            result.boxes[index].images = []
            result.boxes[index].updatedAt = date
        }
        for index in result.items.indices {
            let date = result.items[index].updatedAt
            result.items[index].images = []
            result.items[index].updatedAt = date
        }
        for index in result.locations.indices {
            let date = result.locations[index].updatedAt
            result.locations[index].image = ""
            result.locations[index].updatedAt = date
        }
        return result
    }

    static func restoring(in inventory: InventorySnapshot, from original: InventorySnapshot) -> InventorySnapshot {
        var result = inventory
        let boxes = Dictionary(original.boxes.map { ($0.id, $0.images) }, uniquingKeysWith: { _, last in last })
        let items = Dictionary(original.items.map { ($0.id, $0.images) }, uniquingKeysWith: { _, last in last })
        let locations = Dictionary(original.locations.map { ($0.id, $0.image) }, uniquingKeysWith: { _, last in last })
        for index in result.boxes.indices {
            let date = result.boxes[index].updatedAt
            result.boxes[index].images = boxes[result.boxes[index].id] ?? []
            result.boxes[index].updatedAt = date
        }
        for index in result.items.indices {
            let date = result.items[index].updatedAt
            result.items[index].images = items[result.items[index].id] ?? []
            result.items[index].updatedAt = date
        }
        for index in result.locations.indices {
            let date = result.locations[index].updatedAt
            result.locations[index].image = locations[result.locations[index].id] ?? ""
            result.locations[index].updatedAt = date
        }
        return result
    }
}

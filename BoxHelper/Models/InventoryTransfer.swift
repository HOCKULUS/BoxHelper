import Foundation

/// Versioniertes Austauschformat; bewusst von vollständigen Backups unterscheidbar.
struct InventoryTransfer: Codable, Sendable {
    enum Kind: String, Codable, Sendable { case boxes, items, locations, images }
    var format = "BoxHelper.Selection"
    var version = 1
    var kind: Kind
    var boxes: [MovingBox] = []
    var items: [Items] = []
    var locations: [Locations] = []
    var images: [TransferImage] = []

    var count: Int { boxes.count + items.count + locations.count + images.count }
    var imageNames: Set<String> {
        Set(boxes.flatMap(\.images) + items.flatMap(\.images)
            + locations.map(\.image).filter { !$0.isEmpty } + images.map(\.filename))
    }

    mutating func remove(_ id: String) {
        boxes.removeAll { "box-\($0.id)" == id }
        items.removeAll { "item-\($0.id)" == id }
        locations.removeAll { "location-\($0.id)" == id }
        images.removeAll { "image-\($0.filename)" == id }
    }
}

struct TransferImage: Codable, Sendable {
    let filename: String
    let title: String
}

/// Überschreiben ist eine explizite Benutzerentscheidung, unabhängig vom Änderungsdatum.
enum TransferMerge {
    static func apply<T: Identifiable>(_ incoming: [T], to existing: [T], overwrite: Bool) -> [T] {
        var result = existing
        for value in incoming {
            if let index = result.firstIndex(where: { $0.id == value.id }) {
                if overwrite { result[index] = value }
            } else {
                result.append(value)
            }
        }
        return result
    }
}

import Foundation

/// Plant Wiederherstellungen auf dem frischen Bestand. Vorhandene UUIDs und
/// zwischenzeitlich bearbeitete Besitzer werden niemals mit alten Backups ersetzt.
enum InventoryTrashRestoration {
    struct Plan: Sendable {
        let entries: [InventoryTrashEntry]
        let inventory: InventorySnapshot
    }

    static func make(archive: InventoryTrashStore.Archive, selecting ids: Set<UUID>,
                     current: InventorySnapshot, filenames: [String: String] = [:]) -> Plan {
        var entries = archive.entries.filter { ids.contains($0.id) }
        let boxes = Set(entries.compactMap { entry -> UUID? in
            if case .box(let box) = entry.payload { return box.id }; return nil
        })
        // Eine Kiste bringt ihre ebenfalls gelöschten Kinder mit. Einzelne Items
        // bleiben auch ohne ihre frühere Kiste ausdrücklich wiederherstellbar.
        entries.append(contentsOf: archive.entries.filter { entry in
            guard !ids.contains(entry.id), case .item(let item) = entry.payload else { return false }
            return item.box_uuid.map(boxes.contains) == true
        })
        var result = InventorySnapshot.empty
        for entry in entries {
            switch entry.payload {
            case .location(var value) where !current.locations.contains(where: { $0.id == value.id }):
                value.image = filenames[value.image] ?? value.image
                result.locations.append(value)
            case .box(var value) where !current.boxes.contains(where: { $0.id == value.id }):
                value.images = value.images.map { filenames[$0] ?? $0 }
                result.boxes.append(value)
            case .item(var value) where !current.items.contains(where: { $0.id == value.id }):
                value.images = value.images.map { filenames[$0] ?? $0 }
                result.items.append(value)
            default: break
            }
        }
        let locationIDs = Set(current.locations.map(\.id) + result.locations.map(\.id))
        let boxIDs = Set(current.boxes.map(\.id) + result.boxes.map(\.id))
        for index in result.boxes.indices {
            if let parent = result.boxes[index].location_uuid, !locationIDs.contains(parent) {
                result.boxes[index].location_uuid = nil
                result.boxes[index].category = ""
            }
        }
        for index in result.items.indices {
            if let parent = result.items[index].box_uuid, !boxIDs.contains(parent) { result.items[index].box_uuid = nil }
        }
        for entry in entries {
            guard case .image(let original, let links) = entry.payload else { continue }
            let name = filenames[original] ?? original
            for link in links {
                switch link.owner {
                case .box(let id):
                    if !result.boxes.contains(where: { $0.id == id }), let owner = current.boxes.first(where: { $0.id == id }) {
                        result.boxes.append(owner)
                    }
                    if let index = result.boxes.firstIndex(where: { $0.id == id }), !result.boxes[index].images.contains(name) {
                        result.boxes[index].images.insert(name, at: min(link.index, result.boxes[index].images.count))
                    }
                case .item(let id):
                    if !result.items.contains(where: { $0.id == id }), let owner = current.items.first(where: { $0.id == id }) {
                        result.items.append(owner)
                    }
                    if let index = result.items.firstIndex(where: { $0.id == id }), !result.items[index].images.contains(name) {
                        result.items[index].images.insert(name, at: min(link.index, result.items[index].images.count))
                    }
                case .location(let id):
                    if !result.locations.contains(where: { $0.id == id }), let owner = current.locations.first(where: { $0.id == id }) {
                        result.locations.append(owner)
                    }
                    if let index = result.locations.firstIndex(where: { $0.id == id }), result.locations[index].image.isEmpty {
                        result.locations[index].image = name
                    }
                }
            }
        }
        return Plan(entries: entries, inventory: result)
    }
}

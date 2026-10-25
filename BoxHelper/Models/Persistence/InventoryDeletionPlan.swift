import Foundation

/// Ein Löschauftrag verändert nur seine ausgewählten UUIDs und bekannte Kinder.
/// Fotos ohne Bezug zu diesem Auftrag bleiben als eigenständige Dateien erhalten.
struct InventoryDeletionPlan: Sendable {
    enum PhotoOwner: Sendable { case box(UUID), item(UUID), location(UUID) }

    enum Request: Sendable {
        case boxes(Set<UUID>, onlyIfEmpty: Bool, deletePhotos: Bool)
        case items(Set<UUID>)
        case locations(Set<UUID>)
        case photo(PhotoOwner, filename: String, index: Int?)
    }

    let before: InventorySnapshot
    let after: InventorySnapshot
    let photos: Set<String>

    static func make(_ request: Request, from before: InventorySnapshot) throws -> Self? {
        var after = before
        var photos = Set<String>()
        switch request {
        case .boxes(let ids, let onlyIfEmpty, let deletePhotos):
            let children = before.items.filter { $0.box_uuid.map(ids.contains) == true }
            guard !onlyIfEmpty || children.isEmpty else { return nil }
            if deletePhotos {
                photos.formUnion(before.boxes.filter { ids.contains($0.id) }.flatMap(\.images))
                photos.formUnion(children.flatMap(\.images))
            }
            after.boxes.removeAll { ids.contains($0.id) }
            after.items.removeAll { $0.box_uuid.map(ids.contains) == true }
        case .items(let ids):
            photos.formUnion(before.items.filter { ids.contains($0.id) }.flatMap(\.images))
            after.items.removeAll { ids.contains($0.id) }
        case .locations(let ids):
            let occupied = Set(before.boxes.compactMap(\.location_uuid))
            let unused = ids.subtracting(occupied)
            photos.formUnion(before.locations.filter { unused.contains($0.id) }.map(\.image).filter { !$0.isEmpty })
            after.locations.removeAll { unused.contains($0.id) }
        case .photo(let owner, let name, let index):
            // Der Detailbutton löst nur seine eigene Referenz. Andere Besitzer
            // behalten dasselbe Foto, auch wenn es mehrfach importiert wurde.
            switch owner {
            case .box(let id):
                if let ownerIndex = after.boxes.firstIndex(where: { $0.id == id }) {
                    let remaining = try removingReference(name, at: index, from: after.boxes[ownerIndex].images)
                    if remaining != after.boxes[ownerIndex].images { after.boxes[ownerIndex].images = remaining }
                }
            case .item(let id):
                if let ownerIndex = after.items.firstIndex(where: { $0.id == id }) {
                    let remaining = try removingReference(name, at: index, from: after.items[ownerIndex].images)
                    if remaining != after.items[ownerIndex].images { after.items[ownerIndex].images = remaining }
                }
            case .location(let id):
                if let ownerIndex = after.locations.firstIndex(where: { $0.id == id }), after.locations[ownerIndex].image == name {
                    after.locations[ownerIndex].image = ""
                }
            }
            // Ein ImageDetail-Binding kann die Referenz bereits gespeichert haben.
            // Trotzdem den konkreten Kandidaten global auf weitere Besitzer prüfen.
            return Self(before: before, after: after, photos: [name])
        }
        return before == after ? nil : Self(before: before, after: after, photos: photos)
    }

    private static func removingReference(_ name: String, at index: Int?, from images: [String]) throws -> [String] {
        var result = images
        if let index {
            guard result.indices.contains(index), result[index] == name else { throw InventoryPhotoFileCoordinator.Failure.changed(name) }
            result.remove(at: index)
        } else if let index = result.firstIndex(of: name) { result.remove(at: index) }
        return result
    }

    static func removingPhoto(_ name: String, from inventory: InventorySnapshot) -> Self {
        let normalized = name.lowercased()
        var after = inventory
        for index in after.boxes.indices where after.boxes[index].images.contains(where: { $0.lowercased() == normalized }) {
            after.boxes[index].images.removeAll { $0.lowercased() == normalized }
        }
        for index in after.items.indices where after.items[index].images.contains(where: { $0.lowercased() == normalized }) {
            after.items[index].images.removeAll { $0.lowercased() == normalized }
        }
        for index in after.locations.indices where after.locations[index].image.lowercased() == normalized {
            after.locations[index].image = ""
        }
        return Self(before: inventory, after: after, photos: [name])
    }

    static func photoReferences(in inventory: InventorySnapshot) -> Set<String> {
        Set((inventory.boxes.flatMap(\.images) + inventory.items.flatMap(\.images)
            + inventory.locations.map(\.image)).filter { !$0.isEmpty }.map { $0.lowercased() })
    }

    static func photoURL(_ name: String, documents: URL) throws -> URL {
        let url = documents.appendingPathComponent(name)
        guard !name.isEmpty, name == URL(fileURLWithPath: name).lastPathComponent,
              ["jpg", "jpeg", "png", "heic", "heif", "gif", "tif", "tiff", "bmp", "webp"].contains(url.pathExtension.lowercased()),
              !name.hasPrefix("create_draft_"), !name.hasPrefix("create_item_draft_"),
              url.resolvingSymlinksInPath().deletingLastPathComponent() == documents.resolvingSymlinksInPath() else {
            throw InventoryPhotoFileCoordinator.Failure.unsafeFile(name)
        }
        return url
    }
}

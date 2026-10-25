import Foundation
import SwiftData

/// Unveränderte historische Modellkopie: Feldnamen, Defaults und Attribute gehören
/// zum ausgelieferten Checksum. Die reservierte Eigenschaft wird nur hier gelesen.
enum InventorySchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [StoredBox.self, StoredItem.self, StoredLocation.self, InventoryMigrationMarker.self, StoredInventoryImage.self]
    }

    @Model
    final class StoredBox {
        var id: UUID = UUID()
        var position: Int = 0
        var name: String = ""
        var items: [String] = []
        var images: [String] = []
        var category: String = ""
        var location_uuid: UUID?
        var color: String = ""
        var tags: [String]?
        var notes: String?
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        // Löschungen und Syncversion bleiben unabhängig von historischen DTO-Zeitstempeln erhalten.
        var isDeleted: Bool = false
        var syncChangedAt: Date = Date.distantPast

        init(_ value: MovingBox, position: Int) {
            id = value.id
            self.position = position
            name = value.name
            items = value.items
            images = value.images
            category = value.category
            location_uuid = value.location_uuid
            color = value.color
            tags = value.tags
            notes = value.notes
            createdAt = value.createdAt
            updatedAt = value.updatedAt
            syncChangedAt = value.updatedAt
        }

        func update(from value: MovingBox, position: Int) {
            guard self.position != position || self.value != value else { return }
            self.position = position
            name = value.name
            items = value.items
            images = value.images
            category = value.category
            location_uuid = value.location_uuid
            color = value.color
            tags = value.tags
            notes = value.notes
            createdAt = value.createdAt
            updatedAt = value.updatedAt
        }

        var value: MovingBox {
            var result = MovingBox(id: id, name: name, items: items, images: images, category: category, location_uuid: location_uuid, color: color, tags: tags, notes: notes, createdAt: createdAt, updatedAt: updatedAt)
            // Auch explizites nil bleibt erhalten; DTO-Initialisierer setzen sonst leere Tags.
            result.tags = tags
            result.updatedAt = updatedAt
            return result
        }

        /// Der UUID-Tombstone benötigt keine gelöschten Namen, Notizen oder Bildreferenzen.
        func eraseContent() {
            if !name.isEmpty { name = "" }
            if !items.isEmpty { items = [] }
            if !images.isEmpty { images = [] }
            if !category.isEmpty { category = "" }
            if location_uuid != nil { location_uuid = nil }
            if !color.isEmpty { color = "" }
            if tags != nil { tags = nil }
            if notes != nil { notes = nil }
        }
    }

    @Model
    final class StoredItem {
        var id: UUID = UUID()
        var position: Int = 0
        var name: String = ""
        var box_uuid: UUID?
        var itemDescription: String?
        var images: [String] = []
        var category: String = ""
        var isFragile: Bool = false
        var isHeavy: Bool = false
        var tags: [String]?
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        // Löschungen und Syncversion bleiben unabhängig von historischen DTO-Zeitstempeln erhalten.
        var isDeleted: Bool = false
        var syncChangedAt: Date = Date.distantPast

        init(_ value: Items, position: Int) {
            id = value.id
            self.position = position
            name = value.name
            box_uuid = value.box_uuid
            itemDescription = value.description
            images = value.images
            category = value.category
            isFragile = value.isFragile
            isHeavy = value.isHeavy
            tags = value.tags
            createdAt = value.createdAt
            updatedAt = value.updatedAt
            syncChangedAt = value.updatedAt
        }

        func update(from value: Items, position: Int) {
            guard self.position != position || self.value != value else { return }
            self.position = position
            name = value.name
            box_uuid = value.box_uuid
            itemDescription = value.description
            images = value.images
            category = value.category
            isFragile = value.isFragile
            isHeavy = value.isHeavy
            tags = value.tags
            createdAt = value.createdAt
            updatedAt = value.updatedAt
        }

        var value: Items {
            var result = Items(id: id, name: name, box_uuid: box_uuid, description: itemDescription, images: images, category: category, isFragile: isFragile, isHeavy: isHeavy, tags: tags, createdAt: createdAt, updatedAt: updatedAt)
            // Auch explizites nil bleibt erhalten; DTO-Initialisierer setzen sonst leere Tags.
            result.tags = tags
            result.updatedAt = updatedAt
            return result
        }

        /// Nur die Identität und Versionsmetadaten bleiben für spätere Offline-Abgleiche erhalten.
        func eraseContent() {
            if !name.isEmpty { name = "" }
            if box_uuid != nil { box_uuid = nil }
            if itemDescription != nil { itemDescription = nil }
            if !images.isEmpty { images = [] }
            if !category.isEmpty { category = "" }
            if isFragile { isFragile = false }
            if isHeavy { isHeavy = false }
            if tags != nil { tags = nil }
        }
    }

    @Model
    final class StoredLocation {
        var id: UUID = UUID()
        var position: Int = 0
        var name: String = ""
        var color: String = ""
        var image: String = ""
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        // Löschungen und Syncversion bleiben unabhängig von historischen DTO-Zeitstempeln erhalten.
        var isDeleted: Bool = false
        var syncChangedAt: Date = Date.distantPast

        init(_ value: Locations, position: Int) {
            id = value.id
            self.position = position
            name = value.name
            color = value.color
            image = value.image
            createdAt = value.createdAt
            updatedAt = value.updatedAt
            syncChangedAt = value.updatedAt
        }

        func update(from value: Locations, position: Int) {
            guard self.position != position || self.value != value else { return }
            self.position = position
            name = value.name
            color = value.color
            image = value.image
            createdAt = value.createdAt
            updatedAt = value.updatedAt
        }

        var value: Locations {
            Locations(id: id, name: name, color: color, image: image, createdAt: createdAt, updatedAt: updatedAt)
        }

        /// Gelöschte Standortinhalte werden durch einen minimalen UUID-Tombstone ersetzt.
        func eraseContent() {
            if !name.isEmpty { name = "" }
            if !color.isEmpty { color = "" }
            if !image.isEmpty { image = "" }
        }
    }

    @Model
    final class StoredInventoryImage {
        var filename: String = ""
        @Attribute(.externalStorage) var data: Data? = nil
        var updatedAt: Date = Date.distantPast
        var isDeleted: Bool = false

        init(filename: String, data: Data?, updatedAt: Date = Date(), isDeleted: Bool = false) {
            self.filename = filename
            self.data = isDeleted ? nil : data
            self.updatedAt = updatedAt
            self.isDeleted = isDeleted
        }
    }

    @Model
    final class InventoryMigrationMarker {
        var key: String = ""
        var completedAt: Date = Date()

        init(key: String) {
            self.key = key
            completedAt = Date()
        }
    }
}

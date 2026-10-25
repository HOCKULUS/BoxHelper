import Foundation
import SwiftData

/// Unveränderliche Kopie des bereits ausgelieferten Schemas. Auch Constraints und
/// fehlende Defaultwerte gehören zum V1-Checksum und dürfen nicht angepasst werden.
enum InventorySchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [StoredBox.self, StoredItem.self, StoredLocation.self, InventoryMigrationMarker.self]
    }

    @Model
    final class StoredBox {
        @Attribute(.unique) var id: UUID
        var position: Int
        var name: String
        var items: [String]
        var images: [String]
        var category: String
        var location_uuid: UUID?
        var color: String
        var tags: [String]?
        var notes: String?
        var createdAt: Date
        var updatedAt: Date

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
    }

    @Model
    final class StoredItem {
        @Attribute(.unique) var id: UUID
        var position: Int
        var name: String
        var box_uuid: UUID?
        var itemDescription: String?
        var images: [String]
        var category: String
        var isFragile: Bool
        var isHeavy: Bool
        var tags: [String]?
        var createdAt: Date
        var updatedAt: Date

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
    }

    @Model
    final class StoredLocation {
        @Attribute(.unique) var id: UUID
        var position: Int
        var name: String
        var color: String
        var image: String
        var createdAt: Date
        var updatedAt: Date

        init(_ value: Locations, position: Int) {
            id = value.id
            self.position = position
            name = value.name
            color = value.color
            image = value.image
            createdAt = value.createdAt
            updatedAt = value.updatedAt
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
    }

    @Model
    final class InventoryMigrationMarker {
        @Attribute(.unique) var key: String
        var completedAt: Date

        init(key: String) {
            self.key = key
            completedAt = Date()
        }
    }
}

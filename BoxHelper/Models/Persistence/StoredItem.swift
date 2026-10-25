import Foundation
import SwiftData

/// CloudKit verlangt Defaultwerte und unterstützt keine Unique-Constraints.
/// Persistente Felder; Formulare und Austauschdateien verwenden weiterhin Items als Wertkopie.
@Model
final class StoredItem: InventoryRecord {
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
    // Nur historische Übergangszeilen tragen dieses sichere Fachkennzeichen.
    // Neue Löschungen entfernen die Zeile nativ und schreiben den getrennten Verlauf.
    var isTombstoned: Bool = false
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

import Foundation
import SwiftData

/// CloudKit verlangt Defaultwerte und unterstützt keine Unique-Constraints.
/// Persistente Felder; Formulare und Austauschdateien verwenden weiterhin MovingBox als Wertkopie.
@Model
final class StoredBox: InventoryRecord {
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
    // Nur historische Übergangszeilen tragen dieses sichere Fachkennzeichen.
    // Neue Löschungen entfernen die Zeile nativ und schreiben den getrennten Verlauf.
    var isTombstoned: Bool = false
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

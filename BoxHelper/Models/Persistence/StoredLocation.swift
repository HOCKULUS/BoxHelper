import Foundation
import SwiftData

/// CloudKit verlangt Defaultwerte und unterstützt keine Unique-Constraints.
/// Persistente Felder; Formulare und Austauschdateien verwenden weiterhin Locations als Wertkopie.
@Model
final class StoredLocation: InventoryRecord {
    var id: UUID = UUID()
    var position: Int = 0
    var name: String = ""
    var color: String = ""
    var image: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    // Nur historische Übergangszeilen tragen dieses sichere Fachkennzeichen.
    // Neue Löschungen entfernen die Zeile nativ und schreiben den getrennten Verlauf.
    var isTombstoned: Bool = false
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

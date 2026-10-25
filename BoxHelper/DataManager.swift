import Foundation

/// Normalisiert sehr alte Kisten auch beim Wiederherstellen eines JSON-/ZIP-Backups.
/// Die Umwandlung erfolgt ausschließlich an Wertkopien, bevor SwiftData etwas speichert.
enum DataManager {
    static func normalized(_ inventory: InventorySnapshot,
                           repairMissingLocations: Bool = true) -> InventorySnapshot {
        var result = inventory
        // Der normale SwiftData-Bestand ist bereits migriert. Insbesondere darf eine
        // leere Legacy-Itemliste nicht erneut sämtliche Items jeder Kiste durchsuchen.
        for index in result.boxes.indices where !result.boxes[index].items.isEmpty
            || (result.boxes[index].location_uuid == nil && !result.boxes[index].category.isEmpty) {
            var box = result.boxes[index]
            let originalUpdatedAt = box.updatedAt

            // Gleiche Namen in unterschiedlichen Kisten sind unterschiedliche Gegenstände.
            // Bereits migrierte Einträge werden nur innerhalb derselben Kiste wiederverwendet.
            var remainingItems = box.items.isEmpty ? [] : result.items.filter { $0.box_uuid == box.id }
            for name in box.items {
                if let existing = remainingItems.firstIndex(where: { $0.name == name }) {
                    remainingItems.remove(at: existing)
                } else {
                    result.items.append(Items(id: UUID(), name: name, box_uuid: box.id,
                                              category: box.category, createdAt: box.createdAt,
                                              updatedAt: originalUpdatedAt))
                }
            }
            box.items = []

            // Leere alte Kategorien erzeugen keinen künstlichen Standort.
            if box.location_uuid == nil, !box.category.isEmpty {
                if let location = result.locations.first(where: { $0.name == box.category }) {
                    box.location_uuid = location.id
                } else {
                    let location = Locations(id: UUID(), name: box.category, color: box.color,
                                             image: "", createdAt: box.createdAt, updatedAt: originalUpdatedAt)
                    result.locations.append(location)
                    box.location_uuid = location.id
                }
                box.category = ""
            }
            // Eine Strukturmigration ist keine Bearbeitung durch den Benutzer.
            box.updatedAt = originalUpdatedAt
            result.boxes[index] = box
        }

        // Historische Bestände dürfen fehlende Standorte reparieren. Bei laufendem Cloud-Sync
        // können Kiste und Standort zeitversetzt eintreffen; dort bleiben Referenzen unverändert.
        if repairMissingLocations {
            let knownIDs = Set(result.locations.map(\.id))
            let missingIDs = Set(result.boxes.compactMap(\.location_uuid)).subtracting(knownIDs)
            for id in missingIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
                let box = result.boxes.first { $0.location_uuid == id }!
                result.locations.append(Locations(id: id, name: String(id.uuidString.prefix(6)), color: box.color,
                                                  image: "", createdAt: box.createdAt, updatedAt: box.updatedAt))
            }
        }
        return result
    }
}

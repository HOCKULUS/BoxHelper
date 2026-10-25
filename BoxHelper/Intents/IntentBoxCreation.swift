import Foundation

/// Siri und Kurzbefehle prüfen alle Eingaben und speichern neu erzeugte Objekte atomar.
@MainActor
enum IntentBoxCreation {
    static func location(_ reference: String, in locations: inout [Locations]) throws -> Locations {
        let reference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = try IntentInventoryLookup.existingOrNewName(reference, in: locations, name: { $0.name }) {
            return existing
        }
        let location = Locations(id: UUID(), name: reference, image: "")
        locations.append(location)
        return location
    }

    static func create(name: String, location reference: String, itemNames: [String]) throws -> UUID {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let names = itemNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !name.isEmpty, names.allSatisfy({ !$0.isEmpty }) else { throw IntentInventoryError.emptyName }
        let snapshot = try InventoryPersistence.snapshot()
        var locations = snapshot.locations
        let location = try location(reference, in: &locations)
        let box = MovingBox(id: UUID(), name: name, items: [], images: [], category: "",
                            location_uuid: location.id, color: "", tags: ["Created with AppIntent"])
        let items = names.map { Items(id: UUID(), name: $0, box_uuid: box.id) }
        // Kiste, Gegenstände und ein neuer Standort werden gemeinsam bestätigt.
        let newLocations = snapshot.locations.contains(where: { $0.id == location.id }) ? [] : [location]
        try InventoryPersistence.mergeInventory(boxes: [box], items: items, locations: newLocations)
        return box.id
    }
}

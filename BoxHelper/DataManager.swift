//
//  DataManager.swift
//  BoxHelper
//
//  Created by HOCKULUS on 04.12.24.
//

import Foundation

struct DataManager {
    var boxes: [MovingBox]
    var itemsDatabase: [Items]
    var locationsDatabase: [Locations]
    
    mutating func migrateLocationsToNewModel() {
        // Lade bestehende Items aus UserDefaults
        var currentLocationsDatabase = loadLocations() // Bestehende Items
        var requiresMigration1 = false
        
        // Lade bestehende Boxen
        boxes = loadBoxes()
        
        // Prüfe, ob Migration notwendig ist
        for box in boxes {
            if !box.category.isEmpty { // Wenn alte Items vorhanden sind
                requiresMigration1 = true
                break
            }
        }
        print("requiresMigration1: \(requiresMigration1)")
        // Migration nur durchführen, wenn alte Daten vorhanden sind
        guard requiresMigration1 else {
            print("Keine Migration erforderlich. Locations sind auf dem neuesten Stand.")
            return
        }

        print("Location Migration gestartet...")
        var updatedBoxes: [MovingBox] = []

        for var box in boxes {
            // Überspringe Boxen, die bereits eine Location haben
            if box.location_uuid != nil {
                print("Box.location_uuid: \(box.location_uuid!) ist nicht nil")
                updatedBoxes.append(box) // Box zur Liste hinzufügen und überspringen
                continue
            }

            var newLocationUUID: UUID
            // Prüfe, ob die Location bereits existiert
            if let existingLocation = currentLocationsDatabase.first(where: { $0.name == box.category }) {
                // Item existiert bereits, füge nur die UUID hinzu
                newLocationUUID = existingLocation.id
            } else {
                // Neues Item erstellen und zur Datenbank hinzufügen
                let newLocation = Locations(
                    id: UUID(),
                    name: box.category,
                    color: box.color,
                    image: ""
                )
                
                currentLocationsDatabase.append(newLocation)
                newLocationUUID = newLocation.id
            }
            
            // Weisen Sie die neue UUID zu und setzen Sie die Kategorie zurück
            box.location_uuid = newLocationUUID
            box.category = ""
            updatedBoxes.append(box)
        }

        // Aktualisiere die Boxen und die Items-Datenbank
        boxes = updatedBoxes
        locationsDatabase = currentLocationsDatabase // Beibehalten der bestehenden Locations
        saveToUserDefaults()

        print("Migration abgeschlossen: \(locationsDatabase.count) Locations in der Datenbank.")
    }
    
    mutating func migrateItemsToNewModel() {
        // Lade bestehende Items aus UserDefaults
        var currentItemsDatabase = loadItems() // Bestehende Items
        var requiresMigration = false
        
        // Lade bestehende Boxen
        boxes = loadBoxes()
        
        // Prüfe, ob Migration notwendig ist
        for box in boxes {
            if !box.items.isEmpty { // Wenn alte Items vorhanden sind
                requiresMigration = true
                break
            }
        }

        // Migration nur durchführen, wenn alte Daten vorhanden sind
        guard requiresMigration else {
            print("Keine Migration erforderlich. Daten sind auf dem neuesten Stand.")
            return
        }

        print("Migration gestartet...")
        var updatedBoxes: [MovingBox] = []

        for var box in boxes {
            var newItems: [UUID] = []

            for itemName in box.items {
                // Prüfe, ob das Item bereits existiert
                if let existingItem = currentItemsDatabase.first(where: { $0.name == itemName && $0.category == box.category }) {
                    // Item existiert bereits, füge nur die UUID hinzu
                    newItems.append(existingItem.id)
                } else {
                    // Neues Item erstellen und zur Datenbank hinzufügen
                    let newItem = Items(
                        id : UUID(),
                        name: itemName,
                        box_uuid: box.id,
                        description: nil,
                        images: [],
                        category: box.category,
                        isFragile: false,
                        tags: nil
                    )

                    currentItemsDatabase.append(newItem)
                    newItems.append(newItem.id)
                }
            }

            // Alte UUIDs beibehalten und neue hinzufügen
            if !newItems.isEmpty {
                /*var combinedUUIDs = box.items_uuid ?? []
                for newUUID in newItems {
                    if !combinedUUIDs.contains(newUUID) {
                        combinedUUIDs.append(newUUID)
                    }
                }
                box.items_uuid = combinedUUIDs
                */
                box.items = []
                //updatedBoxes.append(box)
            }
            updatedBoxes.append(box)
        }

        // Aktualisiere die Boxen und die Items-Datenbank
        boxes = updatedBoxes
        itemsDatabase = currentItemsDatabase // Beibehalten der bestehenden Items
        saveToUserDefaults()

        print("Migration abgeschlossen: \(itemsDatabase.count) Items in der Datenbank.")
    }

    func saveToUserDefaults() {
        let encoder = JSONEncoder()

        do {
            let boxesData = try encoder.encode(boxes)
            UserDefaults.standard.set(boxesData, forKey: "movingBoxes")
            print("Items: \(itemsDatabase)")
            let itemsData = try encoder.encode(itemsDatabase)
            UserDefaults.standard.set(itemsData, forKey: "itemsDatabase")

            print("Daten erfolgreich gespeichert.")
        } catch {
            print("Fehler beim Speichern der Daten: \(error)")
        }
        print("Migration abgeschlossen: \(loadItems())")
        
        do {
            let boxesData = try encoder.encode(boxes)
            UserDefaults.standard.set(boxesData, forKey: "movingBoxes")
            print("Locations: \(locationsDatabase)")
            let locationsData = try encoder.encode(locationsDatabase)
            UserDefaults.standard.set(locationsData, forKey: "locationsDatabase")

            print("Daten erfolgreich gespeichert.")
        } catch {
            print("Fehler beim Speichern der Daten: \(error)")
        }
        print("Migration abgeschlossen: \(loadItems())")
    }

    mutating func loadFromUserDefaults() {
        let decoder = JSONDecoder()

        if let boxesData = UserDefaults.standard.data(forKey: "movingBoxes") {
            do {
                boxes = try decoder.decode([MovingBox].self, from: boxesData)
            } catch {
                print("Fehler beim Laden der Box-Daten: \(error)")
            }
        }

        if let itemsData = UserDefaults.standard.data(forKey: "itemsDatabase") {
            do {
                itemsDatabase = try decoder.decode([Items].self, from: itemsData)
            } catch {
                print("Fehler beim Laden der Item-Datenbank: \(error)")
            }
        }
    }
}

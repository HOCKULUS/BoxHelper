//
//  AppIntents.swift
//  BoxHelper
//
//  Created by HOCKULUS on 03.07.25.
//

import AppIntents
import UIKit
import UniformTypeIdentifiers

struct AddEmptyBoxIntent: AppIntent {
    static let title = LocalizedStringResource("Create empty box")
    static let description = LocalizedStringResource("Create a new empty box.")
    
    @Parameter(title: "Name")
    var boxName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Create empty box \(\.$boxName)")
    }
    
    func perform() async throws -> some ReturnsValue<String> {
        var boxes = loadBoxes()
        let newBox = MovingBox(
            id: UUID(),
            name: boxName,
            items: [],
            images: [],
            category: "",
            color: "",
            tags: ["Created with AppIntent"]
        )
        boxes.append(newBox)
        saveBoxes(boxes)
        return .result(value: newBox.id.uuidString)
    }
}

@available(iOS 18.0, *)
struct AddImageBoxIntent: AppIntent {
    static let title = LocalizedStringResource("Add image to box")
    static let description = LocalizedStringResource("Add image file to a box. Returns the image file name")
    
    @Parameter(title: "Image", supportedContentTypes: [.image], inputConnectionBehavior: .connectToPreviousIntentResult)
    var image: IntentFile
    
    @Parameter(title: "Name or ID")
    var boxName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$image) to Box \(\.$boxName)")
    }
    
    func perform() async throws -> some ReturnsValue<String?> {
        let data = try await image.data(contentType: .image)
        guard let uiImage = UIImage(data: data) else {
            return .result(value: nil)
        }

        var boxes = loadBoxes()
        let boxUUID: UUID? = {
            if let uuid = UUID(uuidString: boxName) { return uuid }
            return boxes.first(where: { $0.name == boxName })?.id
        }()

        let sliderValue2 = UserDefaults.standard.double(forKey: "sliderValue2") == 0 ? 500 : UserDefaults.standard.double(forKey: "sliderValue2")
        let sliderValue3 = UserDefaults.standard.double(forKey: "sliderValue3") == 0 ? 0.5 : UserDefaults.standard.double(forKey: "sliderValue3")

        let resizedImage = uiImage.resizeImage(targetSize: CGSize(width: sliderValue2, height: sliderValue2))
        guard let compressedData = resizedImage?.compressImage(),
              let finalImageData = UIImage(data: compressedData)?.jpegData(compressionQuality: sliderValue3) else {
            return .result(value: nil)
        }

        let fileName = "\(UUID().uuidString).jpg"
        let fileLastPathComponent = await MainActor.run { () -> String? in
            guard let fileURL = UserDefaultsManager.shared.saveImage(finalImageData, withName: fileName) else {
                return nil
            }
            if let index = boxes.firstIndex(where: { $0.id == boxUUID }) {
                boxes[index].images.append(fileURL.lastPathComponent)
                saveBoxes(boxes)
                //boxes = loadBoxes() // ggf. nochmal laden, wenn nötig
                print("\(fileURL.lastPathComponent) & \(boxes[index].images)")
            }
            return fileURL.lastPathComponent
        }

        return .result(value: fileLastPathComponent)
    }
}

struct AddBoxIntent: AppIntent {
    static let title = LocalizedStringResource("Create box")
    static let description = LocalizedStringResource("Create a new box with location and items.")
    
    @Parameter(title: "Name")
    var boxName: String
    
    @Parameter(title: "Name or ID")
    var location: String
    
    @Parameter(title: "Items")
    var newItems: [String]

    static var parameterSummary: some ParameterSummary {
        Summary("Create box \(\.$boxName) at Location \(\.$location) with \(\.$newItems)")
    }
    
    func perform() async throws -> some ReturnsValue<String> {
        var boxes = loadBoxes()
        var items = loadItems()
        var locationUUID = loadLocations().first(where: { $0.name == location})?.id
        if locationUUID == nil {
            var locations = loadLocations()
            let newLocation = Locations(
                id: UUID(),
                name: location,
                image: ""
            )
            locationUUID = newLocation.id
            locations.append(newLocation)
            saveLocations(locations)
        }
        let newBox = MovingBox(
            id: UUID(),
            name: boxName,
            items: [],
            images: [],
            category: "",
            location_uuid: locationUUID,
            color: "",
            tags: ["Created with AppIntent"]
        )
        boxes.append(newBox)
        saveBoxes(boxes)
        for itemName in newItems/*.split(separator: " ").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) */{
            let newItem = Items(
                id: UUID(),
                name: itemName,
                box_uuid: newBox.id
            )
            items.append(newItem)
        }
        saveItems(items)
        return .result(value: newBox.id.uuidString)
    }
}

struct AddBoxWithSiriIntent: AppIntent {
    static let title = LocalizedStringResource("Create box (Siri)")
    static let description = LocalizedStringResource("Create a new box with location and items. Use space-separated values for the items.")
    
    @Parameter(title: "Name")
    var boxName: String
    
    @Parameter(title: "Location")
    var location: String
    
    @Parameter(title: "Items")
    var newItems: String

    static var parameterSummary: some ParameterSummary {
        Summary("Create box \(\.$boxName) at \(\.$location) with \(\.$newItems)")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        var boxes = loadBoxes()
        var items = loadItems()
        var locationUUID = loadLocations().first(where: { $0.name == location})?.id
        if locationUUID == nil {
            var locations = loadLocations()
            let newLocation = Locations(
                id: UUID(),
                name: location,
                image: ""
            )
            locationUUID = newLocation.id
            locations.append(newLocation)
            saveLocations(locations)
        }
        let newBox = MovingBox(
            id: UUID(),
            name: boxName,
            items: [],
            images: [],
            category: "",
            location_uuid: locationUUID,
            color: "",
            tags: ["Created with AppIntent"]
        )
        boxes.append(newBox)
        saveBoxes(boxes)
        for itemName in newItems.split(separator: " ").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }){
            let newItem = Items(
                id: UUID(),
                name: itemName,
                box_uuid: newBox.id
            )
            items.append(newItem)
        }
        saveItems(items)
        return .result(dialog: "Okay, \(boxName) has been created!")
    }
}

struct AddLocationIntent: AppIntent {
    static let title = LocalizedStringResource("Create location")
    static let description = LocalizedStringResource("Create a new location.")
    
    @Parameter(title: "Name")
    var locationName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Create Location \(\.$locationName)")
    }
    
    func perform() async throws -> some ReturnsValue<String> {
        var locations = loadLocations()
        let newLocation = Locations(
            id: UUID(),
            name: locationName
        )
        locations.append(newLocation)
        saveLocations(locations)
        return .result(value: newLocation.id.uuidString)
    }
}

struct GetBoxNameByIDIntent: AppIntent {
    static let title = LocalizedStringResource("Get box name by ID")
    static let description = LocalizedStringResource("Returns the name of a box based on its ID.")

    @Parameter(title: "ID")
    var boxID: String

    static var parameterSummary: some ParameterSummary {
        Summary("Get box name for box \(\.$boxID)")
    }

    func perform() async throws -> some ReturnsValue<String?> {
        guard let uuid = UUID(uuidString: boxID) else {
            return .result(value: nil)
        }

        let boxes = loadBoxes()
        let boxName = boxes.first(where: { $0.id == uuid })?.name

        return .result(value: boxName)
    }
}

import AppIntents

struct GetItemNameByIDIntent: AppIntent {
    static let title = LocalizedStringResource("Get item name by ID")
    static let description = LocalizedStringResource("Returns the name of an item based on its ID.")

    @Parameter(title: "ID")
    var itemID: String

    static var parameterSummary: some ParameterSummary {
        Summary("Get item name for item \(\.$itemID)")
    }

    func perform() async throws -> some ReturnsValue<String?> {
        guard let uuid = UUID(uuidString: itemID) else {
            return .result(value: nil)
        }

        let items = loadItems()
        let itemName = items.first(where: { $0.id == uuid })?.name

        return .result(value: itemName)
    }
}
struct GetLocationNameByIDIntent: AppIntent {
    static let title = LocalizedStringResource("Get location name by ID")
    static let description = LocalizedStringResource("Returns the name of a location based on its ID.")

    @Parameter(title: "ID")
    var locationID: String

    static var parameterSummary: some ParameterSummary {
        Summary("Get location name for Location \(\.$locationID)")
    }

    func perform() async throws -> some ReturnsValue<String?> {
        guard let uuid = UUID(uuidString: locationID) else {
            return .result(value: nil)
        }

        let locations = loadLocations()
        let locationName = locations.first(where: { $0.id == uuid })?.name

        return .result(value: locationName)
    }
}

struct ListBoxesAtLocationIntent: AppIntent {
    static let title: LocalizedStringResource = "Get box IDs at location"
    static let description = LocalizedStringResource("Get all box IDs assigned to a specific location.")

    @Parameter(title: "Name or ID")
    var locationIdentifier: String

    static var parameterSummary: some ParameterSummary {
        Summary("Get all box IDs at location \(\.$locationIdentifier)")
    }

    func perform() async throws -> some ReturnsValue<[String]> {
        let boxes = loadBoxes()
        let locations = loadLocations()

        var locationUUID: UUID?

        // Prüfe, ob es sich um eine gültige UUID handelt
        if let uuid = UUID(uuidString: locationIdentifier) {
            locationUUID = uuid
        } else {
            locationUUID = locations.first(where: {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                == locationIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            })?.id
        }

        guard let validLocationUUID = locationUUID else {
            return .result(value: [])
        }

        let matchingBoxes = boxes.filter { $0.location_uuid == validLocationUUID }
                                 .map { $0.name }

        return .result(value: matchingBoxes)
    }
}

struct UpdateBoxLocationIntent: AppIntent {
    static let title = LocalizedStringResource("Set box location")
    static let description = LocalizedStringResource("Change the location of a box.")

    @Parameter(title: "Name or ID")
    var boxIdentifier: String

    @Parameter(title: "Name or ID")
    var newLocationIdentifier: String

    static var parameterSummary: some ParameterSummary {
        Summary("Move box \(\.$boxIdentifier) to location \(\.$newLocationIdentifier)")
    }

    func perform() async throws -> some ReturnsValue<Bool> {
        var boxes = loadBoxes()
        var locations = loadLocations()

        // Box-ID ermitteln (UUID oder Name)
        let boxUUID = UUID(uuidString: boxIdentifier) ??
            boxes.first(where: { $0.name.lowercased() == boxIdentifier.lowercased() })?.id

        guard let validBoxUUID = boxUUID,
              let boxIndex = boxes.firstIndex(where: { $0.id == validBoxUUID }) else {
            return .result(value: false) // Box nicht gefunden
        }

        // Location-ID ermitteln (UUID oder Name)
        var locationUUID: UUID?
        if let uuid = UUID(uuidString: newLocationIdentifier) {
            locationUUID = uuid
        } else if let existingLocation = locations.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            == newLocationIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }) {
            locationUUID = existingLocation.id
        } else {
            // Standort existiert nicht → neuen erstellen
            let newLocation = Locations(id: UUID(), name: newLocationIdentifier, image: "")
            locationUUID = newLocation.id
            locations.append(newLocation)
            saveLocations(locations)
        }

        guard let finalLocationUUID = locationUUID else {
            return .result(value: false) // sollte eigentlich nie passieren
        }

        // Box aktualisieren
        boxes[boxIndex].location_uuid = finalLocationUUID
        saveBoxes(boxes)
        return .result(value: true)
    }
}

struct SetBoxTagsIntent: AppIntent {
    static let title = LocalizedStringResource("Set box tags")
    static let description = LocalizedStringResource("Assign one or more tags to a specific box.")

    @Parameter(title: "Name or ID")
    var boxIdentifier: String

    @Parameter(title: "Tags")
    var tags: [String]

    static var parameterSummary: some ParameterSummary {
        Summary("Set tags \(\.$tags) for box \(\.$boxIdentifier)")
    }

    func perform() async throws -> some ReturnsValue<Bool> {
        var boxes = loadBoxes()

        // Box über UUID oder Name suchen
        let boxUUID = UUID(uuidString: boxIdentifier) ??
            boxes.first(where: { $0.name.lowercased() == boxIdentifier.lowercased() })?.id

        guard let validUUID = boxUUID,
              let index = boxes.firstIndex(where: { $0.id == validUUID }) else {
            return .result(value: false) // Box nicht gefunden
        }

        // Tags setzen
        boxes[index].tags = tags
        saveBoxes(boxes)
        return .result(value: true)
    }
}
struct GetBoxTagsIntent: AppIntent {
    static let title = LocalizedStringResource("Get box tags")
    static let description = LocalizedStringResource("Returns all tags assigned to a box.")

    @Parameter(title: "Name or ID")
    var boxIdentifier: String

    static var parameterSummary: some ParameterSummary {
        Summary("Get tags of box \(\.$boxIdentifier)")
    }

    func perform() async throws -> some ReturnsValue<[String]> {
        let boxes = loadBoxes()

        // Box über UUID oder Name suchen
        let boxUUID = UUID(uuidString: boxIdentifier) ??
            boxes.first(where: { $0.name.lowercased() == boxIdentifier.lowercased() })?.id

        guard let validUUID = boxUUID,
              let box = boxes.first(where: { $0.id == validUUID }) else {
            return .result(value: [])
        }
        
        return .result(value: box.tags ?? [""])
    }
}

struct GetBoxImagesIntent: AppIntent {
    static let title = LocalizedStringResource("Get box image file names")
    static let description = LocalizedStringResource("Returns all image file names associated with a box.")

    @Parameter(title: "Name or ID")
    var boxIdentifier: String

    static var parameterSummary: some ParameterSummary {
        Summary("Get all images of box \(\.$boxIdentifier)")
    }

    func perform() async throws -> some ReturnsValue<[String]> {
        let boxes = loadBoxes()

        // Box über UUID oder Name finden
        let boxUUID = UUID(uuidString: boxIdentifier) ??
            boxes.first(where: { $0.name.lowercased() == boxIdentifier.lowercased() })?.id

        guard let validUUID = boxUUID,
              let box = boxes.first(where: { $0.id == validUUID }) else {
            return .result(value: [])
        }

        return .result(value: box.images)
    }
}

struct ListAllBoxIDsIntent: AppIntent {
    static let title = LocalizedStringResource("Get all box IDs")
    static let description = LocalizedStringResource("Returns the IDs of all existing boxes.")

    static var parameterSummary: some ParameterSummary {
        Summary("Get all box IDs")
    }

    func perform() async throws -> some ReturnsValue<[String]> {
        let boxes = loadBoxes()
        let ids = boxes.map { $0.id.uuidString }
        return .result(value: ids)
    }
}

struct ListAllLocationIDsIntent: AppIntent {
    static let title = LocalizedStringResource("Get all location IDs")
    static let description = LocalizedStringResource("Returns the IDs of all existing locations.")

    static var parameterSummary: some ParameterSummary {
        Summary("Get all location IDs")
    }

    func perform() async throws -> some ReturnsValue<[String]> {
        let locations = loadLocations()
        let ids = locations.map { $0.id.uuidString }
        return .result(value: ids)
    }
}

struct ListAllItemIDsIntent: AppIntent {
    static let title = LocalizedStringResource("Get all item IDs")
    static let description = LocalizedStringResource("Returns the IDs of all existing items.")

    static var parameterSummary: some ParameterSummary {
        Summary("Get all item IDs")
    }

    func perform() async throws -> some ReturnsValue<[String]> {
        let items = loadItems()
        let ids = items.map { $0.id.uuidString }
        return .result(value: ids)
    }
}

struct DeleteLocationIntent: AppIntent {
    static let title = LocalizedStringResource("Delete location")
    static let description = LocalizedStringResource("Deletes a location if no box is assigned to it.")

    @Parameter(title: "Name or ID")
    var locationNameOrID: String

    static var parameterSummary: some ParameterSummary {
        Summary("Delete location \(\.$locationNameOrID) if unused")
    }

    func perform() async throws -> some ReturnsValue<Bool> {
        var locations = loadLocations()
        let boxes = loadBoxes()
        
        // Bestimme UUID
        var locationUUID: UUID?
        if let uuid = UUID(uuidString: locationNameOrID) {
            locationUUID = uuid
        } else {
            locationUUID = locations.first(where: { $0.name == locationNameOrID })?.id
        }

        // Falls ungültig, gib false zurück
        guard let uuidToDelete = locationUUID else {
            return .result(value: false)
        }

        // Prüfe, ob Standort in Verwendung ist
        let isUsed = boxes.contains(where: { $0.location_uuid == uuidToDelete })
        if isUsed {
            return .result(value: false)
        }

        // Lösche den Standort
        locations.removeAll(where: { $0.id == uuidToDelete })
        saveLocations(locations)
        return .result(value: true)
    }
}

struct DeleteImageIntent: AppIntent {
    static let title = LocalizedStringResource("Delete image")
    static let description = LocalizedStringResource("Deletes a specific image file by filename from the app storage.")

    @Parameter(title: "Filename")
    var fileName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Delete image file \(\.$fileName)")
    }

    func perform() async throws -> some ReturnsValue<Bool> {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(fileName)  // Den Dateipfad erstellen
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)  // Bild löschen
                print("Bild erfolgreich gelöscht: \(fileURL.path)")
                return .result(value: true)
            } else {
                print("Fehler: Datei existiert nicht: \(fileURL.path)")
                return .result(value: false)
            }
        } catch {
            return .result(value: false)
            
        }
    }
}

struct DeleteBoxIfEmptyIntent: AppIntent {
    static let title = LocalizedStringResource("Delete box")
    static let description = LocalizedStringResource("Deletes a box if no items is assigned to it. Also deletes all associated images from the app storage if needed.")

    @Parameter(title: "Name or ID")
    var boxIdentifier: String
    
    @Parameter(title: "True or False")
    var deleteImages: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Delete box \(\.$boxIdentifier) if it has no items. Delete assigned images: \(\.$deleteImages)")
    }

    func perform() async throws -> some ReturnsValue<Bool> {
        var boxes = loadBoxes()
        let items = loadItems()

        // Box per UUID oder Name suchen
        let boxUUID: UUID?
        if let uuid = UUID(uuidString: boxIdentifier) {
            boxUUID = uuid
        } else {
            boxUUID = boxes.first(where: { $0.name == boxIdentifier })?.id
        }

        guard let id = boxUUID,
              let boxIndex = boxes.firstIndex(where: { $0.id == id }) else {
            return .result(value: false)
        }

        // Prüfen, ob noch Items zur Box gehören
        let hasItems = items.contains(where: { $0.box_uuid == id })
        if hasItems {
            print("Box „\(boxes[boxIndex].name)“ enthält noch Gegenstände. Bitte löschen oder verschieben, bevor du sie entfernst.")
            return .result(value: false)
        }

        // Bilder löschen
        if deleteImages {
            for fileName in boxes[boxIndex].images {
                let fileManager = FileManager.default
                let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                let fileURL = documentsDirectory.appendingPathComponent(fileName)  // Den Dateipfad erstellen
                
                do {
                    if fileManager.fileExists(atPath: fileURL.path) {
                        try fileManager.removeItem(at: fileURL)  // Bild löschen
                        print("Bild erfolgreich gelöscht: \(fileURL.path)")
                    } else {
                        print("Fehler: Datei existiert nicht: \(fileURL.path)")
                    }
                } catch {
                    print("Fehler beim Löschen des Bildes: \(error)")
                    
                }
            }
        }

        // Box entfernen
        boxes.remove(at: boxIndex)
        saveBoxes(boxes)

        return .result(value: true)
    }
}

struct DeleteItemIntent: AppIntent {
    static let title = LocalizedStringResource("Delete item")
    static let description = LocalizedStringResource("Deletes an item.")

    @Parameter(title: "Name or ID")
    var itemNameOrID: String

    static var parameterSummary: some ParameterSummary {
        Summary("Delete item \(\.$itemNameOrID)")
    }

    func perform() async throws -> some ReturnsValue<Bool> {
        var items = loadItems()

        // Versuche, die UUID direkt zu verwenden
        if let uuid = UUID(uuidString: itemNameOrID),
           let index = items.firstIndex(where: { $0.id == uuid }) {
            items.remove(at: index)
            saveItems(items)
            return .result(value: true)
        }

        // Fallback: Suche nach dem Namen (ignoriere Groß-/Kleinschreibung + Leerzeichen)
        let cleanedName = itemNameOrID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let index = items.firstIndex(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanedName
        }) {
            items.remove(at: index)
            saveItems(items)
            return .result(value: true)
        }

        // Nichts gefunden
        return .result(value: false)
    }
}

struct AddImageFilenameToBoxIntent: AppIntent {
    static let title = LocalizedStringResource("Add image file name to box")
    static let description = LocalizedStringResource("Adds an existing image file name to a box (The image must already exist in the app storage).")

    @Parameter(title: "Name or ID")
    var boxIdentifier: String

    @Parameter(title: "Image File Name")
    var imageFilename: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add image \(\.$imageFilename) to box \(\.$boxIdentifier)")
    }

    func perform() async throws -> some ReturnsValue<Bool> {
        var boxes = loadBoxes()

        // Box über UUID oder Namen identifizieren
        let boxUUID = UUID(uuidString: boxIdentifier) ??
            boxes.first(where: { $0.name.lowercased() == boxIdentifier.lowercased() })?.id

        guard let validUUID = boxUUID,
              let index = boxes.firstIndex(where: { $0.id == validUUID }) else {
            return .result(value: false)
        }

        // Bildname hinzufügen, falls noch nicht vorhanden
        if !boxes[index].images.contains(imageFilename) {
            boxes[index].images.append(imageFilename)
            saveBoxes(boxes)
        }

        return .result(value: true)
    }
}

struct AddItemIntent: AppIntent {
    static let title = LocalizedStringResource("Create item")
    static let description = LocalizedStringResource("Create a new item.")
    
    @Parameter(title: "Name")
    var itemName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Create item \(\.$itemName)")
    }
    
    func perform() async throws -> some ReturnsValue<String> {
        var items = loadItems()
        let newItem = Items(
            id: UUID(),
            name: itemName,
            box_uuid: UUID()
        )
        items.append(newItem)
        saveItems(items)
        return .result(value: newItem.id.uuidString)
    }
}

struct GetBoxLocationIntent: AppIntent {
    static let title = LocalizedStringResource("Get box location ID")
    static let description = LocalizedStringResource("Returns the location id of the box.")

    @Parameter(title: "Name or ID")
    var boxReference: String

    static var parameterSummary: some ParameterSummary {
        Summary("Get location ID of box \(\.$boxReference)")
    }

    func perform() async throws -> some ReturnsValue<String?> {
        let boxes = loadBoxes()
        let locations = loadLocations()
        
        // Box-ID oder Name suchen
        let boxUUID = UUID(uuidString: boxReference) ??
        boxes.first(where: { $0.name == boxReference })?.id
        
        guard let boxID = boxUUID,
              let box = boxes.first(where: { $0.id == boxID }) else {
            return .result(value: nil)
        }
        
        // Standort ermitteln
        if let locationID = locations.first(where: { $0.id == box.location_uuid })?.id {
            return .result(value: locationID.uuidString)
        }
        else {
            return .result(value: nil)
        }
    }
}

struct AddItemToBoxIntent: AppIntent {
    static let title = LocalizedStringResource("Add item to box")
    static let description = LocalizedStringResource("Creates a new item and assigns it to a box. Returns the new item's ID")

    @Parameter(title: "Name")
    var itemName: String

    @Parameter(title: "Name or ID")
    var boxReference: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$itemName) to box \(\.$boxReference)")
    }

    func perform() async throws -> some ReturnsValue<String?> {
        var items = loadItems()
        let boxes = loadBoxes()

        // Box über UUID oder Name finden
        let boxUUID: UUID? = UUID(uuidString: boxReference) ??
            boxes.first(where: { $0.name == boxReference })?.id

        guard let boxID = boxUUID else {
            return .result(value: nil)
        }

        let newItem = Items(
            id: UUID(),
            name: itemName,
            box_uuid: boxID
        )

        items.append(newItem)
        saveItems(items)

        return .result(value: newItem.id.uuidString)
    }
}

struct MoveItemIntent: AppIntent {
    static let title = LocalizedStringResource("Set item box")
    static let description = LocalizedStringResource("Move item to another box.")
    
    @Parameter(title: "Name or ID") //man könnte neben Freitext auch eine UUID Prüfung einbauen um einmalige Werte zu haben
    var itemName: String
    
    @Parameter(title: "Name or ID") //man könnte neben Freitext auch eine UUID Prüfung einbauen um einmalige Werte zu haben
    var boxName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Move item \(\.$itemName) to box \(\.$boxName)")
    }
    
    func perform() async throws -> some ReturnsValue<Bool> {
        var boxUUID : UUID?
        if let uuid = UUID(uuidString: boxName) {
            boxUUID = uuid
        }
        else{
            boxUUID = loadBoxes().first(where: { $0.name == boxName})?.id
        }
        
        var items = loadItems()
        var itemUUID : UUID?
        if let uuid = UUID(uuidString: itemName) {
            itemUUID = uuid
        }
        else{
            itemUUID = loadItems().first(where: { $0.name == itemName})?.id
        }
        if let index = items.firstIndex(where: { $0.id == itemUUID }) {
            if let boxUUID = boxUUID {
                items[index].box_uuid = boxUUID
            }
        }
        saveItems(items)
        if loadItems().first(where: { $0.id == itemUUID})?.box_uuid == boxUUID {
            return .result(value: true)
        }
        else {
            return .result(value: false)
        }
    }
}

struct ListItemsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get box item IDs"
    static let description = LocalizedStringResource("Get all item IDs from a box.")

    @Parameter(title: "Name or ID")
    var boxName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Get all item IDs from box \(\.$boxName)")
    }
    
    func perform() async throws -> some ReturnsValue<[String]>{
        let allItems = loadItems()
        var boxUUID : UUID?
        if let uuid = UUID(uuidString: boxName) {
            boxUUID = uuid
        }
        else{
            boxUUID = loadBoxes().first(where: { $0.name == boxName})?.id
        }
        let matchingItems = allItems.filter { $0.box_uuid == boxUUID }.map{ $0.id.uuidString }

        if matchingItems.isEmpty {
            return .result(
                value: []
            )
        }

        return .result(
            value: matchingItems
        )
    }
}

struct FindItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Get item box ID"
    static let description = IntentDescription("Returns the ID of the box that contains the specified item.")
    
    @Parameter(title: "Item")
    var itemName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Get box id for item \(\.$itemName)")
    }

    func perform() async throws -> some ReturnsValue<String?> {
        let items = loadItems()
        let boxes = loadBoxes()
        //let locations = loadLocations()

        // Trim + Lowercase-Vergleich
        let cleanItemName = itemName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard let item = items.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanItemName
        }) else {
            return .result(value: nil)
        }

        if boxes.first(where: { $0.id == item.box_uuid }) != nil {
            return .result(value: item.box_uuid.uuidString)
        }
        else {
            return .result(value: nil)
        }
    }
}

struct FindItemWithSiriIntent: AppIntent {
    static let title: LocalizedStringResource = "Get item box (Siri)"
    static let description = IntentDescription("Find the box and the location of a specific item.")
    
    @Parameter(title: "Item")
    var itemName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Search item \(\.$itemName)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let items = loadItems()
        let boxes = loadBoxes()
        let locations = loadLocations()

        // Trim + Lowercase-Vergleich
        let cleanItemName = itemName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard let item = items.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanItemName
        }) else {
            return .result(
                dialog: IntentDialog(
                    stringLiteral: String.localizedStringWithFormat(
                        String(localized: "I couldn’t find the item „%@“."),
                        itemName
                    )
                )
            )
        }

        guard let box = boxes.first(where: { $0.id == item.box_uuid }) else {
            return .result(dialog: IntentDialog("The item \"\(item.name)\" is not stored in any box."))
        }

        if let location = locations.first(where: { $0.id == box.location_uuid }) {
            return .result(dialog: IntentDialog("The item \"\(item.name)\" is located in the box \"\(box.name)\" at the location \"\(location.name)\"."))
        } else {
            return .result(dialog: IntentDialog("The item \"\(item.name)\" is in the box \"\(box.name)\"."))
        }
    }
}

struct GetInventorySummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Get inventory summary"
    static let description = IntentDescription("Returns total counts for boxes, items, and locations.")

    static var parameterSummary: some ParameterSummary {
        Summary("Get inventory summary")
    }

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let boxes = loadBoxes()
        let items = loadItems()
        let locations = loadLocations()

        let summary = "Boxes: \(boxes.count), Items: \(items.count), Locations: \(locations.count)"
        return .result(value: summary, dialog: IntentDialog("\(summary)"))
    }
}

struct ListEmptyLocationsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get empty locations"
    static let description = IntentDescription("Returns all locations that currently contain no boxes.")

    static var parameterSummary: some ParameterSummary {
        Summary("Get empty locations")
    }

    func perform() async throws -> some ReturnsValue<[String]> {
        let locations = loadLocations()
        let boxes = loadBoxes()

        let emptyLocationNames = locations
            .filter { location in
                !boxes.contains(where: { $0.location_uuid == location.id })
            }
            .map { $0.name.isEmpty ? $0.id.uuidString : $0.name }

        return .result(value: emptyLocationNames)
    }
}

struct ListUnassignedItemsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get unassigned items"
    static let description = IntentDescription("Returns all items that are not assigned to an existing box.")

    static var parameterSummary: some ParameterSummary {
        Summary("Get unassigned items")
    }

    func perform() async throws -> some ReturnsValue<[String]> {
        let items = loadItems()
        let boxes = loadBoxes()
        let boxIDs = Set(boxes.map(\.id))

        let unassignedItemNames = items
            .filter { !boxIDs.contains($0.box_uuid) }
            .map { $0.name.isEmpty ? $0.id.uuidString : $0.name }

        return .result(value: unassignedItemNames)
    }
}

struct GetLocationOverviewIntent: AppIntent {
    static let title: LocalizedStringResource = "Get location overview"
    static let description = IntentDescription("Returns how many boxes and items are stored at a specific location.")

    @Parameter(title: "Name or ID")
    var locationIdentifier: String

    static var parameterSummary: some ParameterSummary {
        Summary("Get overview for location \(\.$locationIdentifier)")
    }

    func perform() async throws -> some ReturnsValue<String?> & ProvidesDialog {
        let locations = loadLocations()
        let boxes = loadBoxes()
        let items = loadItems()

        let locationID = UUID(uuidString: locationIdentifier) ??
            locations.first(where: {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                == locationIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            })?.id

        guard let locationID,
              let location = locations.first(where: { $0.id == locationID }) else {
            return .result(value: nil, dialog: IntentDialog("Location not found."))
        }

        let boxesAtLocation = boxes.filter { $0.location_uuid == locationID }
        let boxIDs = Set(boxesAtLocation.map(\.id))
        let itemsAtLocation = items.filter { boxIDs.contains($0.box_uuid) }

        let overview = "\(location.name): \(boxesAtLocation.count) boxes, \(itemsAtLocation.count) items"
        return .result(value: overview, dialog: IntentDialog("\(overview)"))
    }
}

struct CreateZIPBackupIntent: AppIntent {
    static let title = LocalizedStringResource("Create ZIP backup")
    static let description = IntentDescription("Creates a ZIP backup of app data and returns the ZIP file.")

    static var parameterSummary: some ParameterSummary {
        Summary("Create ZIP backup")
    }

    func perform() async throws -> some ReturnsValue<IntentFile?> & ProvidesDialog {
        do {
            guard let zipURL = try exportDataAndImages() else {
                return .result(
                    value: nil,
                    dialog: IntentDialog("Backup could not be created.")
                )
            }
            let zipData = try Data(contentsOf: zipURL)
            let zipFile = IntentFile(
                data: zipData,
                filename: zipURL.lastPathComponent,
                type: .zip
            )
            return .result(
                value: zipFile,
                dialog: IntentDialog("ZIP backup created: \(zipURL.lastPathComponent)")
            )
        } catch {
            return .result(
                value: nil,
                dialog: IntentDialog("Backup could not be created.")
            )
        }
    }
}


struct TransferAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddBoxWithSiriIntent(),
            phrases: [
                "Create box in \(.applicationName)",               // 🇺🇸 English
                "Erstelle Kiste in \(.applicationName)",          // 🇩🇪 German
                "Créer une boîte dans \(.applicationName)",        // 🇫🇷 French
                "Crear caja en \(.applicationName)",               // 🇪🇸 Spanish
                "Crea scatola in \(.applicationName)",             // 🇮🇹 Italian
                "Maak doos in \(.applicationName)",                // 🇳🇱 Dutch
                "Utwórz pudełko w \(.applicationName)",            // 🇵🇱 Polish
                "在 \(.applicationName) 中创建箱子",                   // 🇨🇳 Chinese (Simplified)
                "\(.applicationName) でボックスを作成",                // 🇯🇵 Japanese
                "\(.applicationName)에서 상자 만들기",                 // 🇰🇷 Korean
                "Skapa låda i \(.applicationName)",                // 🇸🇪 Swedish
                "Luo laatikko sovelluksessa \(.applicationName)",  // 🇫🇮 Finnish
                "Opprett boks i \(.applicationName)",              // 🇳🇴 Norwegian
                "\(.applicationName)'de kutu oluştur",             // 🇹🇷 Turkish
                "Tạo hộp trong \(.applicationName)",               // 🇻🇳 Vietnamese
                "Criar caixa no \(.applicationName)"               // 🇧🇷 Portuguese
            ],
            shortTitle: "Add new box",
            systemImageName: "shippingbox"
        )
        AppShortcut(
            intent: FindItemWithSiriIntent(),
            phrases: [
                "Find item in \(.applicationName)",            // 🇺🇸 English
                "Finde Gegenstand in \(.applicationName)",     // 🇩🇪 German
                "Trouver un objet dans \(.applicationName)",   // 🇫🇷 French
                "Buscar un objeto en \(.applicationName)",     // 🇪🇸 Spanish
                "Trova un oggetto in \(.applicationName)",     // 🇮🇹 Italian
                "Zoek een item in \(.applicationName)",        // 🇳🇱 Dutch
                "Znajdź przedmiot w \(.applicationName)",      // 🇵🇱 Polish
                "在 \(.applicationName) 中查找物品",             // 🇨🇳 Simplified Chinese
                "\(.applicationName) でアイテムを探す",          // 🇯🇵 Japanese
                "\(.applicationName)에서 항목 찾기",              // 🇰🇷 Korean
                "Hitta föremål i \(.applicationName)",         // 🇸🇪 Swedish
                "Etsi esine \(.applicationName)-sovelluksessa",// 🇫🇮 Finnish
                "Finn gjenstand i \(.applicationName)",        // 🇳🇴 Norwegian
                "\(.applicationName)'de öğe bul",              // 🇹🇷 Turkish
                "Tìm vật phẩm trong \(.applicationName)",      // 🇻🇳 Vietnamese
                "Encontrar item no \(.applicationName)"        // 🇧🇷 Portuguese
            ],
            shortTitle: LocalizedStringResource("Search item"),
            systemImageName: "text.magnifyingglass"
        )
        AppShortcut(
            intent: CreateZIPBackupIntent(),
            phrases: [
                "Create backup in \(.applicationName)",
                "Erstelle Backup in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Create backup"),
            systemImageName: "archivebox"
        )
        AppShortcut(
            intent: GetInventorySummaryIntent(),
            phrases: [
                "Get inventory summary in \(.applicationName)",
                "Zeige Bestandsübersicht in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Inventory summary"),
            systemImageName: "chart.bar"
        )
        AppShortcut(
            intent: ListEmptyLocationsIntent(),
            phrases: [
                "Get empty locations in \(.applicationName)",
                "Zeige leere Standorte in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Empty locations"),
            systemImageName: "mappin.slash"
        )
        AppShortcut(
            intent: ListUnassignedItemsIntent(),
            phrases: [
                "Get unassigned items in \(.applicationName)",
                "Zeige nicht zugewiesene Gegenstände in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Unassigned items"),
            systemImageName: "tray"
        )
    }
}

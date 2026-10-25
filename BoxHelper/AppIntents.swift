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
    
    @MainActor
    func perform() async throws -> some ReturnsValue<String> {
        let newBox = MovingBox(
            id: UUID(),
            name: boxName,
            items: [],
            images: [],
            category: "",
            color: "",
            tags: ["Created with AppIntent"]
        )
        try InventoryPersistence.mergeInventory(boxes: [newBox], items: [], locations: [])
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
    
    @MainActor
    func perform() async throws -> some ReturnsValue<String?> {
        let id = try IntentInventoryLookup.resolve(boxName, in: try InventoryPersistence.loadBoxes(), name: { $0.name }).id
        let photos = try await IntentImageStore.prepare([image])
        let tags = await IntentImageStore.tags(for: photos)
        // Reload after image loading/OCR so concurrent edits are preserved.
        let baseline = try InventoryPersistence.loadBoxes()
        var boxes = baseline
        guard let index = boxes.firstIndex(where: { $0.id == id }) else { throw IntentInventoryError.notFound }
        let names = try IntentImageStore.save(photos)
        boxes[index].images += names
        boxes[index].tags = IntentInventoryLookup.normalizedTags((boxes[index].tags ?? []) + tags)
        try IntentImageStore.commit(names) { try InventoryPersistence.applyBoxChanges(from: baseline, to: boxes) }
        return .result(value: names.first)
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
    
    @MainActor
    func perform() async throws -> some ReturnsValue<String> {
        let id = try IntentBoxCreation.create(name: boxName, location: location, itemNames: newItems)
        return .result(value: id.uuidString)
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
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let names = newItems.split(separator: " ").map(String.init)
        _ = try IntentBoxCreation.create(name: boxName, location: location, itemNames: names)
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
    
    @MainActor
    func perform() async throws -> some ReturnsValue<String> {
        let newLocation = Locations(
            id: UUID(),
            name: locationName
        )
        try InventoryPersistence.mergeInventory(boxes: [], items: [], locations: [newLocation])
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

    @MainActor
    func perform() async throws -> some ReturnsValue<String?> {
        guard let uuid = UUID(uuidString: boxID) else {
            return .result(value: nil)
        }

        let boxes = try InventoryPersistence.loadBoxes()
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

    @MainActor
    func perform() async throws -> some ReturnsValue<String?> {
        guard let uuid = UUID(uuidString: itemID) else {
            return .result(value: nil)
        }

        let items = try InventoryPersistence.loadItems()
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

    @MainActor
    func perform() async throws -> some ReturnsValue<String?> {
        guard let uuid = UUID(uuidString: locationID) else {
            return .result(value: nil)
        }

        let locations = try InventoryPersistence.loadLocations()
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

    @MainActor
    func perform() async throws -> some ReturnsValue<[String]> {
        let location = try IntentInventoryLookup.resolve(locationIdentifier, in: try InventoryPersistence.loadLocations(), name: { $0.name })
        // This action promises IDs, not display names.
        return .result(value: try InventoryPersistence.loadBoxes().filter { $0.location_uuid == location.id }.map { $0.id.uuidString })
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

    @MainActor
    func perform() async throws -> some ReturnsValue<Bool> {
        let snapshot = try InventoryPersistence.snapshot()
        var boxes = snapshot.boxes
        let box = try IntentInventoryLookup.resolve(boxIdentifier, in: boxes, name: { $0.name })
        guard let index = boxes.firstIndex(where: { $0.id == box.id }) else { throw IntentInventoryError.notFound }
        var locations = snapshot.locations
        let location = try IntentBoxCreation.location(newLocationIdentifier, in: &locations)
        boxes[index].location_uuid = location.id
        // Ein neuer Standort und die Zuordnung gehören zur selben Transaktion.
        try InventoryPersistence.applyInventoryChanges(from: snapshot,
            to: InventorySnapshot(boxes: boxes, items: snapshot.items, locations: locations))
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

    @MainActor
    func perform() async throws -> some ReturnsValue<Bool> {
        let baseline = try InventoryPersistence.loadBoxes()
        var boxes = baseline
        let box = try IntentInventoryLookup.resolve(boxIdentifier, in: boxes, name: { $0.name })
        guard let index = boxes.firstIndex(where: { $0.id == box.id }) else { throw IntentInventoryError.notFound }
        boxes[index].tags = IntentInventoryLookup.normalizedTags(tags)
        try InventoryPersistence.applyBoxChanges(from: baseline, to: boxes)
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

    @MainActor
    func perform() async throws -> some ReturnsValue<[String]> {
        let box = try IntentInventoryLookup.resolve(boxIdentifier, in: try InventoryPersistence.loadBoxes(), name: { $0.name })
        return .result(value: box.tags ?? [])
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

    @MainActor
    func perform() async throws -> some ReturnsValue<[String]> {
        let box = try IntentInventoryLookup.resolve(boxIdentifier, in: try InventoryPersistence.loadBoxes(), name: { $0.name })
        return .result(value: box.images)
    }
}

struct ListAllBoxIDsIntent: AppIntent {
    static let title = LocalizedStringResource("Get all box IDs")
    static let description = LocalizedStringResource("Returns the IDs of all existing boxes.")

    static var parameterSummary: some ParameterSummary {
        Summary("Get all box IDs")
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<[String]> {
        let boxes = try InventoryPersistence.loadBoxes()
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

    @MainActor
    func perform() async throws -> some ReturnsValue<[String]> {
        let locations = try InventoryPersistence.loadLocations()
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

    @MainActor
    func perform() async throws -> some ReturnsValue<[String]> {
        let items = try InventoryPersistence.loadItems()
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

    @MainActor
    func perform() async throws -> some ReturnsValue<Bool> {
        // Shortcuts werden auch ohne sichtbare Scene gestartet. Diese explizite
        // Systemzustellung schützt den gesamten asynchronen Löschauftrag.
        guard let lease = InventoryBackgroundExecution.shared.begin(name: "Delete Location Intent", isContinuation: true)
        else { throw CancellationError() }
        let identifier = locationNameOrID
        let deleted = try await lease.perform {
            let inventory = try await InventoryDeletion.shared.inventory()
            let location = try IntentInventoryLookup.resolve(identifier, in: inventory.locations, name: { $0.name })
            return try await InventoryDeletion.shared.locations([location.id])
        }
        return .result(value: deleted)
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

    @MainActor
    func perform() async throws -> some ReturnsValue<Bool> {
        guard let lease = InventoryBackgroundExecution.shared.begin(name: "Delete Image Intent", isContinuation: true)
        else { throw CancellationError() }
        let name = fileName
        let deleted = try await lease.perform { try await InventoryDeletion.shared.image(name) }
        return .result(value: deleted)
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

    @MainActor
    func perform() async throws -> some ReturnsValue<Bool> {
        guard let lease = InventoryBackgroundExecution.shared.begin(name: "Delete Box Intent", isContinuation: true)
        else { throw CancellationError() }
        let identifier = boxIdentifier
        let removePhotos = deleteImages
        let deleted = try await lease.perform {
            let inventory = try await InventoryDeletion.shared.inventory()
            let box = try IntentInventoryLookup.resolve(identifier, in: inventory.boxes, name: { $0.name })
            // Der gemeinsame Pfad prüft aktuelle Kinder erneut unmittelbar vor dem Commit.
            return try await InventoryDeletion.shared.boxes([box.id], onlyIfEmpty: true, deletePhotos: removePhotos)
        }
        return .result(value: deleted)
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

    @MainActor
    func perform() async throws -> some ReturnsValue<Bool> {
        guard let lease = InventoryBackgroundExecution.shared.begin(name: "Delete Item Intent", isContinuation: true)
        else { throw CancellationError() }
        let identifier = itemNameOrID
        let deleted = try await lease.perform {
            let inventory = try await InventoryDeletion.shared.inventory()
            let item = try IntentInventoryLookup.resolve(identifier, in: inventory.items, name: { $0.name })
            return try await InventoryDeletion.shared.items([item.id])
        }
        return .result(value: deleted)
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

    @MainActor
    func perform() async throws -> some ReturnsValue<Bool> {
        let baseline = try InventoryPersistence.loadBoxes()
        var boxes = baseline
        let box = try IntentInventoryLookup.resolve(boxIdentifier, in: boxes, name: { $0.name })
        guard let index = boxes.firstIndex(where: { $0.id == box.id }) else { throw IntentInventoryError.notFound }
        // Only attach real image files; filenames must remain inside app storage.
        _ = try IntentImageStore.files(named: [imageFilename])
        if !boxes[index].images.contains(imageFilename) {
            boxes[index].images.append(imageFilename)
            try InventoryPersistence.applyBoxChanges(from: baseline, to: boxes)
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
    
    @MainActor
    func perform() async throws -> some ReturnsValue<String> {
        let newItem = Items(
            id: UUID(),
            name: itemName
        )
        try InventoryPersistence.mergeInventory(boxes: [], items: [newItem], locations: [])
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

    @MainActor
    func perform() async throws -> some ReturnsValue<String?> {
        let box = try IntentInventoryLookup.resolve(boxReference, in: try InventoryPersistence.loadBoxes(), name: { $0.name })
        return .result(value: try InventoryPersistence.loadLocations().first(where: { $0.id == box.location_uuid })?.id.uuidString)
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

    @MainActor
    func perform() async throws -> some ReturnsValue<String?> {
        let box = try IntentInventoryLookup.resolve(boxReference, in: try InventoryPersistence.loadBoxes(), name: { $0.name })
        let name = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw IntentInventoryError.emptyName }
        let item = Items(id: UUID(), name: name, box_uuid: box.id)
        try InventoryPersistence.mergeInventory(boxes: [], items: [item], locations: [])
        return .result(value: item.id.uuidString)
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
    
    @MainActor
    func perform() async throws -> some ReturnsValue<Bool> {
        try IntentItemAssignment.assign(item: itemName, to: boxName)
        return .result(value: true)
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
    
    @MainActor
    func perform() async throws -> some ReturnsValue<[String]>{
        let box = try IntentInventoryLookup.resolve(boxName, in: try InventoryPersistence.loadBoxes(), name: { $0.name })
        return .result(value: try InventoryPersistence.loadItems().filter { $0.box_uuid == box.id }.map { $0.id.uuidString })
    }
}

struct FindItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Get item box ID"
    static let description = IntentDescription("Returns the ID of the box that contains the specified item.")
    
    @Parameter(title: "Name or ID")
    var itemName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Get box id for item \(\.$itemName)")
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<String?> {
        let item = try IntentInventoryLookup.resolve(itemName, in: try InventoryPersistence.loadItems(), name: { $0.name })
        let box = try InventoryPersistence.loadBoxes().first { $0.id == item.box_uuid }
        return .result(value: box?.id.uuidString)
    }
}

struct FindItemWithSiriIntent: AppIntent {
    static let title: LocalizedStringResource = "Get item box (Siri)"
    static let description = IntentDescription("Find the box and the location of a specific item.")
    
    @Parameter(title: "Name or ID")
    var itemName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Search item \(\.$itemName)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let items = try InventoryPersistence.loadItems()
        let boxes = try InventoryPersistence.loadBoxes()
        let locations = try InventoryPersistence.loadLocations()

        let item = try IntentInventoryLookup.resolve(itemName, in: items, name: { $0.name })

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

    @MainActor
    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let boxes = try InventoryPersistence.loadBoxes()
        let items = try InventoryPersistence.loadItems()
        let locations = try InventoryPersistence.loadLocations()

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

    @MainActor
    func perform() async throws -> some ReturnsValue<[String]> {
        let locations = try InventoryPersistence.loadLocations()
        let boxes = try InventoryPersistence.loadBoxes()

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

    @MainActor
    func perform() async throws -> some ReturnsValue<[String]> {
        let items = try InventoryPersistence.loadItems()
        let boxes = try InventoryPersistence.loadBoxes()
        let boxIDs = Set(boxes.map(\.id))

        let unassignedItemNames = items
            .filter { item in item.box_uuid.map { !boxIDs.contains($0) } ?? true }
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

    @MainActor
    func perform() async throws -> some ReturnsValue<String?> & ProvidesDialog {
        let locations = try InventoryPersistence.loadLocations()
        let boxes = try InventoryPersistence.loadBoxes()
        let items = try InventoryPersistence.loadItems()

        let location = try IntentInventoryLookup.resolve(locationIdentifier, in: locations, name: { $0.name })
        let locationID = location.id

        let boxesAtLocation = boxes.filter { $0.location_uuid == locationID }
        let boxIDs = Set(boxesAtLocation.map(\.id))
        let itemsAtLocation = items.filter { item in item.box_uuid.map { boxIDs.contains($0) } ?? false }

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

    @MainActor
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

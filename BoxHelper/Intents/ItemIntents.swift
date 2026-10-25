import AppIntents
import Foundation
import UniformTypeIdentifiers

@available(iOS 18.0, *)
struct AddImagesToItemIntent: AppIntent {
    static let title = LocalizedStringResource("Add images to item")
    static let description = IntentDescription("Add one or more photos to an item and recognize tags in the background. Returns the saved image file names.")
    @Parameter(title: "Images", supportedContentTypes: [.image], inputConnectionBehavior: .connectToPreviousIntentResult)
    var images: [IntentFile]
    @Parameter(title: "Name or ID") var itemReference: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$images) to item \(\.$itemReference)")
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<[String]> {
        let id = try IntentInventoryLookup.resolve(itemReference, in: try InventoryPersistence.loadItems(), name: { $0.name }).id
        let photos = try await IntentImageStore.prepare(images)
        let tags = await IntentImageStore.tags(for: photos)
        // Reload after suspension: a concurrent edit must not be overwritten by an old snapshot.
        let baseline = try InventoryPersistence.loadItems()
        var items = baseline
        guard let index = items.firstIndex(where: { $0.id == id }) else { throw IntentInventoryError.notFound }
        let names = try IntentImageStore.save(photos)
        items[index].images += names
        items[index].tags = IntentInventoryLookup.normalizedTags((items[index].tags ?? []) + tags)
        try IntentImageStore.commit(names) { try InventoryPersistence.applyItemChanges(from: baseline, to: items) }
        return .result(value: names)
    }
}

struct GetItemImagesIntent: AppIntent {
    static let title = LocalizedStringResource("Get item images")
    static let description = IntentDescription("Returns the item's photos as image files for sharing or further processing.")
    @Parameter(title: "Name or ID") var itemReference: String

    static var parameterSummary: some ParameterSummary {
        Summary("Get images of item \(\.$itemReference)")
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<[IntentFile]> {
        let item = try IntentInventoryLookup.resolve(itemReference, in: try InventoryPersistence.loadItems(), name: { $0.name })
        return .result(value: try IntentImageStore.files(named: item.images))
    }
}

struct SetItemTagsIntent: AppIntent {
    static let title = LocalizedStringResource("Set item tags")
    static let description = IntentDescription("Replace an item's tags or append tags while preserving existing tags.")
    @Parameter(title: "Name or ID") var itemReference: String
    @Parameter(title: "Tags") var tags: [String]
    @Parameter(title: "Keep existing tags", default: true) var keepExisting: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Set tags \(\.$tags) for item \(\.$itemReference)") { \.$keepExisting }
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<Bool> {
        let baseline = try InventoryPersistence.loadItems()
        var items = baseline
        let item = try IntentInventoryLookup.resolve(itemReference, in: items, name: { $0.name })
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { throw IntentInventoryError.notFound }
        items[index].tags = IntentInventoryLookup.normalizedTags((keepExisting ? item.tags ?? [] : []) + tags)
        try InventoryPersistence.applyItemChanges(from: baseline, to: items)
        return .result(value: true)
    }
}

struct GetItemTagsIntent: AppIntent {
    static let title = LocalizedStringResource("Get item tags")
    static let description = IntentDescription("Returns all tags assigned to an item.")
    @Parameter(title: "Name or ID") var itemReference: String

    static var parameterSummary: some ParameterSummary {
        Summary("Get tags of item \(\.$itemReference)")
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<[String]> {
        let item = try IntentInventoryLookup.resolve(itemReference, in: try InventoryPersistence.loadItems(), name: { $0.name })
        return .result(value: item.tags ?? [])
    }
}

struct RenameItemIntent: AppIntent {
    static let title = LocalizedStringResource("Rename item")
    static let description = IntentDescription("Change an item's name while keeping its photos, tags, and box assignment.")
    @Parameter(title: "Name or ID") var itemReference: String
    @Parameter(title: "New name") var newName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Rename item \(\.$itemReference) to \(\.$newName)")
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<String> {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw IntentInventoryError.emptyName }
        let baseline = try InventoryPersistence.loadItems()
        var items = baseline
        let item = try IntentInventoryLookup.resolve(itemReference, in: items, name: { $0.name })
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { throw IntentInventoryError.notFound }
        items[index].name = name
        try InventoryPersistence.applyItemChanges(from: baseline, to: items)
        return .result(value: item.id.uuidString)
    }
}

struct GetItemLocationIntent: AppIntent {
    static let title = LocalizedStringResource("Get item location ID")
    static let description = IntentDescription("Returns the location ID through the item's box, or no value if it has no assigned location.")
    @Parameter(title: "Name or ID") var itemReference: String

    static var parameterSummary: some ParameterSummary {
        Summary("Get location ID of item \(\.$itemReference)")
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<String?> {
        let item = try IntentInventoryLookup.resolve(itemReference, in: try InventoryPersistence.loadItems(), name: { $0.name })
        let locationID = try InventoryPersistence.loadBoxes().first(where: { $0.id == item.box_uuid })?.location_uuid
        let location = try InventoryPersistence.loadLocations().first(where: { $0.id == locationID })
        return .result(value: location?.id.uuidString)
    }
}

/// Assign an existing item by its stable ID, including items created by earlier shortcut actions.
struct AssignItemByIDToBoxIntent: AppIntent {
    static let title = LocalizedStringResource("Set item box by ID")
    static let description = IntentDescription("Assign an existing item to a box using its item ID. Any previous box assignment is replaced.")
    @Parameter(title: "Item ID") var itemID: String
    @Parameter(title: "Box name or ID") var boxReference: String

    static var parameterSummary: some ParameterSummary {
        Summary("Assign item with ID \(\.$itemID) to box \(\.$boxReference)")
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<Bool> {
        guard let id = UUID(uuidString: itemID.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw IntentInventoryError.invalidItemID
        }
        try IntentItemAssignment.assign(item: id.uuidString, to: boxReference)
        return .result(value: true)
    }
}

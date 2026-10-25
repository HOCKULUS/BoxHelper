import AppIntents
import Foundation
import UniformTypeIdentifiers

@available(iOS 18.0, *)
struct SetLocationImageIntent: AppIntent {
    static let title = LocalizedStringResource("Set location image")
    static let description = IntentDescription("Set or replace the single photo of a location. Returns the saved image file name.")
    @Parameter(title: "Image", supportedContentTypes: [.image], inputConnectionBehavior: .connectToPreviousIntentResult)
    var image: IntentFile
    @Parameter(title: "Name or ID") var locationReference: String

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$image) as image of location \(\.$locationReference)")
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<String> {
        let id = try IntentInventoryLookup.resolve(locationReference, in: try InventoryPersistence.loadLocations(), name: { $0.name }).id
        let photos = try await IntentImageStore.prepare([image])
        let baseline = try InventoryPersistence.loadLocations()
        var locations = baseline
        guard let index = locations.firstIndex(where: { $0.id == id }) else { throw IntentInventoryError.notFound }
        let names = try IntentImageStore.save(photos)
        locations[index].image = names[0]
        // Preserve the previous file: it may still be referenced by another inventory object.
        try IntentImageStore.commit(names) { try InventoryPersistence.applyLocationChanges(from: baseline, to: locations) }
        return .result(value: names[0])
    }
}

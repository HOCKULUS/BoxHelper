import Foundation
@preconcurrency import CoreSpotlight
import UniformTypeIdentifiers

private let spotlightEnabledKey = "spotlightIndexingEnabled"

func isSpotlightIndexingEnabled() -> Bool {
    // A missing preference enables Spotlight; an explicit opt-out remains respected.
    let defaults = UserDefaults.standard
    return defaults.object(forKey: spotlightEnabledKey) == nil || defaults.bool(forKey: spotlightEnabledKey)
}

func setSpotlightIndexingEnabled(_ isEnabled: Bool) {
    UserDefaults.standard.set(isEnabled, forKey: spotlightEnabledKey)
    rebuildSpotlightIndex()
}

func scheduleSpotlightReindexIfEnabled() {
    guard isSpotlightIndexingEnabled() else { return }
    Task { await BoxSpotlightIndexer.shared.schedule() }
}

func rebuildSpotlightIndex() {
    Task { await BoxSpotlightIndexer.shared.schedule(immediately: true) }
}

/// A value snapshot keeps database access on the main actor and index work off the UI thread.
struct SpotlightBoxDocument: Sendable {
    let identifier: String
    let title: String
    let description: String
    let keywords: [String]
    let createdAt: Date
    let updatedAt: Date
    let thumbnailURL: URL?

    /// Auf dem MainActor werden nur die bestätigten DTO-Arrays übernommen. Sortierung,
    /// Keywords und Dateiprüfungen laufen anschließend auf dem Spotlight-Actor.
    struct Inventory: Sendable {
        let boxes: [MovingBox]
        let items: [Items]
        let locations: [Locations]
        let documentsDirectory: URL?
    }

    @MainActor static func loadInventory() -> Inventory {
        Inventory(boxes: loadBoxes(), items: loadItems(), locations: loadLocations(),
            documentsDirectory: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
    }

    @MainActor static func loadSnapshot() -> [SpotlightBoxDocument] {
        build(loadInventory())
    }

    static func build(_ inventory: Inventory) -> [SpotlightBoxDocument] {
        let boxes = inventory.boxes
        let itemsByBox = Dictionary(grouping: inventory.items, by: \.box_uuid)
        // Duplicate IDs in imported data should never crash Spotlight indexing.
        let locationsByID = Dictionary(inventory.locations.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let documentsDirectory = inventory.documentsDirectory

        return boxes.map { box in
            let items = itemsByBox[box.id] ?? []
            let location = box.location_uuid.flatMap { locationsByID[$0] }
            let rawLocationName = (location?.name ?? box.category).trimmingCharacters(in: .whitespacesAndNewlines)
            let locationName = rawLocationName.isEmpty ? NSLocalizedString("Spotlight.NoLocation", comment: "") : rawLocationName
            let title = box.name.isEmpty ? NSLocalizedString("CreateView.Box", comment: "") + " " + box.id.uuidString : box.name
            // Preserve repeated names: each line represents one actual item in the box.
            let names = (items.isEmpty ? box.items : items.map(\.name))
                .map { $0.isEmpty ? NSLocalizedString("CreateView.Item", comment: "") : $0 }
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            let itemList = names.isEmpty
                ? NSLocalizedString("Spotlight.EmptyBox", comment: "Empty box in Spotlight")
                : names.map { "• " + $0 }.joined(separator: "\n")
            let description = "\(NSLocalizedString("Location", comment: "")): \(locationName)\nID: \(box.id.uuidString)\n\n\(NSLocalizedString("Items", comment: "")):\n\(itemList)"
            let tags = (box.tags ?? []) + items.flatMap { $0.tags ?? [] }
            let keywords = normalizedKeywords([title, locationName, box.id.uuidString,
                                              box.id.uuidString.replacingOccurrences(of: "-", with: "")] + names + tags)
            let thumbnailURL = box.images.lazy.compactMap { filename -> URL? in
                guard let url = documentsDirectory?.appendingPathComponent(filename),
                      FileManager.default.fileExists(atPath: url.path) else { return nil }
                return url
            }.first
            return SpotlightBoxDocument(identifier: "box:\(box.id.uuidString)", title: title,
                                        description: description, keywords: keywords, createdAt: box.createdAt,
                                        updatedAt: ([box.updatedAt] + items.map(\.updatedAt) + [location?.updatedAt].compactMap { $0 }).max() ?? box.updatedAt,
                                        thumbnailURL: thumbnailURL)
        }
    }

    func searchableItem(domain: String) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = title
        attributes.displayName = title
        attributes.contentDescription = description
        // The complete list stays searchable even when Spotlight abbreviates the visible preview.
        attributes.textContent = ([title, description] + keywords).joined(separator: "\n")
        attributes.identifier = identifier
        attributes.keywords = keywords
        attributes.contentCreationDate = createdAt
        attributes.contentModificationDate = updatedAt
        attributes.thumbnailURL = thumbnailURL
        let item = CSSearchableItem(uniqueIdentifier: identifier, domainIdentifier: domain, attributeSet: attributes)
        item.expirationDate = .distantFuture
        return item
    }

    private static func normalizedKeywords(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else { return nil }
            return trimmed
        }
    }
}

/// Serializes index operations so a late update cannot restore entries after disabling Spotlight.
private actor BoxSpotlightIndexer {
    static let shared = BoxSpotlightIndexer()
    private let boxDomain = "de.hockulus.boxhelper.spotlight.boxes"
    private let allDomains = ["de.hockulus.boxhelper.spotlight.boxes",
                              "de.hockulus.boxhelper.spotlight.items",
                              "de.hockulus.boxhelper.spotlight.locations"]
    private let identifiersKey = "spotlightIndexedBoxIdentifiers"
    private let schemaKey = "spotlightBoxIndexSchema"
    private let schemaVersion = 1
    private var requestedRevision = 0
    private var completedRevision = 0
    private var isUpdating = false

    func schedule(immediately: Bool = false) {
        requestedRevision += 1
        let revision = requestedRevision
        Task {
            // Coalesce the box/item/location writes of a single save into one index update.
            if !immediately { try? await Task.sleep(for: .milliseconds(350)) }
            await refresh(revision: revision)
        }
    }

    private func refresh(revision: Int) async {
        guard revision == requestedRevision, revision > completedRevision, !isUpdating else { return }
        isUpdating = true
        let defaults = UserDefaults.standard
        let index = CSSearchableIndex.default()
        do {
            if !isSpotlightIndexingEnabled() {
                try await index.deleteSearchableItems(withDomainIdentifiers: allDomains)
                defaults.removeObject(forKey: identifiersKey)
                defaults.removeObject(forKey: schemaKey)
            } else {
                let inventory = await SpotlightBoxDocument.loadInventory()
                let documents = SpotlightBoxDocument.build(inventory)
                let identifiers = Set(documents.map(\.identifier))
                if defaults.integer(forKey: schemaKey) != schemaVersion {
                    // Remove old item/location entries and orphaned boxes from the previous implementation.
                    try await index.deleteSearchableItems(withDomainIdentifiers: allDomains)
                } else {
                    let previous = Set(defaults.stringArray(forKey: identifiersKey) ?? [])
                    let removed = Array(previous.subtracting(identifiers))
                    if !removed.isEmpty { try await index.deleteSearchableItems(withIdentifiers: removed) }
                }
                try await index.indexSearchableItems(documents.map { $0.searchableItem(domain: boxDomain) })
                // Only remember a successful update so failed operations are repaired on the next run.
                defaults.set(Array(identifiers).sorted(), forKey: identifiersKey)
                defaults.set(schemaVersion, forKey: schemaKey)
            }
        } catch {
            print("Spotlight indexing failed: \(error)")
        }
        completedRevision = revision
        isUpdating = false
        // A save or opt-out during an async operation must get a final pass with the latest data.
        if requestedRevision > revision { await refresh(revision: requestedRevision) }
    }
}

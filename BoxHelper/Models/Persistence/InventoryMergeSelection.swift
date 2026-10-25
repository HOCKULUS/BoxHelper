import Foundation
import SwiftData

/// Kleine moderne Formular-Commits benötigen ausschließlich die betroffenen UUIDs.
/// Legacy-/Bulkimporte verwenden weiterhin den vollständigen Normalisierungspfad.
@MainActor
struct InventoryMergeSelection {
    var inventory: InventorySnapshot
    let boxes: [StoredBox]
    let items: [StoredItem]
    let locations: [StoredLocation]
    let boxPosition: Int
    let itemPosition: Int
    let locationPosition: Int
    var deleted: InventoryObjectIDs = .empty

    static func prepare(_ incoming: InventorySnapshot, context: ModelContext,
                        repairMissingLocations: Bool,
                        detachRestoredItems: Bool = false) throws -> InventoryMergeSelection? {
        guard incoming.boxes.count + incoming.items.count + incoming.locations.count <= 100,
              incoming.boxes.allSatisfy({ $0.items.isEmpty && $0.category.isEmpty }) else { return nil }
        let boxIDs = incoming.boxes.map(\.id)
        let itemIDs = incoming.items.map(\.id)
        let locationIDs = Array(Set(incoming.locations.map(\.id) + incoming.boxes.compactMap(\.location_uuid)))
        let boxes = boxIDs.isEmpty ? [] : try context.fetch(FetchDescriptor<StoredBox>(predicate: #Predicate { boxIDs.contains($0.id) }))
        let items = itemIDs.isEmpty ? [] : try context.fetch(FetchDescriptor<StoredItem>(predicate: #Predicate { itemIDs.contains($0.id) }))
        let locations = locationIDs.isEmpty ? [] : try context.fetch(FetchDescriptor<StoredLocation>(predicate: #Predicate { locationIDs.contains($0.id) }))
        let knownLocations = try InventoryNativeDeletion.active(locations, in: context).map(\.value)
        let providedIDs = Set(incoming.locations.map(\.id))
        let knownIDs = Set(knownLocations.map(\.id))
        var working = incoming
        working.locations = knownLocations.filter { !providedIDs.contains($0.id) } + incoming.locations
        let deletedParents = try InventoryIntegritySelection.deletedParents(for: working, context: context,
            restoring: .init(boxes: Set(incoming.boxes.map(\.id)), locations: providedIDs))
        if detachRestoredItems {
            working = InventoryIntegritySelection.detachRestoredItems(working, ids: Set(incoming.items.map(\.id)), deletedBoxes: deletedParents.boxes)
        }
        let blockedItems = detachRestoredItems ? [] : incoming.items.filter { $0.box_uuid.map(deletedParents.boxes.contains) == true }
        working = InventoryIntegritySelection.clean(working, deleted: deletedParents)
        // Auch noch unbekannte Kinder-UUIDs erhalten ausschließlich einen Journal-
        // Eintrag. Ein künstlich eingefügter leerer Nutzdatensatz ist nicht nötig.
        for value in blockedItems {
            let parentVersion = try value.box_uuid.flatMap {
                try InventoryDeletionLedger.deletedVersion(kind: "box", key: $0.uuidString, in: context)
            } ?? .distantPast
            try InventoryDeletionLedger.recordDeletion(kind: "item", key: value.id.uuidString,
                at: max(parentVersion, value.updatedAt), in: context)
        }
        var normalized = DataManager.normalized(working, repairMissingLocations: repairMissingLocations)
        // Referenzierte vorhandene Standorte werden nur gelesen, nicht mitgeschrieben.
        normalized.locations.removeAll { knownIDs.contains($0.id) && !providedIDs.contains($0.id) }
        return InventoryMergeSelection(inventory: normalized, boxes: boxes, items: items, locations: locations,
            boxPosition: normalized.boxes.isEmpty ? 0 : try nextBoxPosition(in: context),
            itemPosition: normalized.items.isEmpty ? 0 : try nextItemPosition(in: context),
            locationPosition: normalized.locations.isEmpty ? 0 : try nextLocationPosition(in: context),
            deleted: .init(items: Set(blockedItems.map(\.id))))
    }

    // TestFlight-Build 36 stürzte unter iOS 27.0.1 in nextPosition<Record> ab:
    // SwiftData konnte den Protokoll-Schlüsselpfad (\Record.position) im
    // SortDescriptor nicht dem Modellschema zuordnen. Dieser Framework-FatalError
    // ist nicht mit do/catch abfangbar. Jede Sortierung verwendet deshalb den
    // Schlüsselpfad ihrer konkreten @Model-Klasse statt des InventoryRecord-Protokolls.
    // fetchLimit hält auch große Bestände begrenzt; gelöschte Positionen dürfen Lücken lassen.
    private static func nextBoxPosition(in context: ModelContext) throws -> Int {
        var request = FetchDescriptor<StoredBox>(sortBy: [SortDescriptor(\StoredBox.position, order: .reverse)])
        request.fetchLimit = 1
        return try context.fetch(request).first.map { $0.position + 1 } ?? 0
    }

    private static func nextItemPosition(in context: ModelContext) throws -> Int {
        var request = FetchDescriptor<StoredItem>(sortBy: [SortDescriptor(\StoredItem.position, order: .reverse)])
        request.fetchLimit = 1
        return try context.fetch(request).first.map { $0.position + 1 } ?? 0
    }

    private static func nextLocationPosition(in context: ModelContext) throws -> Int {
        var request = FetchDescriptor<StoredLocation>(sortBy: [SortDescriptor(\StoredLocation.position, order: .reverse)])
        request.fetchLimit = 1
        return try context.fetch(request).first.map { $0.position + 1 } ?? 0
    }
}

import Foundation
import SwiftData

/// Fachliche Integrität für die bestehenden UUID-Fremdschlüssel. Eine unbekannte
/// Eltern-UUID bleibt erhalten; nur ein gewinnender Tombstone löst die Löschregel aus.
enum InventoryIntegritySelection {
    struct ParentState {
        let deleted: InventoryDeletedIDs
        let boxRevisions: [UUID: Date]
    }
    @MainActor
    static func children(of boxes: Set<UUID>, context: ModelContext) throws -> [Items] {
        guard !boxes.isEmpty else { return [] }
        let parents: [UUID?] = boxes.map(Optional.some)
        let matches = try context.fetch(FetchDescriptor<StoredItem>(predicate: #Predicate { parents.contains($0.box_uuid) }))
        let ids = Array(Set(matches.map(\.id)))
        guard !ids.isEmpty else { return [] }
        // Ein älterer physischer Zwilling kann noch die alte Kiste referenzieren.
        // Deshalb alle Zeilen seiner UUID prüfen, bevor ein verschobenes Item gelöscht wird.
        let rows = try context.fetch(FetchDescriptor<StoredItem>(predicate: #Predicate { ids.contains($0.id) }))
        return try InventoryNativeDeletion.active(rows, in: context).filter { $0.box_uuid.map(boxes.contains) == true }.map(\.value)
    }

    @MainActor
    static func boxes(at locations: Set<UUID>, context: ModelContext) throws -> [MovingBox] {
        guard !locations.isEmpty else { return [] }
        let parents: [UUID?] = locations.map(Optional.some)
        let matches = try context.fetch(FetchDescriptor<StoredBox>(predicate: #Predicate { parents.contains($0.location_uuid) }))
        let ids = Array(Set(matches.map(\.id)))
        guard !ids.isEmpty else { return [] }
        let rows = try context.fetch(FetchDescriptor<StoredBox>(predicate: #Predicate { ids.contains($0.id) }))
        return try InventoryNativeDeletion.active(rows, in: context).filter { $0.location_uuid.map(locations.contains) == true }.map(\.value)
    }

    static func clean(_ inventory: InventorySnapshot, deleted: InventoryDeletedIDs,
                      preservingDates: Bool = false) -> InventorySnapshot {
        var result = inventory
        result.items.removeAll { $0.box_uuid.map(deleted.boxes.contains) == true }
        for index in result.boxes.indices where result.boxes[index].location_uuid.map(deleted.locations.contains) == true {
            let date = result.boxes[index].updatedAt
            result.boxes[index].location_uuid = nil
            // Eine alte Kategorie darf den ausdrücklich entfernten Standort nicht
            // beim nächsten Legacy-Import unter einem anderen Namen neu erzeugen.
            result.boxes[index].category = ""
            if preservingDates { result.boxes[index].updatedAt = date }
        }
        return result
    }

    /// Ein ausdrücklicher Item-Import darf seinen Inhalt wiederherstellen, ohne
    /// einen gelöschten Elternteil zu erfinden. Solche Items werden unzugeordnet;
    /// verspätete normale Cloud-Kopien folgen weiterhin der Kaskadenregel.
    static func detachRestoredItems(_ inventory: InventorySnapshot, ids: Set<UUID>, deletedBoxes: Set<UUID>) -> InventorySnapshot {
        var result = inventory
        for index in result.items.indices where ids.contains(result.items[index].id)
            && result.items[index].box_uuid.map(deletedBoxes.contains) == true {
            result.items[index].box_uuid = nil
        }
        return result
    }

    static func deletedParents(for inventory: InventorySnapshot, context: ModelContext,
                               restoring: InventoryObjectIDs = .empty) throws -> InventoryDeletedIDs {
        try parentState(for: inventory, context: context, restoring: restoring).deleted
    }

    static func parentState(for inventory: InventorySnapshot, context: ModelContext,
                            restoring: InventoryObjectIDs = .empty) throws -> ParentState {
        let boxIDs = Array(Set(inventory.items.compactMap(\.box_uuid)).subtracting(restoring.boxes))
        let locationIDs = Array(Set(inventory.boxes.compactMap(\.location_uuid)).subtracting(restoring.locations))
        let boxes = boxIDs.isEmpty ? [] : try context.fetch(FetchDescriptor<StoredBox>(predicate: #Predicate { boxIDs.contains($0.id) }))
        let locations = locationIDs.isEmpty ? [] : try context.fetch(FetchDescriptor<StoredLocation>(predicate: #Predicate { locationIDs.contains($0.id) }))
        var boxVersions = try InventoryNativeDeletion.deletedVersions(for: StoredBox.self, ids: Set(boxIDs), in: context)
        boxVersions.merge(try InventoryNativeDeletion.deletedVersions(for: boxes, in: context)) { max($0, $1) }
        var locationVersions = try InventoryNativeDeletion.deletedVersions(for: StoredLocation.self, ids: Set(locationIDs), in: context)
        locationVersions.merge(try InventoryNativeDeletion.deletedVersions(for: locations, in: context)) { max($0, $1) }
        // Neuere aktive Eltern können vor ihrem Restore-Journal eintreffen.
        for parent in try InventoryNativeDeletion.active(boxes, in: context) { boxVersions.removeValue(forKey: parent.id) }
        for parent in try InventoryNativeDeletion.active(locations, in: context) { locationVersions.removeValue(forKey: parent.id) }
        return ParentState(deleted: .init(boxes: Set(boxVersions.keys), locations: Set(locationVersions.keys)),
                           boxRevisions: boxVersions)
    }

    /// Die reine Prüfung wird im Snapshot-Worker auf den bereits gelesenen Zeilen
    /// ausgeführt. Auch später importierte aktive UUID-Zwillinge müssen konvergieren.
    static func candidates(boxes: [StoredBox], items: [StoredItem], locations: [StoredLocation], context: ModelContext) throws -> InventoryIntegrityCandidates {
        let boxWinners = try InventoryRecordSelection.winners(boxes)
        let itemWinners = try InventoryRecordSelection.winners(items)
        let deletedBoxes = Set(try InventoryNativeDeletion.deletedVersions(for: boxes, in: context, includeAll: true).keys)
        let deletedItems = Set(try InventoryNativeDeletion.deletedVersions(for: items, in: context, includeAll: true).keys)
        let deletedLocations = Set(try InventoryNativeDeletion.deletedVersions(for: locations, in: context, includeAll: true).keys)
        return InventoryIntegrityCandidates(
            boxes: Set(boxWinners.filter { !deletedBoxes.contains($0.id) && $0.location_uuid.map(deletedLocations.contains) == true }.map(\.id))
                .union(boxes.filter { deletedBoxes.contains($0.id) }.map(\.id)),
            items: Set(itemWinners.filter { !deletedItems.contains($0.id) && $0.box_uuid.map(deletedBoxes.contains) == true }.map(\.id))
                .union(items.filter { deletedItems.contains($0.id) }.map(\.id)),
            locations: Set(locations.filter { deletedLocations.contains($0.id) }.map(\.id)))
    }

    @MainActor
    static func changes(_ candidates: InventoryIntegrityCandidates, context: ModelContext) throws -> (
        before: InventorySnapshot, after: InventorySnapshot,
        boxes: [StoredBox], items: [StoredItem], locations: [StoredLocation], itemDeletionVersions: [UUID: Date]) {
        let boxIDs = Array(candidates.boxes), itemIDs = Array(candidates.items), locationIDs = Array(candidates.locations)
        let boxes = boxIDs.isEmpty ? [] : try context.fetch(FetchDescriptor<StoredBox>(predicate: #Predicate { boxIDs.contains($0.id) }))
        let items = itemIDs.isEmpty ? [] : try context.fetch(FetchDescriptor<StoredItem>(predicate: #Predicate { itemIDs.contains($0.id) }))
        let locations = locationIDs.isEmpty ? [] : try context.fetch(FetchDescriptor<StoredLocation>(predicate: #Predicate { locationIDs.contains($0.id) }))
        let boxWinners = try InventoryRecordSelection.winners(boxes)
        let itemWinners = try InventoryRecordSelection.winners(items)
        let locationWinners = try InventoryRecordSelection.winners(locations)
        // Tombstone-Werte sind hier nur UUID-Träger für das Konvergieren verspäteter
        // physischer Duplikate. Ihr bereits gelöschter Inhalt wird nie wieder angelegt.
        let before = InventorySnapshot(boxes: boxWinners.map(\.value), items: itemWinners.map(\.value), locations: locationWinners.map(\.value))
        var after = before
        let parents = try parentState(for: before, context: context)
        after = clean(after, deleted: parents.deleted)
        var itemDeletionVersions: [UUID: Date] = [:]
        for item in itemWinners where !item.isTombstoned {
            guard let parent = item.box_uuid, let revision = parents.boxRevisions[parent] else { continue }
            // Eine abgeleitete Kaskade bekommt die Version ihrer Ursache. Date.now
            // würde eine noch unterwegs befindliche neuere Verschiebung überstimmen.
            itemDeletionVersions[item.id] = max(revision, max(item.updatedAt, item.syncChangedAt))
        }
        let deadBoxes = Set(try InventoryNativeDeletion.deletedVersions(for: boxes, in: context).keys)
        let deadItems = Set(try InventoryNativeDeletion.deletedVersions(for: items, in: context).keys)
        let deadLocations = Set(try InventoryNativeDeletion.deletedVersions(for: locations, in: context).keys)
        after.boxes.removeAll { deadBoxes.contains($0.id) }
        after.items.removeAll { deadItems.contains($0.id) }
        after.locations.removeAll { deadLocations.contains($0.id) }
        return (before, after, boxes, items, locations, itemDeletionVersions)
    }
}

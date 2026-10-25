import Foundation
import SwiftData

/// Kleine Feldänderungen, Anhängen und explizite Löschungen lesen nur betroffene UUIDs.
/// Reordering und Legacy-Normalisierung behalten den vollständigen Transaktionspfad.
@MainActor
enum InventoryChangeSelection {
    static func prepare(from baseline: InventorySnapshot, to desired: InventorySnapshot,
                        deleting deleted: InventoryObjectIDs = .empty,
                        preservingDeletedIDs baselineIDs: InventoryObjectIDs,
                        preservingDeletionsAfter cutoff: Date? = nil,
                        context: ModelContext,
                        repairMissingLocations: Bool) throws -> InventoryMergeSelection? {
        guard desired.boxes.count + desired.items.count + desired.locations.count + deleted.count <= 100,
              desired.boxes.allSatisfy({ $0.items.isEmpty && $0.category.isEmpty }) else { return nil }
        let boxIDs = Array(Set(desired.boxes.map(\.id)).union(deleted.boxes))
        let itemIDs = Array(Set(desired.items.map(\.id)).union(deleted.items))
        let locationIDs = Array(Set(desired.locations.map(\.id)).union(deleted.locations))
        let boxes = boxIDs.isEmpty ? [] : try context.fetch(FetchDescriptor<StoredBox>(predicate: #Predicate { boxIDs.contains($0.id) }))
        let items = itemIDs.isEmpty ? [] : try context.fetch(FetchDescriptor<StoredItem>(predicate: #Predicate { itemIDs.contains($0.id) }))
        let locations = locationIDs.isEmpty ? [] : try context.fetch(FetchDescriptor<StoredLocation>(predicate: #Predicate { locationIDs.contains($0.id) }))
        let boxWinners = try InventoryRecordSelection.winners(boxes)
        let itemWinners = try InventoryRecordSelection.winners(items)
        let locationWinners = try InventoryRecordSelection.winners(locations)
        var patched = try InventorySnapshot(
            boxes: InventoryFieldChanges.boxes(from: baseline.boxes, to: desired.boxes, in: InventoryNativeDeletion.active(boxes, in: context).map(\.value)),
            items: InventoryFieldChanges.items(from: baseline.items, to: desired.items, in: InventoryNativeDeletion.active(items, in: context).map(\.value)),
            locations: InventoryFieldChanges.locations(from: baseline.locations, to: desired.locations, in: InventoryNativeDeletion.active(locations, in: context).map(\.value)))
        // Normale Patches und ein nach Prozessabbruch wiederholter Eingang beleben
        // keine Tombstones. Ein geteilter Remote-Restore darf ausdrücklich nur frühere
        // Löschungen überwinden; seit Beginn des Empfangs erfolgte lokale Löschungen bleiben.
        let blockedBoxes = try protectedIDs(boxWinners, baseline: baselineIDs.boxes, cutoff: cutoff, context: context, including: Set(boxIDs))
        let blockedItems = try protectedIDs(itemWinners, baseline: baselineIDs.items, cutoff: cutoff, context: context, including: Set(itemIDs))
        let blockedLocations = try protectedIDs(locationWinners, baseline: baselineIDs.locations, cutoff: cutoff, context: context, including: Set(locationIDs))
        patched.boxes.removeAll { blockedBoxes.contains($0.id) || deleted.boxes.contains($0.id) }
        patched.items.removeAll { blockedItems.contains($0.id) || deleted.items.contains($0.id) }
        patched.locations.removeAll { blockedLocations.contains($0.id) || deleted.locations.contains($0.id) }
        guard var selection = try InventoryMergeSelection.prepare(patched, context: context,
            repairMissingLocations: repairMissingLocations) else { return nil }
        let blockedReferencedLocations = try protectedIDs(try InventoryRecordSelection.winners(selection.locations),
            baseline: baselineIDs.locations, cutoff: cutoff, context: context,
            including: Set(selection.inventory.locations.map(\.id)))
        selection.inventory.locations.removeAll {
            blockedReferencedLocations.contains($0.id) || deleted.locations.contains($0.id)
        }
        // Die Auswahl für Upserts allein enthält keine gelöschten UUIDs. Alle physischen
        // Duplikate der gezielt gelöschten Datensätze müssen trotzdem im selben Commit
        // konvergieren; PersistentIdentifier verhindert doppelte Context-Referenzen.
        return InventoryMergeSelection(inventory: selection.inventory,
            boxes: combining(selection.boxes, with: boxes),
            items: combining(selection.items, with: items),
            locations: combining(selection.locations, with: locations),
            boxPosition: selection.boxPosition, itemPosition: selection.itemPosition,
            locationPosition: selection.locationPosition, deleted: selection.deleted)
    }

    static func protectedIDs<Record: InventoryRecord>(_ winners: [Record], baseline: Set<UUID>, cutoff: Date?,
                                                       context: ModelContext, including ids: Set<UUID>) throws -> Set<UUID> {
        // Auch bereits nativ entfernte gewünschte UUIDs prüfen, ohne für einen kurzen
        // Freigabe-Commit das Löschjournal des gesamten privaten Inventars einzulesen.
        let versions = try InventoryNativeDeletion.deletedVersions(for: winners, in: context, including: ids)
        return Set(versions.compactMap { id, version in
            if baseline.contains(id) || cutoff == nil || version >= cutoff! { return id }
            return nil
        })
    }

    private static func combining<Record: InventoryRecord>(_ first: [Record], with second: [Record]) -> [Record] {
        let identifiers = Set(first.map(\.persistentModelID))
        return first + second.filter { !identifiers.contains($0.persistentModelID) }
    }
}

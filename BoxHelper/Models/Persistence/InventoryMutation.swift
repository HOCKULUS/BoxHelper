import Foundation

/// Detail-Bindings ändern immer den frisch gelesenen Bestand. Dadurch können verspätete
/// OCR-Callbacks weder andere Datensätze überschreiben noch gelöschte Objekte erneut anlegen.
@MainActor
enum InventoryMutation {
    static func box(_ id: UUID, change: (inout MovingBox) -> Void) -> [MovingBox]? {
        update(id, load: { try InventoryPersistence.selection(boxIDs: [$0]).boxes }, committed: loadBoxes, save: InventoryPersistence.applyBoxChanges, change: change)
    }

    static func item(_ id: UUID, change: (inout Items) -> Void) -> [Items]? {
        update(id, load: { try InventoryPersistence.selection(itemIDs: [$0]).items }, committed: loadItems, save: InventoryPersistence.applyItemChanges, change: change)
    }

    static func location(_ id: UUID, change: (inout Locations) -> Void) -> [Locations]? {
        update(id, load: { try InventoryPersistence.selection(locationIDs: [$0]).locations }, committed: loadLocations, save: InventoryPersistence.applyLocationChanges, change: change)
    }

    static func items(change: (inout [Items]) -> Void) -> [Items]? {
        mutate(load: InventoryPersistence.loadItems, save: InventoryPersistence.applyItemChanges, change: change)
    }

    static func boxes(change: (inout [MovingBox]) -> Void) -> [MovingBox]? {
        mutate(load: InventoryPersistence.loadBoxes, save: InventoryPersistence.applyBoxChanges, change: change)
    }

    private static func update<Value: Identifiable>(_ id: UUID, load: (UUID) throws -> [Value], committed: () -> [Value],
                                                   save: ([Value], [Value]) throws -> Void,
                                                   change: (inout Value) -> Void) -> [Value]? where Value.ID == UUID {
        do {
            // Nur das Ziel frisch prüfen; die bestätigte Gesamt-Liste kommt nach dem
            // Commit aus dem gemeinsamen UI-Cache statt aus einem weiteren DB-Fetch.
            let baseline = try load(id)
            var values = baseline
            guard let index = values.firstIndex(where: { $0.id == id }) else { return nil }
            change(&values[index])
            try save(baseline, values)
            return committed()
        } catch {
            InventoryStorageState.shared.report(error)
            return nil
        }
    }

    private static func mutate<Value>(load: () throws -> [Value], save: ([Value], [Value]) throws -> Void,
                                      change: (inout [Value]) -> Void) -> [Value]? {
        do {
            let baseline = try load()
            var values = baseline
            change(&values)
            try save(baseline, values)
            return values
        } catch {
            InventoryStorageState.shared.report(error)
            return nil
        }
    }
}

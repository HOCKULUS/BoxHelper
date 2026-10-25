import Foundation

/// Logische UUID-Mengen eines bestätigten Commits; auch Item-Löschungen reisen als
/// kleine Wertkopien zum UI-Cache, ohne das SwiftData-Schema zu verändern.
struct InventoryObjectIDs: Equatable, Sendable {
    var boxes: Set<UUID> = []
    var items: Set<UUID> = []
    var locations: Set<UUID> = []

    static let empty = InventoryObjectIDs()
    var count: Int { boxes.count + items.count + locations.count }
}

/// Bereits bestätigte DTOs aktualisieren die UI ohne einen zweiten Komplett-Fetch.
/// Cloud-Importe ohne lokalen Commit lesen weiterhin einen neuen vollständigen Snapshot.
enum InventoryCommit: Sendable {
    case replace(InventorySnapshot)
    case merge(InventorySnapshot)
    case patch(InventorySnapshot, deleting: InventoryObjectIDs)

    var deletedIDs: InventoryObjectIDs {
        if case .patch(_, let deleted) = self { return deleted }
        return .empty
    }

    func applying(to current: InventorySnapshot?) -> InventorySnapshot? {
        switch self {
        case .replace(let inventory): return inventory
        case .merge(let additions):
            guard let current else { return nil }
            return InventorySnapshot(boxes: upsert(additions.boxes, into: current.boxes),
                                     items: upsert(additions.items, into: current.items),
                                     locations: upsert(additions.locations, into: current.locations))
        case .patch(let changes, let deleted):
            guard let current else { return nil }
            return InventorySnapshot(
                boxes: upsert(changes.boxes, into: current.boxes.filter { !deleted.boxes.contains($0.id) }),
                items: upsert(changes.items, into: current.items.filter { !deleted.items.contains($0.id) }),
                locations: upsert(changes.locations, into: current.locations.filter { !deleted.locations.contains($0.id) }))
        }
    }

    private func upsert<Value: Identifiable>(_ additions: [Value], into existing: [Value]) -> [Value] where Value.ID == UUID {
        let replacements = Dictionary(uniqueKeysWithValues: additions.map { ($0.id, $0) })
        let oldIDs = Set(existing.map(\.id))
        return existing.map { replacements[$0.id] ?? $0 } + additions.filter { !oldIDs.contains($0.id) }
    }
}

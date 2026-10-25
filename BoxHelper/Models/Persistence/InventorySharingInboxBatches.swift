import Foundation

/// Eine dauerhaft gespeicherte Inbox wird in kurzen, unabhängig wiederholbaren
/// SQLite-Schritten übernommen. Der Plan enthält ausschließlich Inventar-Wertkopien.
enum InventorySharingInboxBatches {
    struct Batch: Sendable {
        let names: Set<String>
        let before: InventorySnapshot
        let after: InventorySnapshot
    }

    static func plan(before: InventorySnapshot, after: InventorySnapshot, maximumCount: Int = 25) -> [Batch] {
        let limit = max(1, min(25, maximumCount))
        let locations = phases(before: before.locations, after: after.locations, prefix: "location", limit: limit) {
            InventorySnapshot(boxes: [], items: [], locations: $0)
        }
        let boxes = phases(before: before.boxes, after: after.boxes, prefix: "box", limit: limit) {
            InventorySnapshot(boxes: $0, items: [], locations: [])
        }
        let items = phases(before: before.items, after: after.items, prefix: "item", limit: limit) {
            InventorySnapshot(boxes: [], items: $0, locations: [])
        }
        // Referenzierte Eltern zuerst anlegen, Kinder zuerst entfernen. Die Reihenfolge
        // innerhalb einer Tabelle folgt den vorhandenen before-/after-UUID-Slots.
        return locations.upserts + boxes.upserts + items.upserts + items.deletions + boxes.deletions + locations.deletions
    }

    private static func phases<Value: Identifiable & Equatable>(before: [Value], after: [Value], prefix: String,
        limit: Int, inventory: ([Value]) -> InventorySnapshot) -> (upserts: [Batch], deletions: [Batch]) where Value.ID == UUID {
        let previous = Dictionary(before.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        let afterIDs = Set(after.map(\.id))
        let upserts = after.filter { previous[$0.id] != $0 }
        let deletions = before.filter { !afterIDs.contains($0.id) }
        func batches(_ values: [Value], deleting: Bool) -> [Batch] {
            stride(from: 0, to: values.count, by: limit).map { offset in
                let chunk = Array(values[offset..<min(values.count, offset + limit)])
                let ids = Set(chunk.map(\.id))
                return Batch(names: Set(ids.map { "\(prefix)-\($0)" }),
                             before: inventory(before.filter { ids.contains($0.id) }),
                             after: inventory(deleting ? [] : chunk))
            }
        }
        return (batches(upserts, deleting: false), batches(deletions, deleting: true))
    }
}

import Foundation

/// Formularänderungen patchen nur die gegenüber ihrer Ausgangskopie bearbeiteten Felder.
/// Andere Geräte können denselben Datensatz inzwischen an anderen Feldern verändert haben.
enum InventoryFieldChanges {
    static func boxes(from baseline: [MovingBox], to desired: [MovingBox], in current: [MovingBox]) -> [MovingBox] {
        applying(baseline: baseline, desired: desired, current: current) { old, edited, latest in
            var result = latest
            if old.name != edited.name { result.name = edited.name }
            if old.items != edited.items { result.items = edited.items }
            if old.images != edited.images { result.images = edited.images }
            if old.category != edited.category { result.category = edited.category }
            if old.location_uuid != edited.location_uuid { result.location_uuid = edited.location_uuid }
            if old.color != edited.color { result.color = edited.color }
            if old.tags != edited.tags { result.tags = edited.tags }
            if old.notes != edited.notes { result.notes = edited.notes }
            if old.createdAt != edited.createdAt { result.createdAt = edited.createdAt }
            result.updatedAt = max(latest.updatedAt, edited.updatedAt)
            return result
        }
    }

    static func items(from baseline: [Items], to desired: [Items], in current: [Items]) -> [Items] {
        applying(baseline: baseline, desired: desired, current: current) { old, edited, latest in
            var result = latest
            if old.name != edited.name { result.name = edited.name }
            if old.box_uuid != edited.box_uuid { result.box_uuid = edited.box_uuid }
            if old.description != edited.description { result.description = edited.description }
            if old.images != edited.images { result.images = edited.images }
            if old.category != edited.category { result.category = edited.category }
            if old.isFragile != edited.isFragile { result.isFragile = edited.isFragile }
            if old.isHeavy != edited.isHeavy { result.isHeavy = edited.isHeavy }
            if old.tags != edited.tags { result.tags = edited.tags }
            if old.createdAt != edited.createdAt { result.createdAt = edited.createdAt }
            result.updatedAt = max(latest.updatedAt, edited.updatedAt)
            return result
        }
    }

    static func locations(from baseline: [Locations], to desired: [Locations], in current: [Locations]) -> [Locations] {
        applying(baseline: baseline, desired: desired, current: current) { old, edited, latest in
            var result = latest
            if old.name != edited.name { result.name = edited.name }
            if old.color != edited.color { result.color = edited.color }
            if old.image != edited.image { result.image = edited.image }
            if old.createdAt != edited.createdAt { result.createdAt = edited.createdAt }
            result.updatedAt = max(latest.updatedAt, edited.updatedAt)
            return result
        }
    }

    static func orderChanged<Value: Identifiable>(from baseline: [Value], to desired: [Value]) -> Bool where Value.ID == UUID {
        let oldIDs = Set(baseline.map(\.id))
        let desiredIDs = Set(desired.map(\.id))
        let oldOrder = baseline.filter { desiredIDs.contains($0.id) }.map(\.id)
        let newOrder = desired.filter { oldIDs.contains($0.id) }.map(\.id)
        return oldOrder != newOrder || !desiredIDs.subtracting(oldIDs).isEmpty
    }

    private static func applying<Value: Identifiable & Equatable>(
        baseline: [Value], desired: [Value], current: [Value],
        patch: (Value, Value, Value) -> Value
    ) -> [Value] where Value.ID == UUID {
        let oldByID = Dictionary(uniqueKeysWithValues: baseline.map { ($0.id, $0) })
        let desiredIDs = Set(desired.map(\.id))
        let deletedIDs = Set(oldByID.keys).subtracting(desiredIDs)
        var result = current.filter { !deletedIDs.contains($0.id) }
        let indices = Dictionary(uniqueKeysWithValues: result.enumerated().map { ($0.element.id, $0.offset) })
        for value in desired where oldByID[value.id] != value {
            if let index = indices[value.id] {
                result[index] = oldByID[value.id].map { patch($0, value, result[index]) } ?? value
            } else if oldByID[value.id] == nil {
                // Eine inzwischen nativ gelöschte Ausgangs-UUID wird von einer alten
                // Formularantwort nicht neu angelegt. Echte neue UUIDs bleiben zulässig.
                result.append(value)
            }
        }
        guard orderChanged(from: baseline, to: desired) else { return result }

        // Bekannte UUIDs folgen der ausdrücklich gewünschten Reihenfolge. Neu eingetroffene
        // Cloud-UUIDs behalten ihren Platz zwischen diesen Slots und werden nie verworfen.
        let latestByID = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0) })
        let ordered = desired.compactMap { latestByID[$0.id] }
        let knownIDs = Set(oldByID.keys).union(desiredIDs)
        var index = 0
        var arranged: [Value] = []
        for value in result {
            if knownIDs.contains(value.id) {
                if index < ordered.count { arranged.append(ordered[index]); index += 1 }
            } else {
                arranged.append(value)
            }
        }
        arranged.append(contentsOf: ordered.dropFirst(index))
        return arranged
    }
}

import Foundation

enum RecentBoxWidgetSnapshot {
    static func build(boxes: [MovingBox], items: [Items], locations: [Locations] = []) -> RecentBoxWidgetData {
        RecentBoxWidgetData(boxes: allBoxes(boxes: boxes, items: items, locations: locations))
    }

    /// Die vollständige Projektion versorgt auch Standort-Widgets. Erst der Snapshot
    /// für die zuletzt geänderten Kisten begrenzt seine eigene Liste auf 32 Einträge.
    static func allBoxes(boxes: [MovingBox], items: [Items], locations: [Locations]) -> [RecentBoxWidgetData.Box] {
        // Änderungen am Inhalt zählen ebenfalls als Änderung der zugehörigen Kiste.
        let itemDates = Dictionary(items.compactMap { item in
            item.box_uuid.map { ($0, item.updatedAt) }
        }, uniquingKeysWith: { max($0, $1) })
        let locationsByID = Dictionary(locations.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first })
        // Kisten aus älteren Beständen können ihren Standort noch über den Namen zuordnen.
        let locationsByName = Dictionary(locations.map {
            ($0.name.trimmingCharacters(in: .whitespacesAndNewlines), $0)
        }, uniquingKeysWith: { first, _ in first })
        let entries = boxes.map { box in
            let location: Locations?
            if let id = box.location_uuid {
                location = locationsByID[id]
            } else {
                let legacyName = box.category.trimmingCharacters(in: .whitespacesAndNewlines)
                location = legacyName.isEmpty ? nil : locationsByName[legacyName]
            }
            // Alte Bestände ohne Standort-UUID können noch den Kategorienamen tragen.
            let locationName = (location?.name ?? box.category)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return RecentBoxWidgetData.Box(id: box.id, name: box.name,
                locationName: locationName.isEmpty ? nil : locationName, locationID: location?.id,
                color: location?.color ?? "",
                updatedAt: max(box.updatedAt, itemDates[box.id] ?? box.updatedAt))
        }.sorted(by: RecentBoxWidgetData.Box.newestFirst)
        var seen = Set<UUID>()
        return entries.filter { seen.insert($0.id).inserted }
    }
}

import Foundation

enum LocationBoxWidgetSnapshot {
    static func build(locations: [Locations], boxes: [RecentBoxWidgetData.Box]) -> LocationBoxWidgetData {
        let boxesByLocation = Dictionary(grouping: boxes.compactMap { box in
            box.locationID.map { ($0, box) }
        }, by: { $0.0 })
        var seen = Set<UUID>()
        let entries = locations.filter { seen.insert($0.id).inserted }.map { location in
            let locationBoxes = (boxesByLocation[location.id] ?? []).map { $0.1 }
                .sorted(by: RecentBoxWidgetData.Box.newestFirst)
            return LocationBoxWidgetData.Location(id: location.id,
                name: location.name.trimmingCharacters(in: .whitespacesAndNewlines),
                color: location.color, boxes: locationBoxes)
        }.sorted {
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.id.uuidString < $1.id.uuidString
                : comparison == .orderedAscending
        }
        // Auch leere Standorte müssen im Bearbeiten-Dialog auswählbar sein.
        return LocationBoxWidgetData(locations: entries)
    }
}

import Foundation
import WidgetKit

struct LocationBoxesEntry: TimelineEntry {
    let date: Date
    let location: LocationBoxWidgetData.Location?
    let boxes: [RecentBoxWidgetData.Box]
    let needsSelection: Bool

    init(location: LocationBoxWidgetData.Location?, size: Int,
         needsSelection: Bool = false, date: Date = .now) {
        self.date = date
        self.location = location
        // Auch ältere Cache-Dateien können noch alphabetisch sortiert sein. Vor dem
        // Begrenzen auf die Widget-Größe immer die neuesten Kisten auswählen.
        self.boxes = Array((location?.boxes ?? []).sorted(by: RecentBoxWidgetData.Box.newestFirst)
            .prefix(max(0, size)))
        self.needsSelection = needsSelection
    }

    static let previewLocation: LocationBoxWidgetData.Location = {
        let id = UUID(uuidString: "00000000-0000-0000-0001-000000000000")!
        let color = "0.18,0.48,0.90"
        let name = String(localized: "Widget.Sample.Location.Basement")
        let boxes = RecentBoxesEntry.previewBoxes.map {
            RecentBoxWidgetData.Box(id: $0.id, name: $0.name, locationName: name,
                                   locationID: id, color: color, updatedAt: $0.updatedAt)
        }.sorted(by: RecentBoxWidgetData.Box.newestFirst)
        return LocationBoxWidgetData.Location(id: id, name: name, color: color, boxes: boxes)
    }()
}

struct LocationBoxesProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LocationBoxesEntry {
        LocationBoxesEntry(location: LocationBoxesEntry.previewLocation,
                           size: RecentBoxesWidgetLayout(family: context.family).boxCount)
    }

    func snapshot(for configuration: LocationBoxesConfigurationIntent, in context: Context) async -> LocationBoxesEntry {
        if context.isPreview && configuration.location == nil { return placeholder(in: context) }
        return currentEntry(for: configuration, family: context.family)
    }

    func timeline(for configuration: LocationBoxesConfigurationIntent, in context: Context) async -> Timeline<LocationBoxesEntry> {
        let entry = currentEntry(for: configuration, family: context.family)
        return Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(3600)))
    }

    /// Immer den aktuellen Datensatz lesen: Der Intent kann noch einen alten Namen
    /// enthalten, nachdem der Standort umbenannt, neu gefärbt oder gelöscht wurde.
    func currentEntry(for configuration: LocationBoxesConfigurationIntent, family: WidgetFamily,
                      storeURL: URL? = nil) -> LocationBoxesEntry {
        let size = RecentBoxesWidgetLayout(family: family).boxCount
        guard let id = configuration.location?.id else {
            return LocationBoxesEntry(location: nil, size: size, needsSelection: true)
        }
        let location = LocationBoxWidgetStore.read(from: storeURL)?.location(id: id)
        return LocationBoxesEntry(location: location, size: size)
    }
}

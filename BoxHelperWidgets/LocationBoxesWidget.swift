import SwiftUI
import WidgetKit

struct LocationBoxesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: LocationBoxWidgetData.kind, intent: LocationBoxesConfigurationIntent.self,
                               provider: LocationBoxesProvider()) { entry in
            LocationBoxesWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color(uiColor: .systemBackground) }
        }
        .configurationDisplayName("Boxes by location")
        .description("Choose a location to see its recently changed boxes.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

private struct LocationBoxesWidgetEntryView: View {
    let entry: LocationBoxesEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        LocationBoxesWidgetView(entry: entry, layout: RecentBoxesWidgetLayout(family: family))
    }
}

#Preview("Standort klein", as: .systemSmall) { LocationBoxesWidget() } timeline: {
    LocationBoxesEntry(location: LocationBoxesEntry.previewLocation, size: 4)
}
#Preview("Standort mittel", as: .systemMedium) { LocationBoxesWidget() } timeline: {
    LocationBoxesEntry(location: LocationBoxesEntry.previewLocation, size: 8)
}
#Preview("Standort groß", as: .systemLarge) { LocationBoxesWidget() } timeline: {
    LocationBoxesEntry(location: LocationBoxesEntry.previewLocation, size: 16)
}
#Preview("Standort extra groß", as: .systemExtraLarge) { LocationBoxesWidget() } timeline: {
    LocationBoxesEntry(location: LocationBoxesEntry.previewLocation, size: 32)
}

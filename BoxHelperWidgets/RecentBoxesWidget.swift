import SwiftUI
import WidgetKit

@main
struct BoxHelperWidgets: WidgetBundle {
    var body: some Widget {
        RecentBoxesWidget()
        LocationBoxesWidget()
    }
}

struct RecentBoxesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: RecentBoxWidgetData.kind, provider: RecentBoxesProvider()) { entry in
            RecentBoxesWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color(uiColor: .systemBackground) }
        }
        .configurationDisplayName("Recent boxes")
        .description("Open your most recently changed boxes.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

/// WidgetKit bestimmt die Größe; die eigentliche Raster-View bekommt nur ihr Layout.
private struct RecentBoxesWidgetEntryView: View {
    let entry: RecentBoxesEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        RecentBoxesWidgetView(boxes: entry.boxes, layout: RecentBoxesWidgetLayout(family: family))
    }
}

#Preview("Klein", as: .systemSmall) {
    RecentBoxesWidget()
} timeline: {
    RecentBoxesEntry(date: .now, boxes: RecentBoxesEntry.previewBoxes)
}

#Preview("Mittel", as: .systemMedium) {
    RecentBoxesWidget()
} timeline: {
    RecentBoxesEntry(date: .now, boxes: RecentBoxesEntry.previewBoxes)
}

#Preview("Groß", as: .systemLarge) {
    RecentBoxesWidget()
} timeline: {
    RecentBoxesEntry(date: .now, boxes: RecentBoxesEntry.previewBoxes)
}

#Preview("Extra groß", as: .systemExtraLarge) {
    RecentBoxesWidget()
} timeline: {
    RecentBoxesEntry(date: .now, boxes: RecentBoxesEntry.previewBoxes)
}

#Preview("Leer", as: .systemSmall) {
    RecentBoxesWidget()
} timeline: {
    RecentBoxesEntry(date: .now, boxes: [])
}

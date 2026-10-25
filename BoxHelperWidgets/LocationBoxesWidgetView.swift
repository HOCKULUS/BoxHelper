import SwiftUI
import WidgetKit

struct LocationBoxesWidgetView: View {
    let entry: LocationBoxesEntry
    let layout: RecentBoxesWidgetLayout

    var body: some View {
        content.padding(10)
    }

    @ViewBuilder
    private var content: some View {
        if entry.needsSelection {
            message(icon: "location", title: String(localized: "Choose a location"),
                    description: String(localized: "Edit this widget to choose a location."))
        } else if let location = entry.location {
            if location.boxes.isEmpty {
                message(icon: "shippingbox", title: displayName(location),
                        description: String(localized: "No boxes at this location."))
            } else {
                BoxWidgetGrid(boxes: entry.boxes, layout: layout)
            }
        } else {
            message(icon: "location.slash", title: String(localized: "Location unavailable"),
                    description: String(localized: "Choose another location in the widget settings."))
        }
    }

    private func displayName(_ location: LocationBoxWidgetData.Location) -> String {
        location.name.isEmpty ? String(localized: "Unnamed location") : location.name
    }

    private func message(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
                .widgetAccentable()
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .privacySensitive()
            Text(description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

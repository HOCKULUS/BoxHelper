import SwiftUI
import WidgetKit

struct RecentBoxesWidgetView: View {
    let boxes: [RecentBoxWidgetData.Box]
    let layout: RecentBoxesWidgetLayout

    var body: some View {
        content
            // Eigene, kleinere Außenränder geben den Kacheln mehr Platz.
            .padding(10)
    }

    @ViewBuilder
    private var content: some View {
        if boxes.isEmpty {
            emptyState
        } else {
            BoxWidgetGrid(boxes: boxes, layout: layout)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "shippingbox")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.secondary)
                .widgetAccentable()
            Text("No boxes yet")
                .font(.subheadline.weight(.semibold))
            Text("Create a box in BoxHelper to see it here.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


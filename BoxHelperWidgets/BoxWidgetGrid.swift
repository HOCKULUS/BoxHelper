import SwiftUI
import WidgetKit

/// Beide Widgets teilen ihr Raster, die Standortfarben und die Kisten-Navigation.
struct BoxWidgetGrid: View {
    let boxes: [RecentBoxWidgetData.Box]
    let layout: RecentBoxesWidgetLayout

    var body: some View {
        GeometryReader { geometry in
            // Gleich große Zeilen füllen jede Widget-Größe. Die Kisten
            // erscheinen von links oben nach rechts unten.
            let spacing = CGFloat(layout.rows - 1) * 6
            let height = max(0, (geometry.size.height - spacing) / CGFloat(layout.rows))
            VStack(spacing: 6) {
                ForEach(0..<layout.rows, id: \.self) { rowIndex in
                    row(startingAt: rowIndex * layout.columns, height: height)
                }
            }
        }
    }

    private func row(startingAt start: Int, height: CGFloat) -> some View {
        HStack(spacing: 6) {
            ForEach(start..<(start + layout.columns), id: \.self) { index in
                if index < boxes.count {
                    let box = boxes[index]
                    Button(intent: OpenRecentBoxIntent(boxID: box.id)) {
                        BoxWidgetTile(box: box, isCompact: height < 62)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(box.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? String(localized: "Unnamed box") : box.name)
                    .accessibilityValue(box.locationName ?? String(localized: "No location"))
                    .accessibilityHint(Text("Open box in BoxHelper"))
                } else {
                    // Freie Plätze bleiben neutral und öffnen keine erfundene Kiste.
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemFill).opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(height: height)
    }
}

private struct BoxWidgetTile: View {
    let box: RecentBoxWidgetData.Box
    let isCompact: Bool
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: isCompact ? 16 : 20, weight: .regular))
                .foregroundStyle(tint)
                .widgetAccentable()
            Spacer(minLength: isCompact ? 1 : 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(box.locationName ?? String(localized: "No location"))
                    .font(.system(size: isCompact ? 9 : 10, weight: .light))
                    .foregroundStyle(.secondary)
                Text(box.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? String(localized: "Unnamed box") : box.name)
                    .font(.system(size: isCompact ? 10 : 11, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            // Beide Namen bleiben einzeilig und schneiden lange Texte mit einer Ellipse ab.
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .privacySensitive()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, isCompact ? 5 : 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemFill).opacity(0.5))
        }
    }

    private var tint: Color {
        // Im getönten Modus übernimmt iOS die Akzentfarbe des Homescreens.
        guard renderingMode == .fullColor else { return .primary }
        // Die App übergibt die Standortfarbe. Fehlende oder ungültige Farben bleiben neutral.
        let components = box.color.split(separator: ",").compactMap { Double($0) }
        guard components.count == 3, components.allSatisfy({ $0.isFinite && (0...1).contains($0) })
        else { return .secondary }
        return Color(red: components[0], green: components[1], blue: components[2])
    }
}

import Foundation
import WidgetKit

struct RecentBoxesEntry: TimelineEntry {
    let date: Date
    let boxes: [RecentBoxWidgetData.Box]

    // Beispieldaten erscheinen ausschließlich in Galerie/Previews und Platzhaltern.
    private static let previewExamples = [
        (String(localized: "Widget.Sample.Box.Tools"), String(localized: "Widget.Sample.Location.Basement"), "0.18,0.48,0.90"),
        (String(localized: "Widget.Sample.Box.WinterClothes"), String(localized: "Widget.Sample.Location.Attic"), "0.68,0.35,0.85"),
        (String(localized: "Widget.Sample.Box.Kitchen"), String(localized: "Widget.Sample.Location.StorageRoom"), "0.91,0.48,0.18"),
        (String(localized: "Widget.Sample.Box.Keepsakes"), String(localized: "Widget.Sample.Location.LivingRoom"), "0.24,0.64,0.43"),
        (String(localized: "Widget.Sample.Box.Books"), String(localized: "Widget.Sample.Location.Office"), "0.18,0.48,0.90"),
        (String(localized: "Widget.Sample.Box.Toys"), String(localized: "Widget.Sample.Location.ChildrenRoom"), "0.68,0.35,0.85"),
        (String(localized: "Widget.Sample.Box.Camping"), String(localized: "Widget.Sample.Location.Garage"), "0.91,0.48,0.18"),
        (String(localized: "Widget.Sample.Box.Decorations"), String(localized: "Widget.Sample.Location.Attic"), "0.68,0.35,0.85")
    ]

    static let previewBoxes = (0..<RecentBoxWidgetData.maximumBoxCount).map { index in
        let example = previewExamples[index % previewExamples.count]
        let suffix = index < previewExamples.count ? "" : " \(index / previewExamples.count + 1)"
        return RecentBoxWidgetData.Box(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", index))!,
            name: example.0 + suffix, locationName: example.1, color: example.2, updatedAt: .distantPast)
    }
}

struct RecentBoxesProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentBoxesEntry {
        RecentBoxesEntry(date: .now, boxes: RecentBoxesEntry.previewBoxes)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentBoxesEntry) -> Void) {
        completion(RecentBoxesEntry(date: .now,
            boxes: context.isPreview ? RecentBoxesEntry.previewBoxes : currentBoxes()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentBoxesEntry>) -> Void) {
        let entry = RecentBoxesEntry(date: .now, boxes: currentBoxes())
        // App-Saves stoßen Reloads an. Der Zeitplan repariert zusätzlich einen vom
        // System verschobenen Reload, ohne die App oder CloudKit zu starten.
        completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(3600))))
    }

    private func currentBoxes() -> [RecentBoxWidgetData.Box] {
        RecentBoxWidgetStore.read()?.boxes ?? []
    }
}

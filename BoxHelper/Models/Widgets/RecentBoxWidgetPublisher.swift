import Foundation
import WidgetKit

@MainActor
enum RecentBoxWidgetPublisher {
    private static var revision = 0

    static func schedule() {
        // Nur bestätigte DTOs übernehmen; keine zusätzlichen DB-Fetches im UI-Pfad.
        let inventory = InventoryStorageState.shared.readSnapshot()
        revision += 1
        let requestedRevision = revision
        Task {
            await RecentBoxWidgetWriter.shared.publish(boxes: inventory.boxes,
                items: inventory.items, locations: inventory.locations, revision: requestedRevision)
        }
    }
}

private actor RecentBoxWidgetWriter {
    static let shared = RecentBoxWidgetWriter()
    private var latestRevision = 0

    func publish(boxes: [MovingBox], items: [Items], locations: [Locations], revision: Int) {
        // Ein verspäteter Task darf eine neuere Widget-Datei nicht überschreiben.
        guard revision > latestRevision else { return }
        latestRevision = revision
        let entries = RecentBoxWidgetSnapshot.allBoxes(boxes: boxes, items: items, locations: locations)
        do {
            let snapshot = RecentBoxWidgetData(boxes: entries)
            if try RecentBoxWidgetStore.write(snapshot) {
                WidgetCenter.shared.reloadTimelines(ofKind: RecentBoxWidgetData.kind)
            }
        } catch {
            print("Recent boxes widget update failed: \(error)")
        }
        do {
            let snapshot = LocationBoxWidgetSnapshot.build(locations: locations, boxes: entries)
            if try LocationBoxWidgetStore.write(snapshot) {
                WidgetCenter.shared.reloadTimelines(ofKind: LocationBoxWidgetData.kind)
            }
        } catch {
            print("Location boxes widget update failed: \(error)")
        }
    }
}

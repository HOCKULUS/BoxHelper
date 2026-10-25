import Foundation
import Combine
import SwiftData

/// UI-Adapter für vorhandene Wert-Bindings. Ein Lesefehler liefert höchstens den letzten
/// erfolgreichen Snapshot; ein Schreibfehler wird sichtbar und niemals als Erfolg behandelt.
@MainActor
final class InventoryStorageState: ObservableObject {
    static let shared = InventoryStorageState()
    @Published private(set) var isInitialized = false
    @Published private(set) var revision = 0
    @Published private(set) var mediaRevision = 0
    @Published var errorMessage: String?
    private var lastSnapshot = InventorySnapshot.empty
    private var lastDeletedIDs = InventoryDeletedIDs.empty
    private var hasCurrentSnapshot = false
    private(set) var localCommitRevision = 0

    func initialize() {
        do {
            let store = try InventoryPersistence.prepare()
            lastSnapshot = try store.snapshot()
            lastDeletedIDs = try store.deletedIDs()
            hasCurrentSnapshot = true
            // Die UI verwendet ausschließlich DTOs. Ein Container im View-Zustand
            // würde den bisherigen CloudKit-Store beim Umschalten weiter festhalten.
            isInitialized = true
            errorMessage = nil
        } catch { report(error) }
    }

    func readSnapshot() -> InventorySnapshot {
        // Alle UI-Adapter teilen denselben bestätigten DTO-Bestand. Ein Renderdurchlauf
        // mit Kisten, Items und Standorten darf die DB nicht dreimal vollständig lesen.
        guard !hasCurrentSnapshot else { return lastSnapshot }
        do {
            let inventory = try InventoryPersistence.snapshot()
            lastDeletedIDs = try InventoryPersistence.prepare().deletedIDs()
            lastSnapshot = inventory
            hasCurrentSnapshot = true
            return inventory
        } catch {
            report(error)
            return lastSnapshot
        }
    }

    @discardableResult
    func save(_ action: () throws -> Void) -> Bool {
        do {
            try action()
            return true
        } catch {
            report(error)
            return false
        }
    }

    func didCommit(_ commit: InventoryCommit? = nil) {
        localCommitRevision += 1
        let previous = lastSnapshot
        let previousDeletedIDs = lastDeletedIDs
        // Lokale Commits bringen bereits bestätigte Werte mit. Cloud-Importe verwenden
        // applyRemoteSnapshot; sie dürfen hier keinen vollständigen UI-Fetch auslösen.
        if let confirmed = commit?.applying(to: hasCurrentSnapshot ? lastSnapshot : nil) {
            let boxIDs = Set(confirmed.boxes.map(\.id))
            let locationIDs = Set(confirmed.locations.map(\.id))
            lastDeletedIDs.boxes.formUnion(Set(lastSnapshot.boxes.map(\.id)).subtracting(boxIDs))
            lastDeletedIDs.locations.formUnion(Set(lastSnapshot.locations.map(\.id)).subtracting(locationIDs))
            // Ein Sync kann eine bislang nicht sichtbare UUID löschen. Deren expliziter
            // Tombstone gehört trotzdem in den Cache, auch ohne vorherigen DTO-Eintrag.
            lastDeletedIDs.boxes.formUnion(commit?.deletedIDs.boxes ?? [])
            lastDeletedIDs.locations.formUnion(commit?.deletedIDs.locations ?? [])
            lastDeletedIDs.boxes.subtract(boxIDs)
            lastDeletedIDs.locations.subtract(locationIDs)
            lastSnapshot = confirmed
            hasCurrentSnapshot = true
        } else {
            hasCurrentSnapshot = false
            do {
                lastSnapshot = try InventoryPersistence.snapshot()
                lastDeletedIDs = try InventoryPersistence.prepare().deletedIDs()
                hasCurrentSnapshot = true
            }
            catch { report(error) }
        }
        if previous != lastSnapshot || previousDeletedIDs != lastDeletedIDs { revision += 1 }
    }

    /// Tombstone-Prüfungen in onReceive/onChange lesen ausschließlich den UI-Cache.
    func readDeletedIDs() -> InventoryDeletedIDs {
        _ = readSnapshot()
        return lastDeletedIDs
    }

    /// Intents können den Store vor der ersten sichtbaren UI öffnen. Eine anschließende
    /// Hintergrundreparatur braucht trotzdem einen Cache für ihre kleinen Patches;
    /// sie darf dafür keinen vollständigen MainActor-Fetch aus didCommit auslösen.
    func seedForIntegrityRepair(_ snapshot: InventoryRemoteSnapshot) {
        guard !hasCurrentSnapshot else { return }
        lastSnapshot = InventoryIntegritySelection.clean(snapshot.inventory, deleted: snapshot.deletedIDs, preservingDates: true)
        lastDeletedIDs = snapshot.deletedIDs
        hasCurrentSnapshot = true
    }

    @discardableResult
    func applyRemoteSnapshot(_ snapshot: InventoryRemoteSnapshot) -> Bool {
        let changed = lastSnapshot != snapshot.inventory || lastDeletedIDs != snapshot.deletedIDs
        lastSnapshot = snapshot.inventory
        lastDeletedIDs = snapshot.deletedIDs
        hasCurrentSnapshot = true
        if changed { revision += 1 }
        return changed
    }

    /// Neue Fotodateien ändern nur die Darstellung, nicht den bestätigten Inventarbestand.
    func didUpdateMedia() { mediaRevision += 1; revision += 1 }

    func report(_ error: Error) {
        // Nicht synchron während einer View-Auswertung @Published verändern.
        let message = error.localizedDescription
        Task { @MainActor in self.errorMessage = message }
    }
}

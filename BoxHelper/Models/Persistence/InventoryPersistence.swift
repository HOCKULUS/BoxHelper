import Foundation
import SwiftData

extension Notification.Name {
    static let inventoryDidChange = Notification.Name("inventoryDidChange")
}

/// Dieselbe Instanz wird auch ohne sichtbare App aus Siri/Shortcuts geöffnet und migriert.
/// Throwing-Zugriffe lassen Imports und Intents Speicherfehler an ihren Aufrufer melden.
@MainActor
enum InventoryPersistence {
    private static let session = InventoryStoreSession()
    private static var notificationTask: Task<Void, Never>?
    private static let remoteRefresh = InventoryRemoteRefreshController(storage: .shared, publish: { inventory in
        InventorySharingService.shared.observeRemoteChange(inventory: inventory)
        notifyInventoryObservers()
    }, observe: { result in
        try prepare().trash.reconcile(result.inventory, deletionDates: result.trashDeletionDates)
    }, reconciled: {
        InventoryCloudPreferencesStore.shared.scheduleReconciliation()
    })

    static func prepare() throws -> InventoryStore {
        InventoryCloudSyncState.shared.configureRuntimeChange(changeCloudSyncConfiguration)
        // In der kurzen internen SwiftData-Freigabephase keinen zweiten Store öffnen.
        // Ein abgewiesener Save erhält die noch offenen Formularwerte unverändert.
        guard !session.isReplacing else { throw InventoryCloudSyncError.changing }
        if let store = session.store { return store }
        // Die einmalige Entwicklungsschema-Initialisierung ist nur mit einem expliziten
        // Debug-Launchargument aktiv. Sie öffnet niemals parallel den Inventar-Store.
        do {
            try InventoryCloudDevelopmentSchema.initializeIfRequested()
            InventorySharingDevelopmentSchema.initializeIfRequested()
        }
        catch { InventoryCloudSyncState.shared.recordSyncError(error) }
        // Beim Kaltstart die gespeicherte Wahl öffnen; spätere Änderungen laufen
        // durch den geregelten Worker-Abbau in changeCloudSyncConfiguration.
        var cloudEnabled = UserDefaults.standard.bool(forKey: CloudSyncPreferences.enabledKey)
            && CloudSyncPreferences.supportsCloudKit
        let store: InventoryStore
        if cloudEnabled {
            do {
                store = try session.open(cloudSyncEnabled: true)
            } catch {
                // Eine fehlerhafte Cloud-Konfiguration darf den Zugang zu den lokalen
                // Daten und zum Ausschalten der Option nicht sperren. Beide Modi öffnen
                // dieselbe Datei; ein echter lokaler Speicherfehler wird weitergeworfen.
                InventoryCloudSyncState.shared.recordSyncError(error)
                cloudEnabled = false
                store = try session.open(cloudSyncEnabled: false)
            }
        } else {
            store = try session.open(cloudSyncEnabled: false)
        }
        // Auch beim Start ohne iCloud alte UUID-Zuordnungen zu bekannten Tombstones
        // reparieren. Der Scan läuft auf dem Worker, die Commits bleiben begrenzt.
        remoteRefresh.request(container: store.container)
        InventoryCloudMediaWorker.backupDeletedPhotos = { photos, dates in
            let trash = try prepare().trash
            trash.commit(try trash.preparePhotos(photos, source: .cloud, deletionDates: dates))
        }
        // Kodieren/Bereinigen des UserDefaults-Archivs läuft nach dem Start mit
        // niedriger Priorität, während die App bereits bedienbar ist.
        Task { @MainActor in
            do { try await store.trash.cleanupInBackground() }
            catch { InventoryStorageState.shared.report(error) }
        }
        // Handoff bleibt unabhängig; der optionale Formularsync verwendet die
        // vorhandenen Entwurfsmodelle im privaten Cloud-Store.
        InventoryCloudPreferencesStore.shared.start()
        InventoryCloudSyncState.shared.markActive(cloudEnabled)
        InventoryHandoffStore.shared.configureCloudDrafts(InventoryCloudFormSync.shared)
        InventoryCloudFormSync.shared.start()
        if cloudEnabled {
            InventoryCloudSyncCoordinator.shared.start(container: store.container)
            InventorySharingService.shared.start()
        }
        return store
    }

    private static func changeCloudSyncConfiguration(
        _ enabled: Bool, validate: @escaping @MainActor () throws -> Void
    ) async throws {
        _ = try prepare()
        guard enabled != session.cloudSyncEnabled else { try validate(); return }
        InventoryStoreAccess.shared.pause()
        // Während des Abbaus bleibt der bisherige Store für synchrone Formular- und
        // Intent-Commits erreichbar. Neue Hintergrundaufträge werden zurückgehalten.
        await remoteRefresh.pauseAndWait()
        await InventoryCloudSyncCoordinator.shared.stopAndWait()
        await InventoryCloudPreferencesStore.shared.pauseAndWait()
        await InventorySharingService.shared.pauseAndWait()
        await InventoryStoreAccess.shared.waitUntilIdle()
        defer {
            InventoryStoreAccess.shared.resume()
            remoteRefresh.resume()
            InventoryCloudPreferencesStore.shared.resume()
            InventorySharingService.shared.resume()
            if let store = session.store {
                remoteRefresh.request(container: store.container)
                if session.cloudSyncEnabled {
                    InventoryCloudSyncCoordinator.shared.start(container: store.container)
                    InventorySharingService.shared.start()
                }
            }
        }
        // Die Session wartet auch auf SwiftDatas interne Save-Nachbearbeitung und
        // prüft vor dem Wiederöffnen erneut auf einen inzwischen erfolgten Reset.
        try validate()
        try await session.replace(cloudSyncEnabled: enabled, validate: validate)
        InventoryCloudSyncState.shared.markActive(enabled)
        if enabled {
            // Bereits bearbeitete Handoff-Formulare behalten ihre Werte und IDs und
            // nehmen bei aktivem Formular-Opt-in sofort am privaten Abgleich teil.
            do { try InventoryHandoffStore.shared.saveCurrentFormsToCloud() }
            catch { InventoryCloudSyncState.shared.recordFormsError(error) }
        }
    }

    static func snapshot() throws -> InventorySnapshot { try prepare().snapshot() }
    static func selection(boxIDs: [UUID] = [], itemIDs: [UUID] = [], locationIDs: [UUID]? = []) throws -> InventorySnapshot {
        try prepare().selection(boxIDs: boxIDs, itemIDs: itemIDs, locationIDs: locationIDs)
    }
    static func deletedIDs() throws -> InventoryDeletedIDs { try prepare().deletedIDs() }
    static func loadBoxes() throws -> [MovingBox] { try snapshot().boxes }
    static func loadItems() throws -> [Items] { try snapshot().items }
    static func loadLocations() throws -> [Locations] { try snapshot().locations }
    static func loadFirstLocations() throws -> [Locations] { try loadLocations() }

    static func saveBoxes(_ boxes: [MovingBox]) throws {
        // Auch ein Shortcut ohne sichtbare App muss den Store samt gecachten
        // Freigaberechten öffnen, bevor der Sharing-Service erstmals verwendet wird.
        let store = try prepare()
        try validateChanges {
            try (from: InventorySnapshot(boxes: store.snapshot().boxes, items: [], locations: []),
                 to: InventorySnapshot(boxes: boxes, items: [], locations: []))
        }
        if try store.saveBoxes(boxes) { didCommit(store) }
    }

    static func saveItems(_ items: [Items]) throws {
        let store = try prepare()
        try validateChanges {
            try (from: InventorySnapshot(boxes: [], items: store.snapshot().items, locations: []),
                 to: InventorySnapshot(boxes: [], items: items, locations: []))
        }
        if try store.saveItems(items) { didCommit(store) }
    }

    static func saveLocations(_ locations: [Locations]) throws {
        let store = try prepare()
        try validateChanges {
            try (from: InventorySnapshot(boxes: [], items: [], locations: store.snapshot().locations),
                 to: InventorySnapshot(boxes: [], items: [], locations: locations))
        }
        if try store.saveLocations(locations) { didCommit(store) }
    }

    static func saveInventory(boxes: [MovingBox], items: [Items], locations: [Locations]) throws {
        let store = try prepare()
        try validateChanges { (from: try store.snapshot(), to: InventorySnapshot(boxes: boxes, items: items, locations: locations)) }
        if try store.saveInventory(boxes: boxes, items: items, locations: locations) { didCommit(store) }
    }

    /// Anlegen und Zusammenführen ändern nur die übergebenen UUIDs. Zwischenzeitlich
    /// aus iCloud eingetroffene Datensätze werden dadurch nicht als Löschung behandelt.
    static func mergeInventory(boxes: [MovingBox], items: [Items], locations: [Locations]) throws {
        let store = try prepare()
        try validateChanges {
            // Eine vorhandene Freigabe mit Leserechten darf einen Formular-Save nicht
            // in einen Komplett-Fetch verwandeln. Für die Prüfung zählen nur diese UUIDs.
            let current = try store.selection(boxIDs: boxes.map(\.id), itemIDs: items.map(\.id),
                                              locationIDs: locations.map(\.id))
            return (from: current, to: InventorySnapshot(boxes: boxes, items: items, locations: locations))
        }
        if try store.mergeInventory(boxes: boxes, items: items, locations: locations) { didCommit(store) }
    }

    /// Mehrtabellenaktionen übernehmen ausschließlich die vom Benutzer geänderten UUIDs
    /// und ausdrücklich gelöschten Objekte. Unbekannte Cloud-Zugänge bleiben erhalten.
    static func applyInventoryChanges(from baseline: InventorySnapshot, to desired: InventorySnapshot) throws {
        let store = try prepare()
        try InventorySharingService.shared.validateChanges(from: baseline, to: desired)
        if try store.applyInventoryChanges(from: baseline, to: desired) { didCommit(store) }
    }

    static func applyBoxChanges(from baseline: [MovingBox], to desired: [MovingBox]) throws {
        try applyInventoryChanges(from: InventorySnapshot(boxes: baseline, items: [], locations: []),
                                  to: InventorySnapshot(boxes: desired, items: [], locations: []))
    }

    static func applyItemChanges(from baseline: [Items], to desired: [Items]) throws {
        try applyInventoryChanges(from: InventorySnapshot(boxes: [], items: baseline, locations: []),
                                  to: InventorySnapshot(boxes: [], items: desired, locations: []))
    }

    static func applyLocationChanges(from baseline: [Locations], to desired: [Locations]) throws {
        try applyInventoryChanges(from: InventorySnapshot(boxes: [], items: [], locations: baseline),
                                  to: InventorySnapshot(boxes: [], items: [], locations: desired))
    }

    static func clearInventory() throws {
        let store = try prepare()
        try validateChanges { (from: try store.snapshot(), to: .empty) }
        if try store.clearInventory() { didCommit(store) }
    }

    static func storageSize() throws -> Int { try prepare().storageSize() }

    /// Der Foto-Löschmarker und die native Datensatzlöschung werden bestätigt,
    /// bevor ein Aufrufer die zugehörige Documents-Datei entfernt.
    static func deleteCloudPhotos(_ names: Set<String>) throws {
        guard !names.isEmpty else { return }
        let store = try prepare()
        var photos = try InventoryCloudMediaStore.photoBackups(filenames: names, container: store.container)
        for name in names {
            let url = try InventoryDeletionPlan.photoURL(name, documents: store.trash.documents)
            if let bytes = try InventoryPhotoFileCoordinator.read(url).data { photos[name] = bytes }
        }
        let backup = try store.trash.preparePhotos(photos)
        try InventoryCloudMediaStore.delete(filenames: names, container: store.container)
        store.trash.commit(backup)
    }

    /// Einzelne Bilddateiänderungen (auch lose Import-Fotos) haben keinen Inventar-Commit.
    static func mediaDidChange() {
        InventoryStorageState.shared.didUpdateMedia()
        notifyInventoryObservers()
        guard InventoryCloudSyncState.shared.isActive else { return }
        InventoryCloudSyncState.shared.markPendingChanges()
        InventoryCloudSyncCoordinator.shared.scheduleReconciliation()
        InventorySharingService.shared.localMediaDidChange()
    }

    private static func didCommit(_ store: InventoryStore) {
        publishInventoryChanges(store.latestCommit)
        InventorySharingService.shared.recordLocalCommit(inventory: InventoryStorageState.shared.readSnapshot())
        if InventoryCloudSyncState.shared.isActive {
            InventoryCloudSyncState.shared.markPendingChanges()
            InventoryCloudSyncCoordinator.shared.scheduleReconciliation()
        }
    }

    /// Freigaben speichern bereits konfliktgeprüfte Werte. Ihr bestätigter Commit
    /// schützt ebenso wie ein Formular-Save vor einem älteren Hintergrund-Snapshot.
    static func didReceiveSharedCommit(_ store: InventoryStore) {
        publishInventoryChanges(store.latestCommit)
        InventoryCloudSyncState.shared.markPendingChanges()
    }

    /// Nach einem Cloud-Import frische DTOs lesen und dieselben UI-/Spotlight-Abonnenten
    /// informieren wie bei lokalen Änderungen. Kein neuer Save, kein Reconcile-Kreislauf.
    static func refreshAfterRemoteChange(refreshInventory: Bool = true, mediaChanged: Bool = false) {
        if mediaChanged || !refreshInventory {
            InventoryStorageState.shared.didUpdateMedia()
            notifyInventoryObservers()
        }
        guard refreshInventory else { return }
        do { remoteRefresh.request(container: try prepare().container) }
        catch { InventoryStorageState.shared.report(error) }
    }

    /// Ohne Freigaben mit Leserechten ist kein zweiter vollständiger DB-Snapshot nötig.
    /// Die Closure bleibt unausgeführt, bis die Rechteprüfung diese Daten benötigt.
    private static func validateChanges(_ comparison: () throws -> (from: InventorySnapshot, to: InventorySnapshot)) throws {
        guard InventorySharingService.shared.requiresChangeValidation else { return }
        let values = try comparison()
        try InventorySharingService.shared.validateChanges(from: values.from, to: values.to)
    }

    private static func publishInventoryChanges(_ commit: InventoryCommit? = nil) {
        InventoryStorageState.shared.didCommit(commit)
        notifyInventoryObservers()
    }

    private static func notifyInventoryObservers() {
        guard notificationTask == nil else { return }
        // Erst nach Abschluss der laufenden Formularaktion veröffentlichen. So kann kein
        // onReceive-Handler einen noch laufenden Speichervorgang mit alten Werten überschreiben.
        notificationTask = Task { @MainActor in
            notificationTask = nil
            RecentBoxWidgetPublisher.schedule()
            scheduleSpotlightReindexIfEnabled()
            NotificationCenter.default.post(name: .inventoryDidChange, object: nil)
        }
    }
}

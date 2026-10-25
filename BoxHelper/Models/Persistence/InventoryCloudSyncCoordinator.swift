import CloudKit
import CoreData
import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Beobachtet den tatsächlichen CloudKit-Abgleich und aktualisiert die bestehenden DTO-Listen.
/// Jeder geöffnete Container erhält einen eigenen Beobachter- und Worker-Lebenszyklus.
@MainActor
final class InventoryCloudSyncCoordinator {
    static let shared = InventoryCloudSyncCoordinator()

    private let state: InventoryCloudSyncState
    private let notifications: NotificationCenter
    private let reconcileMedia: @MainActor (ModelContainer) async throws -> Bool
    private let publishChanges: @MainActor (Bool, Bool) -> Void
    private let reconciliationDelay: Duration
    private var observers: [NSObjectProtocol] = []
    private var container: ModelContainer?
    private var storeURL: URL?
    private var storeIdentifier: String?
    private var activeEvents: [UUID: String] = [:]
    private var reconcileTask: Task<Void, Never>?
    private var needsReconciliation = false
    private var needsInventoryRefresh = false
    private var generation = 0

    init(state: InventoryCloudSyncState = .shared,
         notifications: NotificationCenter = .default,
         reconcileMedia: @escaping @MainActor (ModelContainer) async throws -> Bool = {
             try await InventoryCloudMediaWorker.reconcile(container: $0)
         },
         reconciliationDelay: Duration = .milliseconds(300),
         publishChanges: @escaping @MainActor (Bool, Bool) -> Void = {
             InventoryPersistence.refreshAfterRemoteChange(refreshInventory: $0, mediaChanged: $1)
         }) {
        self.state = state
        self.notifications = notifications
        self.reconcileMedia = reconcileMedia
        self.publishChanges = publishChanges
        self.reconciliationDelay = reconciliationDelay
    }

    func start(container: ModelContainer) {
        guard self.container == nil else { return }
        self.container = container
        storeURL = container.configurations.first(where: { !$0.isStoredInMemoryOnly })?.url.standardizedFileURL
        refreshStoreIdentifier()
        let observerGeneration = generation

        observers.append(notifications.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification,
                                                   object: nil, queue: nil) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            // Event ist Sendable; Notification mit beliebigem userInfo verlässt den Callback nicht.
            Task { @MainActor in
                guard let self, self.generation == observerGeneration else { return }
                self.receive(event)
            }
        })
        observers.append(notifications.addObserver(forName: .NSPersistentStoreRemoteChange,
                                                   object: nil, queue: nil) { [weak self] notification in
            let identifier = notification.userInfo?[NSStoreUUIDKey] as? String
            let url = notification.userInfo?[NSPersistentStoreURLKey] as? URL
            Task { @MainActor in
                guard let self, self.generation == observerGeneration else { return }
                self.receiveRemoteChange(identifier: identifier, url: url)
            }
        })
        observers.append(notifications.addObserver(forName: .CKAccountChanged, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == observerGeneration else { return }
                await self.refreshAfterForegroundOrAccountChange(generation: observerGeneration)
            }
        })
#if canImport(UIKit)
        observers.append(notifications.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                   object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == observerGeneration else { return }
                await self.refreshAfterForegroundOrAccountChange(generation: observerGeneration)
            }
        })
#endif
        // Bereits heruntergeladene Assets nach Prozessstart materialisieren und lokale Fotos
        // hochladen. CloudKit kann Metadaten und Fotos in getrennten Importen liefern.
        scheduleReconciliation(refreshInventory: true)
        Task { @MainActor [weak self] in
            guard let self, self.generation == observerGeneration else { return }
            await self.state.refreshAccountStatus()
        }
    }

    /// Entwertet auch bereits in die MainActor-Queue übergebene Benachrichtigungen.
    func stop() {
        generation += 1
        observers.forEach(notifications.removeObserver)
        observers.removeAll()
        reconcileTask?.cancel()
        reconcileTask = nil
        needsReconciliation = false
        needsInventoryRefresh = false
        activeEvents.removeAll()
        state.setSynchronizing(false)
        container = nil
        storeURL = nil
        storeIdentifier = nil
    }

    func stopAndWait() async {
        let running = reconcileTask
        stop()
        // cancel allein beendet keine gerade arbeitenden SwiftData-Contexts.
        await running?.value
    }

    func scheduleReconciliation(refreshInventory: Bool = false) {
        guard container != nil else { return }
        needsReconciliation = true
        needsInventoryRefresh = needsInventoryRefresh || refreshInventory
        guard reconcileTask == nil else { return }
        let taskGeneration = generation
        reconcileTask = Task { @MainActor [weak self] in
            guard let self, self.generation == taskGeneration else { return }
            defer {
                if self.generation == taskGeneration { self.reconcileTask = nil }
            }
            while self.needsReconciliation, !Task.isCancelled, let container = self.container {
                // Foto-, Entwurfs- und Inventar-Commits einer Formularaktion bündeln.
                // Warten gibt den MainActor frei; Apples CloudKit-Planung bleibt automatisch.
                do { try await Task.sleep(for: self.reconciliationDelay) }
                catch { return }
                guard !Task.isCancelled, self.generation == taskGeneration else { return }
                self.needsReconciliation = false
                let refresh = self.needsInventoryRefresh
                self.needsInventoryRefresh = false
                do {
                    let mediaChanged = try await self.reconcileMedia(container)
                    guard !Task.isCancelled, self.generation == taskGeneration else { return }
                    self.state.clearMediaError()
                    if refresh || mediaChanged { self.publishChanges(refresh, mediaChanged) }
                } catch is CancellationError {
                    // Ablauf der Hintergrundzeit ist kein defektes Foto. Ein späterer
                    // Vordergrund-Abgleich übernimmt den unveröffentlichten Stand.
                    return
                } catch {
                    guard !Task.isCancelled, self.generation == taskGeneration else { return }
                    self.state.recordMediaError(error)
                    // Ein fehlendes/defektes Foto blockiert keine neuen Kisten oder Standorte.
                    if refresh { self.publishChanges(refresh, false) }
                }
            }
        }
    }

    func receiveRemoteChange(identifier: String?, url: URL?) {
        guard belongsToInventory(identifier: identifier, url: url) else { return }
        scheduleReconciliation(refreshInventory: true)
    }

    private func receive(_ event: NSPersistentCloudKitContainer.Event) {
        guard belongsToInventory(identifier: event.storeIdentifier, url: nil) else { return }
        let description: String
        switch event.type {
        case .setup: description = "iCloud wird vorbereitet"
        case .import: description = "Daten werden aus iCloud geladen"
        case .export: description = "Daten werden in iCloud gespeichert"
        @unknown default: description = "iCloud-Abgleich läuft"
        }
        if event.endDate == nil {
            activeEvents[event.identifier] = description
            state.setSynchronizing(true)
            state.recordSyncStatus(description)
            return
        }
        activeEvents.removeValue(forKey: event.identifier)
        state.setSynchronizing(!activeEvents.isEmpty)
        if let error = event.error {
            state.recordSyncError(error)
        } else if event.succeeded {
            if event.type == .import {
                state.markInitialImportCompleted()
                NotificationCenter.default.post(name: .inventoryCloudFormImportCompleted, object: nil)
            }
            if event.type != .setup, let date = event.endDate {
                state.markSuccessfulSync(at: date, uploadedLocalChanges: event.type == .export)
            }
            if let ongoing = activeEvents.values.sorted().first { state.recordSyncStatus(ongoing) }
            else {
                let date = DateFormatter.localizedString(from: event.endDate!, dateStyle: .short, timeStyle: .short)
                state.recordSyncStatus("Letzter Abgleich: \(date)")
            }
        }
        if event.type == .import { scheduleReconciliation(refreshInventory: true) }
    }

    private func refreshAfterForegroundOrAccountChange(generation requestedGeneration: Int) async {
        await state.refreshAccountStatus()
        guard generation == requestedGeneration else { return }
        scheduleReconciliation(refreshInventory: true)
    }

    private func refreshStoreIdentifier() {
        guard let storeURL else { return }
        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType, at: storeURL, options: nil)
            storeIdentifier = metadata[NSStoreUUIDKey] as? String
        } catch { state.recordSyncError(error) }
    }

    private func belongsToInventory(identifier: String?, url: URL?) -> Bool {
        guard container != nil else { return false }
        if storeIdentifier == nil { refreshStoreIdentifier() }
        if let identifier, let storeIdentifier { return identifier == storeIdentifier }
        if let url, let storeURL { return url.standardizedFileURL == storeURL }
        // Keine fremden Stores/CloudKit-Container der App als Inventaränderung behandeln.
        return false
    }
}

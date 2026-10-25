import Foundation
import SwiftData

/// Eigener serieller Context für das Lesen, Validieren und Hashen sämtlicher Fotos.
/// Sowohl Erzeugung als auch Aufruf bleiben im Detached Task: Ein anschließender
/// Aufruf des ModelActors vom UI-Task kann sonst wieder auf dem MainExecutor laufen.
@ModelActor
actor InventoryCloudMediaWorker {
    /// Die App installiert die lokale Sicherung; isolierte Medien-Tests brauchen
    /// weder den Inventar-Store noch Zugriff auf die echten UserDefaults.
    @MainActor static var backupDeletedPhotos: (([String: Data], [String: Date]) throws -> Void)?
    func prepare(documents: URL, receiptsURL: URL,
                 trace: (@Sendable (InventoryCloudMediaTiming) -> Void)? = nil) throws -> InventoryCloudMediaStore.Reconciliation? {
        // Den Context vor Freigabe der Assertion im selben synchronen Pool abbauen.
        try autoreleasepool {
            try Task.checkCancellation()
            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            return try InventoryCloudMediaStore.prepare(context: context, documents: documents, receiptsURL: receiptsURL, trace: trace)
        }
    }

    @MainActor
    static func reconcile(container: ModelContainer,
                          documents: URL = InventoryCloudMediaStore.documents,
                          receiptsURL: URL = InventoryCloudMediaStore.receiptsURL,
                          trace: (@Sendable (InventoryCloudMediaTiming) -> Void)? = nil) async throws -> Bool {
        try await InventoryStoreAccess.shared.perform {
            try await InventoryBackgroundExecution.shared.perform(name: "Inventory Cloud Photos") {
                try await reconcileProtected(container: container, documents: documents, receiptsURL: receiptsURL, trace: trace)
            }
        }
    }

    @MainActor
    private static func reconcileProtected(container: ModelContainer, documents: URL, receiptsURL: URL,
                                          trace: (@Sendable (InventoryCloudMediaTiming) -> Void)?) async throws -> Bool {
        try Task.checkCancellation()
        let preparation = Task.detached(priority: .utility) {
            let worker = Self.makeWorker(container: container, trace: trace)
            try Task.checkCancellation()
            let plan = try await worker.prepare(documents: documents, receiptsURL: receiptsURL, trace: trace)
            try Task.checkCancellation()
            return plan
        }
        let plan = try await withTaskCancellationHandler {
            try await preparation.value
        } onCancel: { preparation.cancel() }
        try Task.checkCancellation()
        guard let plan else { return false }
        if !plan.deletedPhotos.isEmpty { try backupDeletedPhotos?(plan.deletedPhotos, plan.photoDeletionDates) }
        _ = try await plan.applyInBackground(trace: trace)
        // Ein reiner Foto-Upload ändert keine lokalen DTOs oder Vorschaubilder.
        // Nur materialisierte/gelöschte lokale Dateien brauchen einen UI-Refresh.
        return plan.localFilesChanged
    }

    private nonisolated static func makeWorker(container: ModelContainer,
        trace: (@Sendable (InventoryCloudMediaTiming) -> Void)?) -> InventoryCloudMediaWorker {
        let started = ContinuousClock.now
        let worker = InventoryCloudMediaWorker(modelContainer: container)
        trace?(.init(phase: "worker-create", duration: ContinuousClock.now - started, isMainThread: Thread.isMainThread))
        return worker
    }
}

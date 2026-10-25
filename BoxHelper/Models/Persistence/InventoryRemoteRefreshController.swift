import Foundation
import SwiftData

/// Bündelt Hintergrund-Leseaufträge und veröffentlicht nur aktuelle Ergebnisse.
/// Während SQLite arbeitet, bleiben Formularaktionen und Navigation frei ausführbar.
@MainActor
final class InventoryRemoteRefreshController {
    private let storage: InventoryStorageState
    private let load: @Sendable (ModelContainer) async throws -> InventoryRemoteSnapshot
    private let repair: @MainActor (ModelContainer, InventoryIntegrityCandidates) throws -> InventoryCommit?
    private let publish: @MainActor (InventorySnapshot) -> Void
    private let reconciled: @MainActor () -> Void
    private let observe: @MainActor (InventoryRemoteSnapshot) throws -> Void
    private var task: Task<Void, Never>?
    private var container: ModelContainer?
    private var pending = false
    private var generation = 0
    private var isPaused = false

    init(storage: InventoryStorageState,
         load: @escaping @Sendable (ModelContainer) async throws -> InventoryRemoteSnapshot = {
             try await InventorySnapshotWorker.load(container: $0)
         },
         repair: @escaping @MainActor (ModelContainer, InventoryIntegrityCandidates) throws -> InventoryCommit? = { container, candidates in
             let store = try InventoryPersistence.prepare()
             // Ein inzwischen gewechselter Store darf keinen Plan seines Vorgängers
             // übernehmen. Der Controller beendet solche Aufträge ebenfalls per Generation.
             guard store.container === container else { return nil }
             return try store.repairIntegrity(candidates: candidates) ? store.latestCommit : nil
         },
         publish: @escaping @MainActor (InventorySnapshot) -> Void,
         observe: @escaping @MainActor (InventoryRemoteSnapshot) throws -> Void = { _ in },
         reconciled: @escaping @MainActor () -> Void = {}) {
        self.storage = storage
        self.load = load
        self.repair = repair
        self.publish = publish
        self.reconciled = reconciled
        self.observe = observe
    }

    func request(container: ModelContainer) {
        guard !isPaused else { return }
        if let current = self.container, current !== container { stop() }
        self.container = container
        pending = true
        guard task == nil else { return }
        let requestedGeneration = generation
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if self.generation == requestedGeneration { self.task = nil } }
            do {
                // Nicht nur der Fetch: Auch nachfolgende Integritäts-Commits gehören
                // zur selben Assertion und dürfen nicht zwischen zwei Tasks suspendieren.
                try await InventoryBackgroundExecution.shared.perform(name: "Inventory Refresh") {
                    await self.refresh(generation: requestedGeneration)
                }
            } catch is CancellationError {
                // Ein erneuter Vordergrundaufruf liest den Bestand frisch.
            } catch { self.storage.report(error) }
        }
    }

    private func refresh(generation requestedGeneration: Int) async {
        var needsPublication = false
        while self.pending, !Task.isCancelled, let container = self.container {
            self.pending = false
            let commitRevision = self.storage.localCommitRevision
            do {
                let result = try await self.load(container)
                guard !Task.isCancelled, self.generation == requestedGeneration else { return }
                // Ein Save während des Hintergrund-Fetches macht dessen Ergebnis alt.
                // Frisch lesen statt den gerade bestätigten Formularstand zurückzudrehen.
                guard self.storage.localCommitRevision == commitRevision else {
                    self.pending = true
                    continue
                }
                try self.observe(result)
                if !result.integrityCandidates.isEmpty {
                    self.storage.seedForIntegrityRepair(result)
                    let batches = await Task.detached(priority: .utility) {
                        result.integrityCandidates.batches()
                    }.value
                    var expectedRevision = commitRevision
                    for batch in batches {
                        guard !Task.isCancelled, self.generation == requestedGeneration else { return }
                        guard self.storage.localCommitRevision == expectedRevision else { break }
                        // Die FK-Prüfung erfolgt frisch direkt vor einem begrenzten
                        // Commit. Zwischen Schritten können Formulare weiterarbeiten.
                        if let commit = try autoreleasepool(invoking: { try self.repair(container, batch) }) {
                            self.storage.didCommit(commit)
                            expectedRevision = self.storage.localCommitRevision
                            needsPublication = true
                        }
                        await Task.yield()
                    }
                    // Erst den reparierten DB-Stand veröffentlichen. Ein während der
                    // Reparatur verschobenes Kind wird dabei mit seiner neuen FK gelesen.
                    self.pending = true
                    continue
                }
                let changed = self.storage.applyRemoteSnapshot(result)
                if changed || needsPublication { self.publish(result.inventory) }
                needsPublication = false
                self.reconciled()
            } catch is CancellationError {
                // Die nächste Vordergrundaktivierung liest den Bestand erneut.
                // Ein vom System beendeter Auftrag ist kein Datenbankfehler.
                return
            } catch {
                guard !Task.isCancelled, self.generation == requestedGeneration else { return }
                self.storage.report(error)
                if needsPublication {
                    self.publish(self.storage.readSnapshot())
                    needsPublication = false
                }
                self.reconciled()
            }
        }
    }

    func stop() {
        generation += 1
        task?.cancel()
        task = nil
        pending = false
        container = nil
    }

    func pauseAndWait() async {
        isPaused = true
        let running = task
        stop()
        await running?.value
    }

    func resume() { isPaused = false }
}

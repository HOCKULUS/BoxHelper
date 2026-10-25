import CloudKit
import Combine
import CryptoKit
import Foundation

/// Lokale DTOs bleiben die gemeinsame Schnittstelle für Formulare, Intents und Backups.
/// Eine Freigabe fügt lediglich einen zweiten, konfliktgeprüften Syncweg hinzu.
@MainActor
final class InventorySharingService: ObservableObject {
    static let shared = makeShared()

    private static func makeShared() -> InventorySharingService {
        InventorySharingService(
            backend: { try InventorySharingCloudBackend() },
            snapshot: { try InventoryPersistence.snapshot() },
            asyncSnapshot: { try await InventorySnapshotWorker.load(container: InventoryPersistence.prepare().container).inventory },
            scopedSnapshot: { names in
                func ids(_ prefix: String) -> [UUID] {
                    names.filter { $0.hasPrefix(prefix) }.compactMap { UUID(uuidString: String($0.dropFirst(prefix.count))) }
                }
                return try InventoryPersistence.prepare().selection(boxIDs: ids("box-"), itemIDs: ids("item-"), locationIDs: ids("location-"))
            },
            apply: { before, after in
                let store = try InventoryPersistence.prepare()
                if try store.applyInventoryChanges(from: before, to: after, trashSource: .cloud) {
                    InventoryPersistence.didReceiveSharedCommit(store)
                }
            }, protectedApply: { before, after, recordedAt in
                let store = try InventoryPersistence.prepare()
                if try store.applyInventoryChanges(from: before, to: after, preservingDeletionsAfter: recordedAt, trashSource: .cloud) {
                    InventoryPersistence.didReceiveSharedCommit(store)
                }
            }, revision: { InventoryStorageState.shared.revision }, mediaDidChange: {
                InventoryCloudSyncState.shared.markPendingChanges()
                InventoryCloudSyncCoordinator.shared.scheduleReconciliation(refreshInventory: true)
                InventoryPersistence.refreshAfterRemoteChange(refreshInventory: true, mediaChanged: true)
            }, backupDeletedPhoto: { url in
                if let bytes = try InventoryPhotoFileCoordinator.read(url).data {
                    let trash = try InventoryPersistence.prepare().trash
                    trash.commit(try trash.preparePhotos([url.lastPathComponent: bytes], source: .cloud))
                }
            }, documents: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
            cacheURL: nil, state: InventoryCloudSyncState.shared)
    }

    @Published private(set) var shares: [InventoryShareDescriptor] = []
    @Published private(set) var isSyncing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var notice: String?
    @Published private(set) var lastSync: Date?
    @Published private(set) var creationShareID: String?
    private struct Inbox: Codable, Sendable {
        var before: InventorySnapshot
        var after: InventorySnapshot
        var mediaChanged: Bool
        // Optionales Cache-Metadata erhält auch ältere Checkpoints. Spätere lokale
        // Löschungen dürfen bei einer wiederholten Teilübernahme nicht wiederauferstehen.
        var recordedAt: Date?
        var checkpointID: UUID?
        // Optional erhält die Kompatibilität mit älteren dauerhaften Sync-Checkpoints.
        // Dateilöschungen werden erst nach allen erfolgreichen DTO-Schritten ausgeführt.
        var photoDeletions: [InventorySharingPhotoCleanup.Candidate]?
    }
    private struct Group: Codable, Sendable {
        var descriptor: InventoryShareDescriptor
        var baseline: [String: InventorySharedRecord] = [:]
        var newIDs: Set<String> = []
        var available = true
        var published = true
        var inbox: Inbox?
    }
    private struct Cache: Codable, Sendable { var groups: [String: Group] = [:]; var creationShareID: String? }
    private let makeBackend: () throws -> any InventorySharingBackend
    private let snapshot: () throws -> InventorySnapshot
    private let asyncSnapshot: @MainActor () async throws -> InventorySnapshot
    private let scopedSnapshot: (Set<String>) throws -> InventorySnapshot
    private let apply: (InventorySnapshot, InventorySnapshot) throws -> Void
    private let protectedApply: (InventorySnapshot, InventorySnapshot, Date?) throws -> Void
    private let revision: () -> Int
    private let mediaDidChange: () -> Void
    private let backupDeletedPhoto: (URL) throws -> Void
    private let documents: URL
    private let providedCacheURL: URL?
    private let state: InventoryCloudSyncState
    private var backend: (any InventorySharingBackend)?
    private var cache = Cache()
    private var cacheURL: URL?
    private var pinnedAccount: String?
    private var task: Task<Void, Never>?
    private var pending = false
    private var started = false
    private var isPaused = false
    private var activeOperations = 0
    private var idleWaiters: [CheckedContinuation<Void, Never>] = []
    private var observedIDs: Set<String> = []
    private var retryAttempt = 0
    private var creatingShare = false
    private var subscribed = false
    private var initialCacheError: Error?
    private let cacheWorker: InventorySharingCacheWorker
    private var cachePersistenceRevision = 0

    init(backend: @escaping () throws -> any InventorySharingBackend,
         snapshot: @escaping () throws -> InventorySnapshot,
         asyncSnapshot: @escaping @MainActor @Sendable () async throws -> InventorySnapshot,
         scopedSnapshot: ((Set<String>) throws -> InventorySnapshot)? = nil,
         apply: @escaping (InventorySnapshot, InventorySnapshot) throws -> Void,
         protectedApply: ((InventorySnapshot, InventorySnapshot, Date?) throws -> Void)? = nil,
         revision: @escaping () -> Int,
         mediaDidChange: @escaping () -> Void = {},
         backupDeletedPhoto: @escaping (URL) throws -> Void = { _ in },
         documents: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
         cacheURL: URL? = nil, state: InventoryCloudSyncState = .shared,
         cacheWorker: InventorySharingCacheWorker? = nil) {
        makeBackend = backend; self.snapshot = snapshot; self.apply = apply
        self.protectedApply = protectedApply ?? { before, after, _ in try apply(before, after) }
        self.asyncSnapshot = asyncSnapshot
        self.cacheWorker = cacheWorker ?? InventorySharingCacheWorker()
        self.scopedSnapshot = scopedSnapshot ?? { try InventoryShareMerge.select(snapshot(), names: $0) }
        self.revision = revision; self.documents = documents; providedCacheURL = cacheURL; self.state = state
        self.mediaDidChange = mediaDidChange
        self.backupDeletedPhoto = backupDeletedPhoto
        // Shortcuts können schon vor der ersten Netzwerkantwort schreiben. Bekannte
        // Leserechte müssen deshalb synchron aus dem gerätelokalen Cache verfügbar sein.
        if cacheURL == nil, state.isActive,
           let hash = try? String(contentsOf: Self.sharingDirectory.appendingPathComponent("active-account.txt"), encoding: .utf8),
           hash.count == 64, hash.allSatisfy({ $0.isHexDigit }) {
            let url = Self.sharingDirectory.appendingPathComponent(hash + ".json")
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    cache = try JSONDecoder().decode(Cache.self, from: Data(contentsOf: url))
                    self.cacheURL = url; publish()
                } catch { initialCacheError = error; report(error) }
            }
        }
    }

    /// Isolierte Aufrufer dürfen den vorhandenen synchronen Snapshot-Spy behalten.
    /// Im produktiven Service ist der separate Hintergrundleser ausdrücklich injiziert.
    convenience init(backend: @escaping () throws -> any InventorySharingBackend,
                     snapshot: @escaping () throws -> InventorySnapshot,
                     scopedSnapshot: ((Set<String>) throws -> InventorySnapshot)? = nil,
                     apply: @escaping (InventorySnapshot, InventorySnapshot) throws -> Void,
                     protectedApply: ((InventorySnapshot, InventorySnapshot, Date?) throws -> Void)? = nil,
                     revision: @escaping () -> Int,
                     mediaDidChange: @escaping () -> Void = {},
                     documents: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
                     cacheURL: URL? = nil, state: InventoryCloudSyncState = .shared,
                     cacheWorker: InventorySharingCacheWorker? = nil) {
        self.init(backend: backend, snapshot: snapshot, asyncSnapshot: { try snapshot() },
                  scopedSnapshot: scopedSnapshot, apply: apply, protectedApply: protectedApply, revision: revision,
                  mediaDidChange: mediaDidChange, documents: documents, cacheURL: cacheURL, state: state,
                  cacheWorker: cacheWorker)
    }

    func start() {
        guard !started, !isPaused, state.isActive else { return }
        started = true
        observedIDs = (try? InventoryShareMerge.identifiers(in: snapshot())) ?? []
        requestSync()
    }

    func requestSync() {
        guard started, !isPaused, state.isActive else { return }
        pending = true
        guard task == nil, !creatingShare, !isSyncing else { return }
        task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard let self else { return }
            while self.pending, !Task.isCancelled, !self.creatingShare, !self.isSyncing {
                self.pending = false
                do { try await self.synchronize(); self.retryAttempt = 0 }
                catch is CancellationError {
                    // Nach Ablauf erst bei der nächsten Vordergrundaktivierung fortsetzen.
                    self.pending = true
                    break
                }
                catch {
                    self.report(error)
                    self.retryAttempt += 1
                    // Der Ausgangsstand bleibt auf Platte; Offline-Änderungen überleben Exit.
                    // Begrenzter Backoff vermeidet fortlaufende Konto-/Netzwerkabfragen.
                    if self.retryAttempt <= 3 {
                        let seconds = [5, 15, 60][self.retryAttempt - 1]
                        try? await Task.sleep(for: .seconds(seconds))
                        self.pending = true
                    }
                }
            }
            self.task = nil
        }
    }

    /// Private Fotos brauchen nur den SwiftData-Abgleich, keine Zonen-Discovery
    /// des getrennten Freigabesystems nach jedem einzelnen Dateischreibvorgang.
    func localMediaDidChange() {
        guard cache.groups.values.contains(where: { $0.available }) else { return }
        requestSync()
    }

    func selectCreationShare(_ id: String?) throws {
        if let id, let group = cache.groups[id], group.descriptor.scope.kind == .inventory,
           group.descriptor.canEdit, group.available { cache.creationShareID = id }
        else { cache.creationShareID = nil }
        try persist(); publish()
    }

    /// Nur ausdrücklich lokale Commits dürfen neue unabhängige Daten einer Freigabe
    /// zuordnen. Ein privater iCloud-Import wird über observeRemoteChange separat erfasst.
    func recordLocalCommit(inventory: InventorySnapshot? = nil) {
        guard state.isActive, cache.groups.values.contains(where: { $0.available }) else { return }
        do {
            let ids = InventoryShareMerge.identifiers(in: try inventory ?? snapshot())
            if let id = cache.creationShareID, var group = cache.groups[id], group.available, group.descriptor.canEdit {
                let previous = group.newIDs
                group.newIDs.formUnion(ids.subtracting(observedIDs))
                if group.newIDs != previous {
                    cache.groups[id] = group
                    try persist()
                }
            }
            observedIDs = ids
            if cache.groups.values.contains(where: { $0.available && $0.descriptor.canEdit }) {
                state.markPendingChanges(channel: "collaboration")
            }
            requestSync()
        } catch { report(error) }
    }

    func observeRemoteChange(inventory: InventorySnapshot? = nil) {
        guard state.isActive, cache.groups.values.contains(where: { $0.available }) else { return }
        observedIDs = (try? InventoryShareMerge.identifiers(in: inventory ?? snapshot())) ?? observedIDs
        if !isSyncing { requestSync() }
    }

    /// Leserechte werden an derselben Fassade geprüft, die auch Shortcuts verwenden.
    var requiresChangeValidation: Bool {
        state.isActive && (initialCacheError != nil || cache.groups.values.contains { $0.available && !$0.descriptor.canEdit })
    }

    func validateChanges(from before: InventorySnapshot, to after: InventorySnapshot) throws {
        guard requiresChangeValidation else { return }
        if let initialCacheError { throw initialCacheError }
        let old = try InventoryShareMerge.records(before); let new = try InventoryShareMerge.records(after)
        let changed = Set(old.keys).union(new.keys).filter { old[$0]?.body != new[$0]?.body }
        for group in cache.groups.values where group.available && !group.descriptor.canEdit {
            if changed.contains(where: { group.baseline[$0]?.isDeleted == false }) { throw InventorySharingError.readOnly }
        }
    }

    func create(title: String, scope: InventoryShareScope) async throws -> (InventoryShareDescriptor, CKShare) {
        try beginOperation()
        defer { endOperation() }
        let backend = try await readyBackend()
        guard !isSyncing, !creatingShare else { throw InventorySharingError.conflict }
        creatingShare = true
        state.setSynchronizing(true, channel: "collaboration")
        defer { creatingShare = false; state.setSynchronizing(false, channel: "collaboration"); requestSync() }
        // Prüft auch auf einem anderen Gerät angelegte Freigaben. Abgebrochene,
        // noch unveröffentlichte Erstübertragungen bleiben im Cache verwaltbar.
        applyDiscovery(try await backend.discover())
        try await persistInBackground(); publish()
        guard !cache.groups.values.contains(where: { $0.available && $0.descriptor.isOwner }) else {
            throw InventorySharingError.existingShare
        }
        let current = try await stableSnapshot()
        let selection = scope.select(from: current, isOwner: true)
        if scope.kind != .inventory && scope.roots.isEmpty { throw InventorySharingError.emptySelection }
        let names = InventoryShareMerge.identifiers(in: selection)
        for group in cache.groups.values where group.available {
            let alreadySelected = group.descriptor.scope.select(from: current, isOwner: group.descriptor.isOwner,
                                                                knownIDs: Set(group.baseline.keys), newIDs: group.newIDs)
            let existing = InventoryShareMerge.identifiers(in: alreadySelected)
                .union(group.baseline.filter { !$0.value.isDeleted }.keys)
            if (group.descriptor.isOwner && group.descriptor.scope.kind == .inventory)
                || scope.kind == .inventory || !names.isDisjoint(with: existing) { throw InventorySharingError.overlappingShare }
        }
        let descriptor = try await backend.create(title: title, scope: scope)
        cache.groups[descriptor.id] = Group(descriptor: descriptor, published: false)
        try await persistInBackground(); publish()
        do {
            try await synchronizeGroup(descriptor.id, backend: backend)
            let share = try await backend.publishShare(descriptor)
            cache.groups[descriptor.id]?.published = true
            try await persistInBackground(); publish()
            return (descriptor, share)
        } catch { report(error); throw error }
    }

    func shareForManagement(_ descriptor: InventoryShareDescriptor) async throws -> CKShare {
        try beginOperation()
        defer { endOperation() }
        let backend = try await readyBackend()
        // Eine zuvor abgebrochene Erstübertragung wird vor dem Öffnen der Einladung fertiggestellt.
        if cache.groups[descriptor.id]?.published == false {
            try await synchronizeGroup(descriptor.id, backend: backend)
        }
        let share = cache.groups[descriptor.id]?.published == false
            ? try await backend.publishShare(descriptor) : try await backend.share(descriptor)
        cache.groups[descriptor.id]?.published = true
        try await persistInBackground()
        return share
    }

    func end(_ descriptor: InventoryShareDescriptor) async throws {
        try beginOperation()
        defer { endOperation() }
        let backend = try await readyBackend()
        guard !isSyncing, !creatingShare else { throw InventorySharingError.conflict }
        // Sperrt Abgleich und Neuanlage während des serverseitigen Widerrufs.
        creatingShare = true
        defer { creatingShare = false; requestSync() }
        try await backend.end(descriptor)
        cache.groups[descriptor.id]?.available = false
        cache.groups[descriptor.id]?.descriptor.isAvailable = false
        cache.groups[descriptor.id]?.descriptor.canEdit = false
        cache.groups[descriptor.id]?.inbox = nil
        if cache.creationShareID == descriptor.id { cache.creationShareID = nil }
        try await persistInBackground()
        publish()
    }

    func accept(_ metadata: CKShare.Metadata) async {
        do {
            // Die Aktivierung findet vor dem Freigabeauftrag statt. Dadurch kann der
            // Storewechsel laufende Freigabeaufträge beenden, ohne auf sich selbst zu warten.
            guard CloudSyncPreferences.supportsCloudKit else { throw InventoryCloudSyncError.unsupportedBuild }
            if !state.isEnabled || !state.isActive { try await state.setEnabled(true) }
            try beginOperation()
            defer { endOperation() }
            let backend = try await readyBackend()
            try await backend.accept(metadata)
            start(); try await synchronize()
            notice = "Die gemeinsamen Daten wurden geladen."
            NotificationCenter.default.post(name: .inventoryShareAccepted, object: nil)
        } catch { report(error) }
    }

    func synchronize() async throws {
        try beginOperation()
        defer { endOperation() }
        // Ein Netzwerk-Wait darf nicht mit späteren SQLite-Commits in die
        // Suspension hineinlaufen. Der Checkpoint bleibt bei Abbruch erhalten.
        try await InventoryBackgroundExecution.shared.perform(name: "Inventory Sharing") {
            try await self.synchronizeProtected()
        }
    }

    private func synchronizeProtected() async throws {
        guard !isSyncing, !creatingShare else { pending = true; return }
        isSyncing = true; state.setSynchronizing(true, channel: "collaboration")
        defer {
            isSyncing = false; state.setSynchronizing(false, channel: "collaboration")
            if pending && task == nil { requestSync() }
        }
        try Task.checkCancellation()
        let backend = try await readyBackend()
        let discovered = try await backend.discover()
        try Task.checkCancellation()
        applyDiscovery(discovered)
        try await persistInBackground(); publish()
        var failure: Error?
        for id in cache.groups.keys.sorted() where cache.groups[id]?.available == true {
            try Task.checkCancellation()
            do { try await synchronizeGroup(id, backend: backend) }
            catch is CancellationError { throw CancellationError() }
            catch { failure = error }
        }
        if let failure { throw failure }
        lastSync = Date(); errorMessage = nil; state.clearCollaborationError()
        state.clearPendingChanges(channel: "collaboration")
        if !discovered.isEmpty { state.markSuccessfulSync(at: lastSync!, uploadedLocalChanges: false) }
    }

    /// Erstellen und Abgleichen verwenden dieselbe Sicht auf aktive und beendete Freigaben.
    private func applyDiscovery(_ discovered: [InventoryShareDescriptor]) {
        let discoveredIDs = Set(discovered.map(\.id))
        for id in cache.groups.keys where cache.groups[id]?.published == true && !discoveredIDs.contains(id) {
            cache.groups[id]?.available = false; cache.groups[id]?.descriptor.canEdit = false
            cache.groups[id]?.descriptor.isAvailable = false
            if cache.creationShareID == id { cache.creationShareID = nil }
        }
        for descriptor in discovered {
            if var group = cache.groups[descriptor.id] {
                group.descriptor = descriptor; group.available = true; cache.groups[descriptor.id] = group
            } else { cache.groups[descriptor.id] = Group(descriptor: descriptor) }
        }
    }

    private func synchronizeGroup(_ id: String, backend: any InventorySharingBackend) async throws {
        for attempt in 0..<4 {
            var materializedPhotos = false
            var mediaPublished = false
            do {
                guard var group = cache.groups[id], group.available else { return }
                if group.inbox != nil {
                    try await recoverInbox(id)
                    group = cache.groups[id]!
                }
                let fetched = try await backend.fetch(group.descriptor)
                // Neue Zuordnungen und Rechte aus lokalen Aktionen während des Netzwerkwaits
                // gehören zur aktuellen Gruppe, nicht zur Kopie vor dem Fetch.
                guard let refreshedGroup = cache.groups[id], refreshedGroup.available else { return }
                group = refreshedGroup
                let remote = Dictionary(uniqueKeysWithValues: fetched.map { ($0.name, $0) })
                let initialRevision = revision()
                let initialCacheRevision = cachePersistenceRevision
                let before = try await asyncSnapshot()
                try requireCurrent(local: initialRevision, cache: initialCacheRevision)
                let otherIDs = Set(cache.groups.values.filter { $0.descriptor.id != id && $0.available }
                    .flatMap { $0.baseline.filter { !$0.value.isDeleted }.keys })
                let documents = self.documents
                let inputGroup = group
                // Umfangreiche JSON-/Bildarbeit erhält nur Sendable-Wertkopien. Jeder
                // Actor-Wechsel wird vor dem Anwenden erneut auf lokale Änderungen geprüft.
                let prepared = try await Task.detached(priority: .utility) {
                    try InventorySharingPreparation.prepare(before: before, descriptor: inputGroup.descriptor,
                        baseline: inputGroup.baseline, newIDs: inputGroup.newIDs, otherIDs: otherIDs,
                        remote: remote, documents: documents)
                }.value
                try requireCurrent(local: initialRevision, cache: initialCacheRevision)
                var merged = prepared.records
                for key in prepared.downloads {
                    guard let expected = merged[key] else { throw InventorySharingError.invalidData }
                    let asset = try await backend.photo(named: key, in: group.descriptor)
                    try requireCurrent(local: initialRevision, cache: initialCacheRevision)
                    guard asset.body == expected.body, asset.filename == expected.filename,
                          asset.kind == "photo", !asset.isDeleted else { throw InventorySharingError.conflict }
                    merged[key] = asset
                }
                let writes = merged.values.filter { value in
                    guard let old = remote[value.name] else { return true }
                    return old.body != value.body || old.isDeleted != value.isDeleted || old.filename != value.filename
                }.sorted { $0.name < $1.name }
                if !writes.isEmpty && group.descriptor.canEdit {
                    for saved in try await backend.save(writes, in: group.descriptor) { merged[saved.name] = saved }
                }
                try requireCurrent(local: initialRevision, cache: initialCacheRevision)
                // Fotos vor dem lokalen DTO-Commit materialisieren. Fehlende Assets lassen
                // die bisherigen Datensätze unberührt und werden beim nächsten Abgleich erneut geladen.
                let photoRecords = Array(merged.values)
                let photos = try await Task.detached(priority: .utility) {
                    try InventorySharingPreparation.preparePhotos(photoRecords, documents: documents,
                        expected: prepared.photoVersions)
                }.value
                try requireCurrent(local: initialRevision, cache: initialCacheRevision)
                materializedPhotos = try await photos.applyInBackground()
                try requireCurrent(local: initialRevision, cache: initialCacheRevision)
                if materializedPhotos {
                    // Fotos sind bereits bestätigt, auch wenn ein späterer Metadaten-
                    // Checkpoint scheitert. Ein Retry erkennt passende Bytes sonst als
                    // unverändert und könnte die UI dauerhaft ohne Medienrevision lassen.
                    mediaDidChange()
                    mediaPublished = true
                }
                for (name, var record) in merged {
                    record.photo = nil // Bildbytes gehören nur in Documents/CKAsset, nicht doppelt in den Sync-Cache.
                    group.baseline[name] = record
                }
                group.newIDs.subtract(merged.keys)
                let affected = prepared.affected
                group.inbox = Inbox(before: InventoryShareMerge.select(before, names: affected),
                                    after: InventoryShareMerge.select(prepared.after, names: affected), mediaChanged: false,
                                    recordedAt: Date(), checkpointID: UUID(), photoDeletions: prepared.photoDeletions)
                let previousGroup = cache.groups[id]
                cache.groups[id] = group
                let checkpointRevision = cachePersistenceRevision + 1
                do { try await persistInBackground() }
                catch {
                    // Eine neuere lokale Cache-Schreibung darf nicht durch die ältere
                    // Gruppenkopie zurückgesetzt werden. Dann mit aktuellem Zustand erneut versuchen.
                    if cachePersistenceRevision == checkpointRevision { cache.groups[id] = previousGroup }
                    throw error
                }
                // Der bestätigte Serverstand und die noch anzuwendende Änderung sind vor
                // dem SQLite-Commit dauerhaft gesichert. Ein Savefehler/Exit verliert nichts.
                try await recoverInbox(id)
                publish()
                observedIDs = InventoryShareMerge.identifiers(in: try await stableSnapshot())
                return
            } catch {
                if materializedPhotos && !mediaPublished { mediaDidChange() }
                if attempt < 3 && Self.isConflict(error) { continue }
                throw error
            }
        }
    }

    private func recoverInbox(_ id: String) async throws {
        guard let inbox = cache.groups[id]?.inbox else { return }
        let batches = await Task.detached(priority: .utility) {
            InventorySharingInboxBatches.plan(before: inbox.before, after: inbox.after)
        }.value
        for batch in batches {
            try Task.checkCancellation()
            try requireInbox(inbox, id: id)
            // Frisch lesen, lokale Feldänderungen patchen und speichern bleiben in
            // EINEM MainActor-Durchlauf. Eingaben während früherer Yields haben Vorrang.
            let current = try scopedSnapshot(batch.names)
            let desired = InventorySnapshot(
                boxes: InventoryFieldChanges.boxes(from: batch.before.boxes, to: current.boxes, in: batch.after.boxes),
                items: InventoryFieldChanges.items(from: batch.before.items, to: current.items, in: batch.after.items),
                locations: InventoryFieldChanges.locations(from: batch.before.locations, to: current.locations, in: batch.after.locations))
            try protectedApply(current, desired, inbox.recordedAt)
            // Der vollständige dauerhafte Checkpoint bleibt bis zum letzten Schritt
            // bestehen. Ein Fehler/Exit darf jederzeit dieselben Schritte wiederholen.
            await Task.yield()
        }
        try Task.checkCancellation()
        try requireInbox(inbox, id: id)
        try await removeDeletedPhotos(inbox, id: id)
        try requireInbox(inbox, id: id)
        if inbox.mediaChanged { mediaDidChange() }
        cache.groups[id]?.inbox = nil
        try await persistInBackground()
    }

    private func removeDeletedPhotos(_ inbox: Inbox, id: String) async throws {
        guard let candidates = inbox.photoDeletions, !candidates.isEmpty else { return }
        let localRevision = revision()
        let cacheRevision = cachePersistenceRevision
        // Alle privaten und geteilten Referenzen prüfen, nicht nur die aktuelle Gruppe.
        // Der vollständige Datenbank-Leser und das Foto-Staging bleiben im Hintergrund.
        let current = try await asyncSnapshot()
        try requireCurrent(local: localRevision, cache: cacheRevision)
        try requireInbox(inbox, id: id)
        let documents = self.documents
        var removedPhotos = false
        // Bereits bestätigte Löschungen auch bei einem späteren Fehler veröffentlichen.
        // Der dauerhafte Checkpoint darf beim Retry fehlende Dateien einfach überspringen.
        defer { if removedPhotos { mediaDidChange() } }
        for offset in stride(from: 0, to: candidates.count, by: 8) {
            // Rollback-Bytes großer Fotos nur für einen kleinen Abschnitt halten.
            let batch = Array(candidates[offset..<min(candidates.count, offset + 8)])
            let worker = Task.detached(priority: .utility) {
                try InventorySharingPhotoCleanup.prepare(batch, retaining: InventoryShareMerge.photos(in: current), documents: documents)
            }
            let transaction = try await withTaskCancellationHandler(operation: { try await worker.value },
                                                                   onCancel: { worker.cancel() })
            try requireCurrent(local: localRevision, cache: cacheRevision)
            try requireInbox(inbox, id: id)
            guard let transaction else { continue }
            try await transaction.apply(beforeCommit: { url in
                // Lokale Metadatenänderungen zwischen zwei Dateien verwerfen die alte
                // Referenzprüfung. Bereits entfernte Dateien werden dann zurückgerollt.
                try self.requireCurrent(local: localRevision, cache: cacheRevision)
                try self.requireInbox(inbox, id: id)
                try self.backupDeletedPhoto(url)
            })
            removedPhotos = true
        }
    }

    private func requireInbox(_ expected: Inbox, id: String) throws {
        guard let group = cache.groups[id], group.available, let current = group.inbox else {
            throw InventorySharingError.conflict
        }
        if let checkpointID = expected.checkpointID {
            guard current.checkpointID == checkpointID else { throw InventorySharingError.conflict }
        } else {
            // Frühere Cache-Dateien hatten noch keine Checkpoint-ID.
            guard current.before == expected.before, current.after == expected.after,
                  current.mediaChanged == expected.mediaChanged, current.recordedAt == expected.recordedAt else {
                throw InventorySharingError.conflict
            }
        }
    }

    private func readyBackend() async throws -> any InventorySharingBackend {
        let value = try backend ?? makeBackend()
        let account = try await value.accountID()
        if let pinnedAccount, pinnedAccount != account { throw InventorySharingError.accountChanged }
        if pinnedAccount == nil {
            let hash = Self.digest(Data(account.utf8))
            let url = providedCacheURL ?? Self.sharingDirectory.appendingPathComponent(hash + ".json")
            let beforeLoad = cachePersistenceRevision
            let loaded = try await cacheWorker.read(Cache.self, at: url) ?? Cache()
            guard cachePersistenceRevision == beforeLoad else { throw InventorySharingError.conflict }
            if providedCacheURL == nil {
                let stage = try await cacheWorker.stageData(Data(hash.utf8), at: Self.sharingDirectory.appendingPathComponent("active-account.txt"))
                defer { stage.discard() }
                guard cachePersistenceRevision == beforeLoad else { throw InventorySharingError.conflict }
                try stage.publish()
            }
            // Bei einem defekten/veralteten Cache niemals ohne Ausgangsstand weiterarbeiten.
            // Erst nach allen Waits übernehmen; lokale Eingaben behalten so Vorrang.
            pinnedAccount = account; backend = value; cacheURL = url; cache = loaded
            initialCacheError = nil
            publish()
        }
        if !subscribed {
            try await value.subscribe()
            subscribed = true
        }
        return value
    }

    /// Explizite lokale Änderungen bestätigen ihre Dauerhaftigkeit weiterhin synchron.
    /// Die Revision entwertet bereits gestartete ältere Netzwerk-Cache-Stages.
    private func persist() throws {
        cachePersistenceRevision += 1
        guard let cacheURL else { return }
        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try InventoryShareMerge.encode(cache).write(to: cacheURL, options: .atomic)
    }

    private func persistInBackground() async throws {
        cachePersistenceRevision += 1
        let requestedRevision = cachePersistenceRevision
        guard let cacheURL else { return }
        let value = cache
        let stage = try await cacheWorker.stage(value, at: cacheURL)
        defer { stage.discard() }
        try Task.checkCancellation()
        guard requestedRevision == cachePersistenceRevision, self.cacheURL == cacheURL else {
            throw InventorySharingError.conflict
        }
        // Keine Actor-Unterbrechung zwischen Revisionsprüfung und atomarem Checkpoint.
        try stage.publish()
    }

    private func requireCurrent(local: Int, cache: Int) throws {
        try Task.checkCancellation()
        guard !isPaused else { throw CancellationError() }
        guard revision() == local, cachePersistenceRevision == cache else { throw InventorySharingError.conflict }
    }

    /// Hintergrundlesungen dürfen währenddessen bestätigte lokale Eingaben nicht ersetzen.
    private func stableSnapshot() async throws -> InventorySnapshot {
        for _ in 0..<4 {
            let local = revision(), cache = cachePersistenceRevision
            let value = try await asyncSnapshot()
            if revision() == local, cachePersistenceRevision == cache { return value }
        }
        throw InventorySharingError.conflict
    }

    /// Wartet zusätzlich auf ausdrücklich gestartete Freigabeaktionen. Deren
    /// bestätigte Checkpoints bleiben erhalten und werden beim Einschalten fortgesetzt.
    func pauseAndWait() async {
        isPaused = true
        started = false
        pending = false
        let running = task
        running?.cancel()
        await running?.value
        if activeOperations > 0 {
            await withCheckedContinuation { idleWaiters.append($0) }
        }
        task = nil
        pending = false
        retryAttempt = 0
    }

    func resume() { isPaused = false }

    private func beginOperation() throws {
        guard !isPaused else { throw CancellationError() }
        guard state.isActive else { throw InventorySharingError.disabled }
        activeOperations += 1
    }

    private func endOperation() {
        activeOperations -= 1
        if activeOperations == 0 {
            let pending = idleWaiters
            idleWaiters.removeAll()
            pending.forEach { $0.resume() }
        }
    }
    private func publish() {
        let availableShares = cache.groups.values.map(\.descriptor).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        if shares != availableShares { shares = availableShares }
        if creationShareID != cache.creationShareID { creationShareID = cache.creationShareID }
    }
    private func report(_ error: Error) { errorMessage = error.localizedDescription; state.recordCollaborationError(error) }
    private static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private static var sharingDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BoxHelper/Sharing", isDirectory: true)
    }
    private static func isConflict(_ error: Error) -> Bool {
        if case InventorySharingError.conflict = error { return true }
        guard let error = error as? CKError else { return false }
        if error.code == .serverRecordChanged || error.code == .batchRequestFailed { return true }
        if error.code == .partialFailure, let failures = error.partialErrorsByItemID {
            return failures.values.contains { isConflict($0) }
        }
        return false
    }
}

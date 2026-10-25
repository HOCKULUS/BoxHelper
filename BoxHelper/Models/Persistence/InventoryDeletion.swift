import Foundation

/// Gemeinsamer Ablauf für Listen und Shortcuts: Metadaten zuerst atomar speichern,
/// danach nur unveränderte Fotos ohne private oder geteilte Referenzen entfernen.
@MainActor
final class InventoryDeletion {
    static let shared = makeShared()

    private static func makeShared() -> InventoryDeletion {
        InventoryDeletion(selection: { request in
            let store = try InventoryPersistence.prepare()
            switch request {
            case .boxes(let ids, _, _):
                var selected = try store.selection(boxIDs: Array(ids))
                selected.items = try store.children(in: ids)
                return selected
            case .items(let ids): return try store.selection(itemIDs: Array(ids))
            case .locations(let ids):
                var selected = try store.selection(locationIDs: Array(ids))
                selected.boxes = try store.boxes(at: ids)
                return selected
            case .photo(let owner, _, _):
                switch owner {
                case .box(let id): return try store.selection(boxIDs: [id])
                case .item(let id): return try store.selection(itemIDs: [id])
                case .location(let id): return try store.selection(locationIDs: [id])
                }
            }
        }, snapshot: {
            try await InventorySnapshotWorker.load(container: InventoryPersistence.prepare().container).inventory
        }, apply: { try InventoryPersistence.applyInventoryChanges(from: $0, to: $1) },
        revision: { InventoryStorageState.shared.revision }, deleteCloudPhotos: { try InventoryPersistence.deleteCloudPhotos($0) }, mediaDidChange: { InventoryPersistence.mediaDidChange() },
        report: { InventoryStorageState.shared.report($0) },
        documents: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])
    }

    private let selection: (InventoryDeletionPlan.Request) throws -> InventorySnapshot
    private let snapshot: @MainActor () async throws -> InventorySnapshot
    private let apply: (InventorySnapshot, InventorySnapshot) throws -> Void
    private let revision: () -> Int
    private let deleteCloudPhotos: (Set<String>) throws -> Void
    private let mediaDidChange: () -> Void
    private let report: (Error) -> Void
    private let documents: URL

    init(selection: @escaping (InventoryDeletionPlan.Request) throws -> InventorySnapshot,
         snapshot: @escaping @MainActor () async throws -> InventorySnapshot,
         apply: @escaping (InventorySnapshot, InventorySnapshot) throws -> Void,
         revision: @escaping () -> Int, deleteCloudPhotos: @escaping (Set<String>) throws -> Void = { _ in }, mediaDidChange: @escaping () -> Void,
         report: @escaping (Error) -> Void, documents: URL) {
        self.selection = selection; self.snapshot = snapshot; self.apply = apply
        self.revision = revision; self.deleteCloudPhotos = deleteCloudPhotos; self.mediaDidChange = mediaDidChange
        self.report = report; self.documents = documents
    }

    func boxes(_ ids: Set<UUID>, onlyIfEmpty: Bool = false, deletePhotos: Bool = true) async throws -> Bool {
        try await delete(.boxes(ids, onlyIfEmpty: onlyIfEmpty, deletePhotos: deletePhotos))
    }

    func items(_ ids: Set<UUID>) async throws -> Bool { try await delete(.items(ids)) }
    func locations(_ ids: Set<UUID>) async throws -> Bool { try await delete(.locations(ids)) }
    func inventory() async throws -> InventorySnapshot { try await snapshot() }

    func imageReference(_ name: String, owner: InventoryDeletionPlan.PhotoOwner, index: Int? = nil) async throws -> Bool {
        try await delete(.photo(owner, filename: name, index: index))
    }

    /// Konkrete Altdateien nach einem bestätigten Bildwechsel bereinigen. Referenzen
    /// anderer Besitzer und veränderte Dateiversionen werden genauso geschützt.
    func cleanUnusedPhotos(_ names: Set<String>) async throws {
        let identities = try await photoIdentities(names)
        _ = try await removeUnreferencedPhotos(identities)
    }

    private func delete(_ request: InventoryDeletionPlan.Request) async throws -> Bool {
        for _ in 0..<4 {
            let version = revision()
            guard let plan = try InventoryDeletionPlan.make(request, from: selection(request)) else { return false }
            let identities = try await photoIdentities(plan.photos)
            // Während der Dateiprüfung kann auch ohne bereits veröffentlichte UI-Revision
            // ein Cloud-Import eingetroffen sein. Die Auswahl deshalb erneut frisch lesen.
            guard revision() == version, try selection(request) == plan.before else { continue }
            if plan.before != plan.after { try apply(plan.before, plan.after) }
            // Metadaten sind jetzt bestätigt. Ein Dateifehler macht die erfolgreiche
            // Objektlöschung nicht rückgängig und wird separat sichtbar gemeldet.
            do { _ = try await removeUnreferencedPhotos(identities) } catch { report(error) }
            return true
        }
        throw InventoryPhotoFileCoordinator.Failure.changed("Inventar")
    }

    /// Ein ausdrücklich gelöschtes Foto wird aus sämtlichen Referenzen entfernt.
    /// Die Referenzänderung scheitert bei Leserechten vor jeder Dateilöschung.
    func image(_ filename: String) async throws -> Bool {
        _ = try InventoryDeletionPlan.photoURL(filename, documents: documents)
        let identities = try await photoIdentities([filename])
        for _ in 0..<4 {
            let version = revision()
            let current = try await snapshot()
            guard revision() == version else { continue }
            let plan = InventoryDeletionPlan.removingPhoto(filename, from: current)
            if plan.before != plan.after { try apply(plan.before, plan.after) }
            let removed = try await removeUnreferencedPhotos(identities)
            return removed > 0 || plan.before != plan.after
        }
        throw InventoryPhotoFileCoordinator.Failure.changed(filename)
    }

    private struct Photo: Sendable {
        let url: URL
        let identity: InventoryPhotoFileCoordinator.Identity?
    }

    private func photoIdentities(_ names: Set<String>) async throws -> [Photo] {
        guard !names.isEmpty else { return [] }
        let documents = self.documents
        return try await Task.detached(priority: .utility) {
            try names.sorted().map { name in
                let url = try InventoryDeletionPlan.photoURL(name, documents: documents)
                // Ausstehende Cloud-Fotos besitzen noch keine lokale Datei. Ihr
                // expliziter Löschauftrag muss trotzdem den Cloud-Datensatz erreichen.
                return Photo(url: url, identity: try InventoryPhotoFileCoordinator.Identity.read(url))
            }
        }.value
    }

    private func removeUnreferencedPhotos(_ photos: [Photo]) async throws -> Int {
        guard !photos.isEmpty else { return 0 }
        var remaining = photos
        var confirmedDeletions = 0
        defer { if confirmedDeletions > 0 { mediaDidChange() } }
        for _ in 0..<4 {
            let version = revision()
            let current = try await snapshot()
            guard revision() == version else { continue }
            let references = InventoryDeletionPlan.photoReferences(in: current)
            remaining.removeAll { references.contains($0.url.lastPathComponent.lowercased()) }
            while !remaining.isEmpty, revision() == version {
                let batch = Array(remaining.prefix(25))
                remaining.removeFirst(batch.count)
                for photo in batch {
                    // Geänderte Dateien und inzwischen entstandene neue Referenzen
                    // gehören nicht mehr zum ursprünglichen Löschauftrag.
                    guard try InventoryPhotoFileCoordinator.Identity.read(photo.url) == photo.identity else { continue }
                    // Zuerst den Cloud-Datensatz samt Löschauftrag bestätigen. Ein
                    // fehlgeschlagener Datenbank-Commit lässt die Originaldatei erhalten.
                    try deleteCloudPhotos([photo.url.lastPathComponent])
                    // Schon der bestätigte Auftrag braucht einen Medienabgleich,
                    // selbst wenn die Datei fehlt oder ihr Entfernen später scheitert.
                    confirmedDeletions += 1
                    if photo.identity != nil { try InventoryPhotoFileCoordinator.remove(photo.url) }
                }
                await Task.yield()
            }
            if remaining.isEmpty { return confirmedDeletions }
        }
        throw InventoryPhotoFileCoordinator.Failure.changed("Fotos")
    }
}

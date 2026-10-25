import Foundation

/// Gerätelokaler Schutz gegen echte DB-Löschungen, auch zwischen zwei Appstarts.
/// Der Schattenbestand speichert die zuletzt bestätigten DTOs vor einem Cloud-Delete.
/// Er ist kein weiterer synchronisierter Datenbestand und stellt nichts automatisch her.
@MainActor
final class InventoryTrashStore {
    static let archiveKey = "inventoryTrashArchiveV1"
    static let retentionKey = "inventoryTrashRetentionDays"
    static let retentionOptions = [30, 14, 7, 2, 0]

    struct Archive: Codable, Equatable, Sendable {
        var inventory = InventorySnapshot.empty
        var entries: [InventoryTrashEntry] = []
        var photos: [String: Data] = [:]
    }

    struct PreparedChange {
        let data: Data
        let hasLocalDeletion: Bool
        var archive: Archive? = nil
    }

    private let defaults: UserDefaults
    private var cachedData: Data?
    private var cachedArchive: Archive?
    let documents: URL

    init(defaults: UserDefaults = .standard, documents: URL? = nil) {
        self.defaults = defaults
        self.documents = documents ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var retentionDays: Int {
        guard defaults.object(forKey: Self.retentionKey) != nil else { return 30 }
        let days = min(30, max(0, defaults.integer(forKey: Self.retentionKey)))
        // Die frühere Ein-Tages-Auswahl bleibt auch nach Entfernen ihres Picker-Tags gültig.
        return days == 1 ? 2 : days
    }

    func read() throws -> Archive {
        guard let data = defaults.data(forKey: Self.archiveKey) else { return Archive() }
        // Viele kleine iCloud-Batches ändern denselben Schattenbestand. Bereits
        // dekodierte DTOs wiederverwenden, solange auch die persistierten Bytes gleich
        // sind; fremde Instanzen und Hintergrundbereinigungen bleiben damit sichtbar.
        if data == cachedData, let cachedArchive { return cachedArchive }
        // Ein beschädigtes Archiv darf durch einen nächsten Delete nicht überschrieben werden.
        let archive = try PropertyListDecoder().decode(Archive.self, from: data)
        cachedData = data
        cachedArchive = archive
        return archive
    }

    func setRetentionDays(_ days: Int, now: Date = Date()) throws {
        let previous = defaults.object(forKey: Self.retentionKey)
        defaults.set(min(30, max(0, days)), forKey: Self.retentionKey)
        do { try cleanup(now: now) }
        catch { defaults.set(previous, forKey: Self.retentionKey); throw error }
    }

    /// Vor dem SQLite-Save kodieren, danach veröffentlichen. Ein fehlgeschlagener
    /// Commit erzeugt dadurch keine falschen Papierkorbeinträge.
    func prepareChange(before: InventorySnapshot, after: InventorySnapshot,
                       deleting: InventoryObjectIDs, source: InventoryTrashEntry.Source = .local,
                       deletionDates: [String: Date] = [:], now: Date = Date()) throws -> PreparedChange {
        var archive = try read()
        var localDeletion = deleting.count > 0
        if retentionDays > 0 {
            for value in before.boxes where deleting.boxes.contains(value.id) {
                try append(.box(value), to: &archive, source: source, now: min(now, deletionDates["box:\(value.id)"] ?? now))
            }
            for value in before.items where deleting.items.contains(value.id) {
                try append(.item(value), to: &archive, source: source, now: min(now, deletionDates["item:\(value.id)"] ?? now))
            }
            for value in before.locations where deleting.locations.contains(value.id) {
                try append(.location(value), to: &archive, source: source, now: min(now, deletionDates["location:\(value.id)"] ?? now))
            }
            // Eine Referenzlöschung in einer Detailansicht sichert das Foto und
            // seine ursprüngliche Zuordnung, ohne den Besitzer zurückzusetzen.
            let changedIDs = InventoryObjectIDs(boxes: Set(after.boxes.map(\.id)),
                items: Set(after.items.map(\.id)), locations: Set(after.locations.map(\.id)))
            let changedBefore = InventorySnapshot(boxes: before.boxes.filter { changedIDs.boxes.contains($0.id) },
                items: before.items.filter { changedIDs.items.contains($0.id) },
                locations: before.locations.filter { changedIDs.locations.contains($0.id) })
            let removedPhotoKeys = InventoryDeletionPlan.photoReferences(in: changedBefore)
                .subtracting(InventoryDeletionPlan.photoReferences(in: after))
            localDeletion = localDeletion || !removedPhotoKeys.isEmpty
            let originalNames = changedBefore.boxes.flatMap(\.images) + changedBefore.items.flatMap(\.images)
                + changedBefore.locations.map(\.image)
            for name in Set(originalNames) where removedPhotoKeys.contains(name.lowercased()) {
                try append(.image(name, Self.links(for: name, in: changedBefore)), to: &archive, source: source, now: now)
            }
        }
        archive.inventory = retentionDays > 0
            ? InventoryCommit.patch(after, deleting: deleting).applying(to: archive.inventory)! : .empty
        // Sicherungen erst ausdrücklich entfernen. Ein Restore kann nach dem
        // Inventar-Commit noch an der separaten Fototransaktion scheitern.
        prune(&archive, now: now)
        return try prepared(archive, localDeletion: source == .local && localDeletion)
    }

    func commit(_ change: PreparedChange) {
        defaults.set(change.data, forKey: Self.archiveKey)
        cachedData = change.data
        cachedArchive = change.archive
        NotificationCenter.default.post(name: .inventoryTrashDidChange, object: nil)
        if change.hasLocalDeletion {
            NotificationCenter.default.post(name: .inventoryTrashLocalDeletion, object: nil)
        }
    }

    /// Ein vollständiger, aktueller Snapshot erkennt auch native CloudKit-Deletes
    /// ohne verbliebene Nutzdatenzeile. Der alte Schattenbestand überlebt Appstarts.
    func reconcile(_ current: InventorySnapshot, deletionDates: [String: Date] = [:], now: Date = Date()) throws {
        guard retentionDays > 0 else { return }
        let previous = try read().inventory
        let deleting = InventoryObjectIDs(
            boxes: Set(previous.boxes.map(\.id)).subtracting(current.boxes.map(\.id)),
            items: Set(previous.items.map(\.id)).subtracting(current.items.map(\.id)),
            locations: Set(previous.locations.map(\.id)).subtracting(current.locations.map(\.id)))
        guard previous != current else { return }
        commit(try prepareChange(before: previous, after: current, deleting: deleting, source: .cloud,
            deletionDates: deletionDates, now: now))
    }

    /// Cloud-Medienabgleiche liefern die Originalbytes vor dem Entfernen einer Datei.
    /// Lokale Dateilöschungen verwenden denselben Weg vor ihrem Datenbank-Commit.
    func preparePhotos(_ photos: [String: Data], source: InventoryTrashEntry.Source = .local,
                       deletionDates: [String: Date] = [:], now: Date = Date()) throws -> PreparedChange {
        var archive = try read()
        if retentionDays > 0 {
            for (name, data) in photos {
                try append(.image(name, Self.links(for: name, in: archive.inventory)), to: &archive, source: source,
                    now: min(now, deletionDates[name] ?? now))
                archive.photos[name] = data
            }
        }
        prune(&archive, now: now)
        return try prepared(archive, localDeletion: source == .local && !photos.isEmpty)
    }

    func remove(_ ids: Set<UUID>) throws {
        var archive = try read()
        archive.entries.removeAll { ids.contains($0.id) }
        prune(&archive, now: Date())
        commit(try prepared(archive))
    }

    func cleanup(now: Date = Date()) throws {
        let previous = try read()
        var archive = previous
        prune(&archive, now: now)
        guard archive != previous else { return }
        commit(try prepared(archive))
    }

    func cleanupInBackground(now: Date = Date()) async throws {
        guard let original = defaults.data(forKey: Self.archiveKey) else { return }
        let days = retentionDays
        let changed = try await Task.detached(priority: .utility) {
            let previous = try PropertyListDecoder().decode(Archive.self, from: original)
            var archive = previous
            Self.prune(&archive, now: now, days: days)
            guard archive != previous else { return Optional<Data>.none }
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            return try encoder.encode(archive)
        }.value
        // Während des Wartungslaufs kann der Nutzer löschen oder wiederherstellen.
        // Nur den unveränderten Archivstand ersetzen; der nächste Start räumt erneut auf.
        guard let changed, defaults.data(forKey: Self.archiveKey) == original else { return }
        commit(PreparedChange(data: changed, hasLocalDeletion: false))
    }

    private func append(_ payload: InventoryTrashEntry.Payload, to archive: inout Archive,
                        source: InventoryTrashEntry.Source, now: Date) throws {
        let entry = InventoryTrashEntry(payload: payload, source: source, deletedAt: now)
        if let index = archive.entries.firstIndex(where: { $0.key == entry.key }) {
            // Wiederholte Syncs verlängern die Frist nicht; fehlende Fotozuordnungen
            // können aber noch vor dem tatsächlichen Entfernen der Datei eintreffen.
            if case .image(let name, let links) = payload,
               case .image(_, let existing) = archive.entries[index].payload, existing.isEmpty, !links.isEmpty {
                let old = archive.entries[index]
                archive.entries[index] = InventoryTrashEntry(id: old.id, deletedAt: old.deletedAt,
                    source: old.source, payload: .image(name, links))
            }
        } else { archive.entries.append(entry) }
        for name in entry.images where archive.photos[name] == nil {
            let url = try InventoryDeletionPlan.photoURL(name, documents: documents)
            archive.photos[name] = try InventoryPhotoFileCoordinator.read(url).data
        }
    }

    private func prune(_ archive: inout Archive, now: Date) {
        Self.prune(&archive, now: now, days: retentionDays)
    }

    private nonisolated static func prune(_ archive: inout Archive, now: Date, days: Int) {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        archive.entries.removeAll { days == 0 || $0.deletedAt <= cutoff }
        if days == 0 { archive.inventory = .empty }
        let retainedNames = Set(archive.entries.flatMap(\.images))
        archive.photos = archive.photos.filter { retainedNames.contains($0.key) }
    }

    private func prepared(_ archive: Archive, localDeletion: Bool = false) throws -> PreparedChange {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return PreparedChange(data: try encoder.encode(archive), hasLocalDeletion: localDeletion, archive: archive)
    }

    static func links(for name: String, in inventory: InventorySnapshot) -> [InventoryTrashEntry.PhotoLink] {
        var links: [InventoryTrashEntry.PhotoLink] = []
        for box in inventory.boxes {
            for (index, image) in box.images.enumerated() where image.lowercased() == name.lowercased() {
                links.append(.init(owner: .box(box.id), index: index))
            }
        }
        for item in inventory.items {
            for (index, image) in item.images.enumerated() where image.lowercased() == name.lowercased() {
                links.append(.init(owner: .item(item.id), index: index))
            }
        }
        for location in inventory.locations where location.image.lowercased() == name.lowercased() {
            links.append(.init(owner: .location(location.id), index: 0))
        }
        return links
    }
}

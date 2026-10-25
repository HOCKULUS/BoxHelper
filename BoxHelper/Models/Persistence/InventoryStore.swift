import Foundation
import SwiftData

/// Ein gemeinsamer Store für UI und AppIntents. ModelContext bleibt immer auf dem MainActor;
/// Hintergrundarbeit erhält ausschließlich Codable-/Sendable-Wertkopien.
@MainActor
final class InventoryStore {
    let container: ModelContainer
    let trash: InventoryTrashStore
    private(set) var latestCommit: InventoryCommit?
    private let defaults: UserDefaults
    private let repairMissingLocationsOnSave: Bool
    private static let migrationKey = "userDefaultsInventoryV1"
    private static let legacyKeys = ["movingBoxes", "itemsDatabase", "locationsDatabase"]

    init(container: ModelContainer, defaults: UserDefaults = .standard,
         repairMissingLocationsOnSave: Bool? = nil, trashDocuments: URL? = nil) throws {
        self.container = container
        self.defaults = defaults
        self.trash = InventoryTrashStore(defaults: defaults, documents: trashDocuments)
        // Der explizite Override macht dieselbe Cloud-Policy ohne Account-/Entitlementzugriff
        // testbar. Im normalen Appbetrieb bestimmt ausschließlich die aktive Storekonfiguration.
        self.repairMissingLocationsOnSave = repairMissingLocationsOnSave
            ?? !container.configurations.contains { $0.cloudKitContainerIdentifier != nil }
        try migrateUserDefaultsIfNeeded()
    }

    static func makeContainer(url: URL? = nil, inMemory: Bool = false,
                              cloudSyncEnabled: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: InventorySchemaV4.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration("Inventory", schema: schema, isStoredInMemoryOnly: true,
                                               cloudKitDatabase: .none)
        } else {
            let storeURL: URL
            if let url { storeURL = url }
            else {
                let support = try FileManager.default.url(for: .applicationSupportDirectory,
                                                         in: .userDomainMask, appropriateFor: nil, create: true)
                storeURL = support.appendingPathComponent("BoxHelper", isDirectory: true)
                    .appendingPathComponent("Inventory.store")
            }
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try InventorySchemaRecovery.prepareIfNeeded(at: storeURL, schema: schema)
            // Eigenes Verzeichnis: Medien-/Backup-Bereinigung im Documents-Ordner berührt die DB nicht.
            // Ein Laufzeitwechsel öffnet dieselbe lokale Datei mit der neuen Konfiguration,
            // nachdem die bisherige Session und sämtliche Worker freigegeben wurden.
            let cloudDatabase: ModelConfiguration.CloudKitDatabase = cloudSyncEnabled
                ? .private("iCloud.de.hockulus.boxhelper") : .none
            configuration = ModelConfiguration("Inventory", schema: schema, url: storeURL,
                                               cloudKitDatabase: cloudDatabase)
        }
        return try ModelContainer(for: schema, migrationPlan: InventorySchemaMigrationPlan.self,
                                  configurations: [configuration])
    }

    func snapshot() throws -> InventorySnapshot {
        // Neue Kontexte verhindern veraltete registrierte Objekte nach einem Intent-Commit.
        let context = ModelContext(container)
        let records = try fetchRecords(in: context)
        let deleted = try InventoryDeletedIDs(
            boxes: Set(InventoryNativeDeletion.deletedVersions(for: records.boxes, in: context, includeAll: true).keys),
            locations: Set(InventoryNativeDeletion.deletedVersions(for: records.locations, in: context, includeAll: true).keys))
        // Schon beim Kaltstart konsistent darstellen; der Hintergrundleser meldet
        // dieselben rohen Datensätze anschließend zur dauerhaften Reparatur.
        let inventory = InventoryIntegritySelection.clean(try snapshot(from: records, in: context), deleted: deleted, preservingDates: true)
        try trash.reconcile(inventory, deletionDates: InventoryNativeDeletion.trashDates(in: context))
        return inventory
    }

    /// Formularprüfungen lesen nur die ausgewählten UUIDs frisch aus SQLite. So bleiben
    /// Löschungen/Abschlüsse anderer Geräte sichtbar, ohne alle Items zu materialisieren.
    /// `locationIDs == nil` liest alle Standorte für die bestehende Namensauswahl.
    func selection(boxIDs: [UUID] = [], itemIDs: [UUID] = [], locationIDs: [UUID]? = []) throws -> InventorySnapshot {
        let context = ModelContext(container)
        let boxes = boxIDs.isEmpty ? [] : try context.fetch(FetchDescriptor<StoredBox>(
            predicate: #Predicate { boxIDs.contains($0.id) }))
        let items = itemIDs.isEmpty ? [] : try context.fetch(FetchDescriptor<StoredItem>(
            predicate: #Predicate { itemIDs.contains($0.id) }))
        let locations: [StoredLocation]
        if let locationIDs {
            locations = locationIDs.isEmpty ? [] : try context.fetch(FetchDescriptor<StoredLocation>(
                predicate: #Predicate { locationIDs.contains($0.id) }))
        } else { locations = try context.fetch(FetchDescriptor<StoredLocation>()) }
        let inventory = try snapshot(from: InventoryRecords(boxes: boxes, items: items, locations: locations), in: context)
        let deleted = try InventoryIntegritySelection.deletedParents(for: inventory, context: context)
        return InventoryIntegritySelection.clean(inventory, deleted: deleted, preservingDates: true)
    }

    /// Frische, eng begrenzte Leser für die gemeinsamen Löschregeln von UI und Intents.
    func children(in boxes: Set<UUID>) throws -> [Items] {
        try InventoryIntegritySelection.children(of: boxes, context: ModelContext(container))
    }

    func boxes(at locations: Set<UUID>) throws -> [MovingBox] {
        try InventoryIntegritySelection.boxes(at: locations, context: ModelContext(container))
    }

    @discardableResult
    func repairIntegrity(candidates: InventoryIntegrityCandidates) throws -> Bool {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let change = try InventoryIntegritySelection.changes(candidates, context: context)
        var deleted = InventoryIDs()
        deleted.boxes = Set(change.before.boxes.map(\.id)).subtracting(change.after.boxes.map(\.id))
        deleted.items = Set(change.before.items.map(\.id)).subtracting(change.after.items.map(\.id))
        deleted.locations = Set(change.before.locations.map(\.id)).subtracting(change.after.locations.map(\.id))
        // Keine Legacy-Normalisierung des Gesamtbestands und keine zusätzliche Kaskade:
        // Der Worker meldet alle Kinder separat. Auch alte Payloads bleiben begrenzt.
        let saved = try commit(change.after, context: context,
            records: InventoryRecords(boxes: change.boxes, items: change.items, locations: change.locations),
            replacing: [], upserting: InventoryIDs(change.after), deleting: deleted,
            itemDeletionVersions: change.itemDeletionVersions, trashSource: .cloud)
        if saved { latestCommit = .patch(change.after, deleting: .init(boxes: deleted.boxes, items: deleted.items, locations: deleted.locations)) }
        return saved
    }

    /// Fehlende Cloud-Referenzen sind keine Löschungen. Formulare dürfen ihre Auswahl
    /// erst entfernen, wenn tatsächlich ein neuerer UUID-Tombstone eingetroffen ist.
    func deletedIDs() throws -> InventoryDeletedIDs {
        let context = ModelContext(container)
        return try InventoryDeletedIDs(
            boxes: Set(InventoryNativeDeletion.deletedVersions(for: context.fetch(FetchDescriptor<StoredBox>()), in: context, includeAll: true).keys),
            locations: Set(InventoryNativeDeletion.deletedVersions(for: context.fetch(FetchDescriptor<StoredLocation>()), in: context, includeAll: true).keys))
    }

    @discardableResult
    func saveBoxes(_ boxes: [MovingBox]) throws -> Bool {
        let baselineIDs = InventoryIDs(InventorySnapshot(boxes: boxes, items: [], locations: []))
        return try mutateInventory(replacing: [.boxes], preservingDeletionsFor: baselineIDs,
                                   protectingAllDeletions: true) { current in
            var result = current
            result.boxes = boxes
            return result
        }
    }

    @discardableResult
    func saveItems(_ items: [Items]) throws -> Bool {
        let baselineIDs = InventoryIDs(InventorySnapshot(boxes: [], items: items, locations: []))
        return try mutateInventory(replacing: [.items], preservingDeletionsFor: baselineIDs,
                                   protectingAllDeletions: true) { current in
            var result = current
            result.items = items
            return result
        }
    }

    @discardableResult
    func saveLocations(_ locations: [Locations]) throws -> Bool {
        let baselineIDs = InventoryIDs(InventorySnapshot(boxes: [], items: [], locations: locations))
        return try mutateInventory(replacing: [.locations], preservingDeletionsFor: baselineIDs,
                                   protectingAllDeletions: true) { current in
            var result = current
            result.locations = locations
            return result
        }
    }

    /// Explizite Wiederherstellung ersetzt alle Tabellen mit einer atomaren Transaktion.
    @discardableResult
    func saveInventory(boxes: [MovingBox], items: [Items], locations: [Locations]) throws -> Bool {
        try mutateInventory(replacing: [.boxes, .items, .locations]) { _ in
            InventorySnapshot(boxes: boxes, items: items, locations: locations)
        }
    }

    /// Imports ergänzen ausschließlich die übergebenen UUIDs. Nicht mitgelieferte Cloud-Daten
    /// bleiben erhalten, auch wenn sie erst nach einer früheren Importvorschau eingetroffen sind.
    @discardableResult
    func mergeInventory(boxes: [MovingBox], items: [Items], locations: [Locations]) throws -> Bool {
        let incoming = InventorySnapshot(boxes: boxes, items: items, locations: locations)
        try validate(incoming)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        if let selection = try InventoryMergeSelection.prepare(incoming, context: context,
                                                                repairMissingLocations: repairMissingLocationsOnSave,
                                                                detachRestoredItems: true) {
            let normalized = selection.inventory
            var deleted = InventoryIDs()
            deleted.items = selection.deleted.items
            let saved = try commit(normalized, context: context,
                records: InventoryRecords(boxes: selection.boxes, items: selection.items, locations: selection.locations),
                replacing: [], upserting: InventoryIDs(normalized), deleting: deleted, positions: selection)
            if saved {
                latestCommit = selection.deleted.count == 0 ? .merge(normalized) : .patch(normalized, deleting: selection.deleted)
            }
            return saved
        }
        return try mutateInventory(replacing: [], upserting: InventoryIDs(incoming),
                                   restoringDetachedItems: Set(incoming.items.map(\.id))) { current in
            InventorySnapshot(boxes: mergeUpserts(boxes, into: current.boxes),
                              items: mergeUpserts(items, into: current.items),
                              locations: mergeUpserts(locations, into: current.locations))
        }
    }

    /// Änderungen einer Ansicht werden auf den aktuellen Bestand gepatcht. Neue Cloud-UUIDs
    /// und zwischenzeitliche Bearbeitungen anderer Felder bleiben dabei erhalten.
    /// Ein Freigabe-Eingang kann ältere Tombstones ausdrücklich wiederherstellen; der
    /// Empfangszeitpunkt schützt dabei alle erst später lokal gelöschten UUIDs.
    @discardableResult
    func applyInventoryChanges(from initial: InventorySnapshot, to requested: InventorySnapshot,
                               preservingDeletionsAfter cutoff: Date? = nil,
                               trashSource: InventoryTrashEntry.Source = .local) throws -> Bool {
        var baseline = initial
        var desired = requested
        let removedBoxes = Set(baseline.boxes.map(\.id)).subtracting(desired.boxes.map(\.id))
        if !removedBoxes.isEmpty {
            let children = try self.children(in: removedBoxes)
            let existing = Set(baseline.items.map(\.id))
            baseline.items.append(contentsOf: children.filter { !existing.contains($0.id) })
            let childIDs = Set(children.map(\.id))
            // Ein im selben Commit ausdrücklich verschobenes Kind bleibt erhalten.
            desired.items.removeAll { childIDs.contains($0.id) && $0.box_uuid.map(removedBoxes.contains) == true }
        }
        let removedLocations = Set(baseline.locations.map(\.id)).subtracting(desired.locations.map(\.id))
        if !removedLocations.isEmpty {
            let boxes = try self.boxes(at: removedLocations)
            let existing = Set(baseline.boxes.map(\.id))
            baseline.boxes.append(contentsOf: boxes.filter { !existing.contains($0.id) })
            let desiredIDs = Set(desired.boxes.map(\.id))
            desired.boxes.append(contentsOf: boxes.filter { !desiredIDs.contains($0.id) && !removedBoxes.contains($0.id) })
            desired = InventoryIntegritySelection.clean(desired, deleted: .init(boxes: [], locations: removedLocations))
        }
        try validate(baseline)
        try validate(desired)
        let before = InventoryIDs(baseline)
        let after = InventoryIDs(desired)
        var deleted = InventoryIDs()
        deleted.boxes = before.boxes.subtracting(after.boxes)
        deleted.items = before.items.subtracting(after.items)
        deleted.locations = before.locations.subtracting(after.locations)
        var edited = InventoryIDs()
        edited.boxes = changedIDs(desired.boxes, comparedTo: baseline.boxes)
        edited.items = changedIDs(desired.items, comparedTo: baseline.items)
        edited.locations = changedIDs(desired.locations, comparedTo: baseline.locations)
        var reordered: Set<Table> = []
        if requiresReindexing(from: baseline.boxes, to: desired.boxes) { reordered.insert(.boxes) }
        if requiresReindexing(from: baseline.items, to: desired.items) { reordered.insert(.items) }
        if requiresReindexing(from: baseline.locations, to: desired.locations) { reordered.insert(.locations) }
        if reordered.isEmpty {
            let focusedBefore = InventorySnapshot(boxes: baseline.boxes.filter { edited.boxes.contains($0.id) || deleted.boxes.contains($0.id) },
                items: baseline.items.filter { edited.items.contains($0.id) || deleted.items.contains($0.id) },
                locations: baseline.locations.filter { edited.locations.contains($0.id) || deleted.locations.contains($0.id) })
            let focusedAfter = InventorySnapshot(boxes: desired.boxes.filter { edited.boxes.contains($0.id) },
                items: desired.items.filter { edited.items.contains($0.id) },
                locations: desired.locations.filter { edited.locations.contains($0.id) })
            let context = ModelContext(container)
            context.autosaveEnabled = false
            if let selection = try InventoryChangeSelection.prepare(from: focusedBefore, to: focusedAfter,
                deleting: .init(boxes: deleted.boxes, items: deleted.items, locations: deleted.locations),
                preservingDeletedIDs: .init(boxes: before.boxes, items: before.items, locations: before.locations),
                preservingDeletionsAfter: cutoff, context: context,
                repairMissingLocations: repairMissingLocationsOnSave) {
                let inventory = selection.inventory
                deleted.items.formUnion(selection.deleted.items)
                let saved = try commit(inventory, context: context,
                    records: InventoryRecords(boxes: selection.boxes, items: selection.items, locations: selection.locations),
                    replacing: [], upserting: InventoryIDs(inventory), deleting: deleted, positions: selection, trashSource: trashSource)
                if saved { latestCommit = .patch(inventory, deleting: .init(boxes: deleted.boxes, items: deleted.items, locations: deleted.locations)) }
                return saved
            }
        }
        return try mutateInventory(replacing: [], upserting: edited, deleting: deleted,
                                   preservingDeletionsFor: before, protectingAllDeletions: true,
                                   preservingDeletionsAfter: cutoff, reordering: reordered, trashSource: trashSource) { current in
            InventorySnapshot(boxes: InventoryFieldChanges.boxes(from: baseline.boxes, to: desired.boxes, in: current.boxes),
                              items: InventoryFieldChanges.items(from: baseline.items, to: desired.items, in: current.items),
                              locations: InventoryFieldChanges.locations(from: baseline.locations, to: desired.locations, in: current.locations))
        }
    }

    @discardableResult
    func clearInventory() throws -> Bool {
        let context = ModelContext(container)
        let records = try fetchRecords(in: context)
        var removed = InventoryIDs()
        removed.boxes = Set(records.boxes.map(\.id))
        removed.items = Set(records.items.map(\.id))
        removed.locations = Set(records.locations.map(\.id))
        for (kind, keyPath) in [("box", \InventoryIDs.boxes), ("item", \InventoryIDs.items), ("location", \InventoryIDs.locations)] {
            let states = try InventoryDeletionLedger.states(in: context, kind: kind)
            removed[keyPath: keyPath].formUnion(states.keys.compactMap { UUID(uuidString: $0) })
        }
        // Ein ausdrückliches Leeren umfasst auch bereits angekündigte Restores, deren
        // Nutzdaten noch unterwegs sind. Migrationsmarker und logischer Schutz bleiben.
        return try mutateInventory(replacing: [.boxes, .items, .locations], deleting: removed) { _ in .empty }
    }

    func storageSize() throws -> Int {
        let manager = FileManager.default
        return try container.configurations.reduce(0) { total, configuration in
            guard !configuration.isStoredInMemoryOnly else { return total }
            let path = configuration.url.path
            return try [path, path + "-wal", path + "-shm"].reduce(total) { sum, path in
                guard manager.fileExists(atPath: path) else { return sum }
                let size = (try manager.attributesOfItem(atPath: path)[.size]) as? NSNumber
                return sum + (size?.intValue ?? 0)
            }
        }
    }

    private func migrateUserDefaultsIfNeeded() throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let markers = try context.fetch(FetchDescriptor<InventoryMigrationMarker>())
        if markers.contains(where: { $0.key == Self.migrationKey }) {
            // Nach einem Abbruch zwischen Commit und Cleanup ist die DB bereits maßgeblich.
            removeLegacyKeys()
            return
        }

        let legacy = InventorySnapshot(
            boxes: try decodeLegacy([MovingBox].self, key: "movingBoxes") ?? [],
            items: try decodeLegacy([Items].self, key: "itemsDatabase") ?? [],
            locations: try decodeLegacy([Locations].self, key: "locationsDatabase") ?? []
        )
        try validate(legacy)
        let records = try fetchRecords(in: context)
        let current = try snapshot(from: records, in: context)
        // Vorhandene DB-Einträge bleiben maßgeblich, falls eine Vorabversion schon Daten angelegt hat.
        var combined = InventorySnapshot(
            boxes: mergeMissing(legacy.boxes, into: current.boxes),
            items: mergeMissing(legacy.items, into: current.items),
            locations: mergeMissing(legacy.locations, into: current.locations)
        )
        // Automatische Alt-Datenübernahme ist kein ausdrücklicher Restore. Bereits
        // bekannte Löschungen bleiben auch bei einem verspäteten Migrationsmarker
        // maßgeblich; DataManager darf ihre Eltern nicht synthetisch neu erzeugen.
        let deletedBoxes = Set(try InventoryNativeDeletion.deletedVersions(for: records.boxes, in: context, includeAll: true).keys)
        let deletedItems = Set(try InventoryNativeDeletion.deletedVersions(for: records.items, in: context, includeAll: true).keys)
        let deletedLocations = Set(try InventoryNativeDeletion.deletedVersions(for: records.locations, in: context, includeAll: true).keys)
        combined.boxes.removeAll { deletedBoxes.contains($0.id) }
        combined.items.removeAll { deletedItems.contains($0.id) }
        combined.locations.removeAll { deletedLocations.contains($0.id) }
        combined = InventoryIntegritySelection.clean(combined, deleted: .init(boxes: deletedBoxes, locations: deletedLocations))
        // Die vollständige Altquelle gehört zur Migration; hier sind fehlende IDs keine
        // nur zeitversetzt eintreffenden Cloud-Datensätze und können sicher repariert werden.
        let normalized = DataManager.normalized(combined, repairMissingLocations: true)
        try commit(normalized, context: context, records: records, replacing: [],
                   upserting: InventoryIDs(normalized), completingMigration: true)
        // Erfolgreiches erneutes Lesen prüft den gespeicherten Bestand vor dem Entfernen der Quelle.
        _ = try snapshot()
        removeLegacyKeys()
    }

    private func decodeLegacy<T: Decodable>(_ type: T.Type, key: String) throws -> T? {
        guard let raw = defaults.object(forKey: key) else { return nil }
        guard let data = raw as? Data else { throw InventoryStorageError.invalidLegacyData(key) }
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw InventoryStorageError.invalidLegacyData(key) }
    }

    private func removeLegacyKeys() {
        Self.legacyKeys.forEach { defaults.removeObject(forKey: $0) }
    }

    private func mergeMissing<T: Identifiable>(_ legacy: [T], into current: [T]) -> [T] where T.ID == UUID {
        let currentIDs = Set(current.map(\.id))
        return current + legacy.filter { !currentIDs.contains($0.id) }
    }

    private func validate(_ inventory: InventorySnapshot) throws {
        func check<T: Identifiable>(_ values: [T], table: String) throws where T.ID == UUID {
            guard Set(values.map(\.id)).count == values.count else {
                throw InventoryStorageError.duplicateID(table)
            }
        }
        try check(inventory.boxes, table: "Kisten")
        try check(inventory.items, table: "Items")
        try check(inventory.locations, table: "Standorte")
    }

    private enum Table: Hashable { case boxes, items, locations }

    /// Genau ein Fetch je Tabelle liefert sowohl den Arbeits-Snapshot als auch die zu
    /// ändernden SwiftData-Objekte. Ein später eingetroffener Fremdtabelleneintrag wird nie gelöscht.
    private struct InventoryRecords {
        let boxes: [StoredBox]
        let items: [StoredItem]
        let locations: [StoredLocation]
    }

    private struct InventoryIDs {
        var boxes: Set<UUID> = []
        var items: Set<UUID> = []
        var locations: Set<UUID> = []

        init() { }
        init(_ inventory: InventorySnapshot) {
            boxes = Set(inventory.boxes.map(\.id))
            items = Set(inventory.items.map(\.id))
            locations = Set(inventory.locations.map(\.id))
        }
    }

    private func fetchRecords(in context: ModelContext) throws -> InventoryRecords {
        InventoryRecords(boxes: try context.fetch(FetchDescriptor<StoredBox>()),
                         items: try context.fetch(FetchDescriptor<StoredItem>()),
                         locations: try context.fetch(FetchDescriptor<StoredLocation>()))
    }

    private func snapshot(from records: InventoryRecords, in context: ModelContext) throws -> InventorySnapshot {
        InventorySnapshot(boxes: try InventoryNativeDeletion.active(records.boxes, in: context).map(\.value),
                          items: try InventoryNativeDeletion.active(records.items, in: context).map(\.value),
                          locations: try InventoryNativeDeletion.active(records.locations, in: context).map(\.value))
    }

    @discardableResult
    private func mutateInventory(replacing tables: Set<Table>, upserting ids: InventoryIDs = InventoryIDs(),
                                 deleting deleted: InventoryIDs = InventoryIDs(),
                                 preservingDeletionsFor baselineIDs: InventoryIDs = InventoryIDs(),
                                 protectingAllDeletions: Bool = false,
                                 preservingDeletionsAfter cutoff: Date? = nil,
                                 reordering reordered: Set<Table> = [],
                                 restoringDetachedItems importedItems: Set<UUID> = [],
                                 trashSource: InventoryTrashEntry.Source = .local,
                                 mutation: (InventorySnapshot) -> InventorySnapshot) throws -> Bool {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let records = try fetchRecords(in: context)
        let current = try snapshot(from: records, in: context)
        var requested = mutation(current)
        try validate(requested)
        // Ein später speicherndes Formular darf eine seit seiner Ausgangskopie gelöschte
        // UUID nicht wiederherstellen. Ein expliziter Backup-Restore benutzt mergeInventory.
        let deletedBoxes = protectingAllDeletions
            ? try InventoryChangeSelection.protectedIDs(try winningRecords(records.boxes), baseline: baselineIDs.boxes, cutoff: cutoff, context: context, including: Set(requested.boxes.map(\.id)).union(baselineIDs.boxes))
            : (baselineIDs.boxes.isEmpty ? [] : Set(try InventoryNativeDeletion.deletedVersions(for: records.boxes, in: context, includeAll: true).keys).intersection(baselineIDs.boxes))
        let deletedItems = protectingAllDeletions
            ? try InventoryChangeSelection.protectedIDs(try winningRecords(records.items), baseline: baselineIDs.items, cutoff: cutoff, context: context, including: Set(requested.items.map(\.id)).union(baselineIDs.items))
            : (baselineIDs.items.isEmpty ? [] : Set(try InventoryNativeDeletion.deletedVersions(for: records.items, in: context, includeAll: true).keys).intersection(baselineIDs.items))
        let deletedLocations = protectingAllDeletions
            ? try InventoryChangeSelection.protectedIDs(try winningRecords(records.locations), baseline: baselineIDs.locations, cutoff: cutoff, context: context, including: Set(requested.locations.map(\.id)).union(baselineIDs.locations))
            : (baselineIDs.locations.isEmpty ? [] : Set(try InventoryNativeDeletion.deletedVersions(for: records.locations, in: context, includeAll: true).keys).intersection(baselineIDs.locations))
        requested.boxes.removeAll { deletedBoxes.contains($0.id) }
        requested.items.removeAll { deletedItems.contains($0.id) }
        requested.locations.removeAll { deletedLocations.contains($0.id) }
        var restored = InventoryObjectIDs(boxes: ids.boxes, items: ids.items, locations: ids.locations)
        if tables.contains(.boxes) { restored.boxes.formUnion(requested.boxes.map(\.id)) }
        if tables.contains(.locations) { restored.locations.formUnion(requested.locations.map(\.id)) }
        var removedParents = try InventoryIntegritySelection.deletedParents(for: requested, context: context, restoring: restored)
        removedParents.boxes.formUnion(deleted.boxes)
        removedParents.locations.formUnion(deleted.locations)
        if tables.contains(.boxes) {
            removedParents.boxes.formUnion(Set(current.boxes.map(\.id)).subtracting(requested.boxes.map(\.id)))
        }
        if tables.contains(.locations) {
            removedParents.locations.formUnion(Set(current.locations.map(\.id)).subtracting(requested.locations.map(\.id)))
        }
        let restoredItems = tables.contains(.items) ? Set(requested.items.map(\.id)) : importedItems
        requested = InventoryIntegritySelection.detachRestoredItems(requested, ids: restoredItems, deletedBoxes: removedParents.boxes)
        let consistent = InventoryIntegritySelection.clean(requested, deleted: removedParents)
        var normalized = DataManager.normalized(consistent, repairMissingLocations: repairMissingLocationsOnSave)
        // Synthetische Legacy-Reparaturen dürfen ausdrücklich gelöschte UUIDs nicht neu anlegen.
        normalized.boxes.removeAll { deleted.boxes.contains($0.id) }
        normalized.items.removeAll { deleted.items.contains($0.id) }
        normalized.locations.removeAll { deleted.locations.contains($0.id) || deletedLocations.contains($0.id) }
        var affected = ids
        // Altdaten-Normalisierung kann ergänzte Gegenstände oder Standorte erzeugen. Solche
        // Änderungen werden mitgeschrieben, ohne unveränderte andere UUIDs anzufassen.
        affected.boxes.formUnion(changedIDs(normalized.boxes, comparedTo: current.boxes))
        affected.items.formUnion(changedIDs(normalized.items, comparedTo: current.items))
        affected.locations.formUnion(changedIDs(normalized.locations, comparedTo: current.locations))
        // Beim Umsortieren brauchen auch unveränderte Cloud-Zwischenzeilen neue Positionen;
        // deren aktuelle DTO-Felder werden unverändert aus demselben Context übernommen.
        if reordered.contains(.boxes) { affected.boxes.formUnion(normalized.boxes.map(\.id)) }
        if reordered.contains(.items) { affected.items.formUnion(normalized.items.map(\.id)) }
        if reordered.contains(.locations) { affected.locations.formUnion(normalized.locations.map(\.id)) }
        var actualDeleted = deleted
        let retainedItemIDs = Set(normalized.items.map(\.id))
        actualDeleted.items.formUnion(Set(current.items.filter {
            $0.box_uuid.map(removedParents.boxes.contains) == true && !retainedItemIDs.contains($0.id)
        }.map(\.id)))
        let saved = try commit(normalized, context: context, records: records, replacing: tables,
                               upserting: affected, deleting: actualDeleted, reordering: reordered, trashSource: trashSource)
        if saved { latestCommit = .replace(normalized) }
        return saved
    }

    private func changedIDs<Value: Identifiable & Equatable>(_ values: [Value], comparedTo current: [Value]) -> Set<UUID>
    where Value.ID == UUID {
        let existing = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        return Set(values.filter { existing[$0.id] != $0 }.map(\.id))
    }

    /// Anhängen am Ende benötigt nur SQL MAX(position), keine Materialisierung und
    /// Neuindizierung des gesamten privaten Inventars. Einfügen zwischen alten UUIDs
    /// oder eine geänderte relative Reihenfolge bleibt ausdrücklich ein Reorder.
    private func requiresReindexing<Value: Identifiable>(from baseline: [Value], to desired: [Value]) -> Bool
    where Value.ID == UUID {
        let oldIDs = Set(baseline.map(\.id)), desiredIDs = Set(desired.map(\.id))
        guard baseline.filter({ desiredIDs.contains($0.id) }).map(\.id)
            == desired.filter({ oldIDs.contains($0.id) }).map(\.id) else { return true }
        var reachedNewIDs = false
        for value in desired {
            if !oldIDs.contains(value.id) { reachedNewIDs = true }
            else if reachedNewIDs { return true }
        }
        return false
    }

    private func mergeUpserts<Value: Identifiable>(_ incoming: [Value], into current: [Value]) -> [Value]
    where Value.ID == UUID {
        var result = current
        let indices = Dictionary(uniqueKeysWithValues: current.enumerated().map { ($0.element.id, $0.offset) })
        for value in incoming {
            if let index = indices[value.id] { result[index] = value }
            else { result.append(value) }
        }
        return result
    }

    @discardableResult
    private func commit(_ inventory: InventorySnapshot, context: ModelContext, records: InventoryRecords,
                        replacing tables: Set<Table>, upserting ids: InventoryIDs,
                        deleting deleted: InventoryIDs = InventoryIDs(),
                        reordering reordered: Set<Table> = [],
                        completingMigration: Bool = false, positions: InventoryMergeSelection? = nil,
                        itemDeletionVersions: [UUID: Date] = [:],
                        trashSource: InventoryTrashEntry.Source = .local) throws -> Bool {
        try validate(inventory)
        // Auch Kinder mit gerade eingetroffenem Elterntombstone besitzen hier noch
        // ihre vollständige Payload. Vor dem Mutieren der ModelObjects kopieren.
        let before = InventorySnapshot(
            boxes: try winningRecords(records.boxes).filter { !$0.isTombstoned }.map(\.value),
            items: try winningRecords(records.items).filter { !$0.isTombstoned }.map(\.value),
            locations: try winningRecords(records.locations).filter { !$0.isTombstoned }.map(\.value))
        do {
            try InventoryRecordWriter.synchronize(inventory.boxes, records: records.boxes, in: context,
                            deleteMissing: tables.contains(.boxes), writingIDs: ids.boxes, deletingIDs: deleted.boxes,
                            reindex: tables.contains(.boxes) || reordered.contains(.boxes),
                            startingPosition: positions?.boxPosition,
                            make: { StoredBox($0, position: $1) }, update: { $0.update(from: $1, position: $2) })
            try InventoryRecordWriter.synchronize(inventory.items, records: records.items, in: context,
                            deleteMissing: tables.contains(.items), writingIDs: ids.items, deletingIDs: deleted.items,
                            reindex: tables.contains(.items) || reordered.contains(.items),
                            startingPosition: positions?.itemPosition,
                            deletionVersions: itemDeletionVersions,
                            make: { StoredItem($0, position: $1) }, update: { $0.update(from: $1, position: $2) })
            try InventoryRecordWriter.synchronize(inventory.locations, records: records.locations, in: context,
                            deleteMissing: tables.contains(.locations), writingIDs: ids.locations, deletingIDs: deleted.locations,
                            reindex: tables.contains(.locations) || reordered.contains(.locations),
                            startingPosition: positions?.locationPosition,
                            make: { StoredLocation($0, position: $1) }, update: { $0.update(from: $1, position: $2) })
            if completingMigration { context.insert(InventoryMigrationMarker(key: Self.migrationKey)) }
            guard context.hasChanges else { return false }
            let removed = InventoryObjectIDs(
                boxes: Set(context.deletedModelsArray.compactMap { ($0 as? StoredBox)?.id }),
                items: Set(context.deletedModelsArray.compactMap { ($0 as? StoredItem)?.id }),
                locations: Set(context.deletedModelsArray.compactMap { ($0 as? StoredLocation)?.id }))
            let backup = try trash.prepareChange(before: before, after: inventory, deleting: removed, source: trashSource,
                deletionDates: InventoryNativeDeletion.trashDates(in: context, boxIDs: removed.boxes,
                    itemIDs: removed.items, locationIDs: removed.locations))
            try context.save()
            trash.commit(backup)
            return true
        } catch {
            // Kein Teilcommit und kein Autosave: sämtliche Tabellen und Syncversionen zurückrollen.
            context.rollback()
            throw error
        }
    }

    /// Syncrevision und DTO-Datum bestimmen gemeinsam den Gewinner. Bei gleicher Version
    /// gewinnt eine Löschung; erst danach entscheiden Payload und Listenposition deterministisch.
    private func winningRecords<Record: InventoryRecord>(_ records: [Record]) throws -> [Record] {
        try InventoryRecordSelection.winners(records)
    }
}

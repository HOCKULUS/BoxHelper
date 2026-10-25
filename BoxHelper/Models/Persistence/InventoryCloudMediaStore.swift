import CryptoKit
import Foundation
import ImageIO
import SwiftData

/// Schmaler Profiling-Seam: Tests messen dieselben produktiven Phasen, ohne große
/// Dateiinhalte oder ModelObjects aus dem Worker herauszureichen.
struct InventoryCloudMediaTiming: Sendable {
    let phase: String
    let duration: Duration
    let isMainThread: Bool
}

/// Verbindet CloudKit-Assets mit dem bisherigen Bilddateisystem, ohne Inventarreferenzen zu verändern.
/// Das lokale Receipt unterscheidet gelöschte lokale Fotos von erstmalig eingetroffenen Cloud-Fotos.
enum InventoryCloudMediaStore {
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var receiptsURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BoxHelper", isDirectory: true)
            .appendingPathComponent("cloud-media-receipts-v1.json")
    }

    /// Den Löschauftrag vor der Dateilöschung dauerhaft bestätigen. CloudKit erhält
    /// echte Record-Löschungen; der separate Marker schützt verspätete Duplikate.
    @MainActor
    static func delete(filenames: Set<String>, container: ModelContainer, at: Date = Date(),
                       documents: URL = documents) throws {
        let names = filenames.filter(isValidFilename)
        guard !names.isEmpty else { return }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let keys = Array(names)
        let records = try context.fetch(FetchDescriptor<StoredInventoryImage>(predicate: #Predicate { keys.contains($0.filename) }))
        let grouped = Dictionary(grouping: records, by: \.filename)
        let states = try InventoryDeletionLedger.states(in: context, kind: "photo", keys: keys)
        do {
            for name in names {
                let matching = grouped[name] ?? []
                let file = documents.appendingPathComponent(name)
                let modified = FileManager.default.fileExists(atPath: file.path)
                    ? try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate : nil
                let prior = matching.map(\.updatedAt) + [states[name]?.revision, modified].compactMap { $0 }
                let version = InventoryDeletionLedger.nextVersion(after: prior, proposed: at)
                try InventoryDeletionLedger.recordDeletion(kind: "photo", key: name, at: version, in: context)
                for record in matching { context.delete(record) }
            }
            if context.hasChanges { try context.save() }
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Ein ausdrücklicher Papierkorb-Restore erhält eine Version nach dem letzten
    /// Tombstone, auch wenn dessen Zeitstempel von einem anderen Gerät vorausliegt.
    @MainActor
    static func restore(photos: [String: Data], container: ModelContainer) throws {
        guard !photos.isEmpty else { return }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let names = Array(photos.keys)
        let records = try context.fetch(FetchDescriptor<StoredInventoryImage>(predicate: #Predicate { names.contains($0.filename) }))
        let grouped = Dictionary(grouping: records, by: \.filename)
        let states = try InventoryDeletionLedger.states(in: context, kind: "photo", keys: names)
        do {
            for (name, bytes) in photos {
                guard isValidFilename(name) else { throw InventoryCloudMediaError.unsafeFile(name) }
                try validateImage(bytes, filename: name)
                let rows = grouped[name] ?? []
                let version = InventoryDeletionLedger.nextVersion(after: rows.map(\.updatedAt) + [states[name]?.revision].compactMap { $0 })
                for row in rows { context.delete(row) }
                context.insert(StoredInventoryImage(filename: name, data: bytes, updatedAt: version))
                try InventoryDeletionLedger.recordRestore(kind: "photo", key: name, at: version, in: context)
            }
            try context.save()
        } catch { context.rollback(); throw error }
    }

    /// Ein Asset kann schon in SwiftData liegen, bevor seine lokale Datei fertig
    /// heruntergeladen wurde. Auch diese Bytes vor einer lokalen Löschung sichern.
    @MainActor
    static func photoBackups(filenames: Set<String>, container: ModelContainer) throws -> [String: Data] {
        let names = Array(filenames.filter(isValidFilename))
        guard !names.isEmpty else { return [:] }
        let context = ModelContext(container)
        let rows = try context.fetch(FetchDescriptor<StoredInventoryImage>(predicate: #Predicate { names.contains($0.filename) }))
        var photos: [String: Data] = [:]
        for (name, group) in Dictionary(grouping: rows, by: \.filename) {
            let version = try newestImage(in: group)
            if !version.isDeleted { photos[name] = version.data }
        }
        return photos
    }

    /// Auch lose Fotos werden erfasst. Die Rückgabe zeigt echte Änderungen an Datenbank/Dateien an.
    /// `save` ist ein schmaler Test-Seam für den Fall eines abgewiesenen SwiftData-Commits.
    @MainActor
    @discardableResult
    static func reconcile(
        container: ModelContainer,
        documents: URL = documents,
        receiptsURL: URL = receiptsURL,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> Bool {
        let context = ModelContext(container)
        guard let plan = try prepare(context: context, documents: documents, receiptsURL: receiptsURL, save: save) else { return false }
        return try plan.apply()
    }

    /// Nur der aufrufende ModelActor verwendet diesen Context. Bildprüfung und Hashes
    /// brauchen keine UI-Isolation; ausschließlich Wertkopien verlassen den Context.
    static func prepare(context: ModelContext, documents: URL, receiptsURL: URL,
                        save: (ModelContext) throws -> Void = { try $0.save() },
                        trace: (@Sendable (InventoryCloudMediaTiming) -> Void)? = nil) throws -> Reconciliation? {
        var phaseStarted = ContinuousClock.now
        func phase(_ name: String) {
            let now = ContinuousClock.now
            trace?(.init(phase: name, duration: now - phaseStarted, isMainThread: Thread.isMainThread))
            phaseStarted = now
        }
        context.autosaveEnabled = false
        let records = try context.fetch(FetchDescriptor<StoredInventoryImage>())
        phase("fetch")
        let receiptOriginal = FileManager.default.fileExists(atPath: receiptsURL.path) ? try Data(contentsOf: receiptsURL) : nil
        let previous = try readReceipt(at: receiptsURL)
        let local = try readLocalImages(in: documents)
        phase("read-local")
        let grouped = Dictionary(grouping: records, by: \.filename)
        let states = try InventoryDeletionLedger.states(in: context, kind: "photo")
        // Fehlende Assets bleiben pro Datei ausstehend. Sie dürfen weder andere
        // Löschungen blockieren noch durch eine ältere lokale Version ersetzt werden.
        let remote = try grouped.mapValues { try newestImage(in: $0) }
        let legacyDeletions = grouped.compactMapValues { rows in
            rows.filter(\.isTombstoned).map(\.updatedAt).max()
        }
        phase("validate-remote")
        let names = Set(local.keys).union(remote.keys).union(previous.entries.keys).union(states.keys).sorted()
        var next = previous
        var databaseChanges: [ImageVersion] = []
        var fileChanges: [FileChange] = []

        for name in names {
            try Task.checkCancellation()
            let deletedAt = [states[name]?.deletedAt, legacyDeletions[name]].compactMap { $0 }.filter { $0 > .distantPast }.max()
            let restoredAt = states[name]?.restoredAt ?? .distantPast
            let currentDeletion = deletedAt.map { $0 >= restoredAt } ?? false
            let receipt = previous.entries[name]
            let confirmedRestore = deletedAt.map { date in
                receipt.map { !$0.isDeleted && $0.updatedAt > date } ?? false
            } ?? false
            var cloud = remote[name]
            if let deletedAt {
                let staleRecord = cloud.map { $0.updatedAt <= deletedAt } ?? false
                if staleRecord || (cloud == nil && currentDeletion && !confirmedRestore) {
                    cloud = ImageVersion(filename: name, data: nil, updatedAt: deletedAt, isDeleted: true)
                }
            }
            let resolution = resolve(filename: name, local: local[name], remote: cloud, receipt: receipt,
                                     deletedAt: currentDeletion && !confirmedRestore ? deletedAt : nil)
            guard let resolution else { continue }
            let version = resolution.version
            next.entries[name] = Receipt.Entry(version)
            let duplicates = grouped[name] ?? []
            if version.isDeleted {
                if !duplicates.isEmpty || states[name]?.deletedAt != version.updatedAt {
                    databaseChanges.append(version)
                }
                if let original = local[name]?.data {
                    fileChanges.append(FileChange(filename: name, original: original, replacement: nil, deletedAt: version.updatedAt))
                }
            } else {
                if duplicates.isEmpty || !duplicates.allSatisfy({ matches($0, version) }) ||
                    (states[name]?.isDeleted == true && version.updatedAt > states[name]!.deletedAt) {
                    databaseChanges.append(version)
                }
                if local[name]?.digest != version.digest {
                    fileChanges.append(FileChange(filename: name, original: local[name]?.data, replacement: version.data))
                }
            }
        }

        let receiptChanged = next != previous
        phase("resolve")
        guard !databaseChanges.isEmpty || !fileChanges.isEmpty || receiptChanged else { return nil }
        let receiptData = try JSONEncoder().encode(next)
        // Verzeichnisse dürfen vorbereitet werden; vorhandene Fotos bleiben bis zum Save unangetastet.
        try FileManager.default.createDirectory(at: receiptsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        do {
            for version in databaseChanges {
                let duplicates = grouped[version.filename] ?? []
                if let legacyDate = legacyDeletions[version.filename] {
                    try InventoryDeletionLedger.recordDeletion(kind: "photo", key: version.filename, at: legacyDate, in: context)
                }
                if version.isDeleted {
                    try InventoryDeletionLedger.recordDeletion(kind: "photo", key: version.filename,
                                                              at: version.updatedAt, in: context)
                    for record in duplicates { context.delete(record) }
                } else {
                    if deletedBefore(version, states: states, legacyDeletions: legacyDeletions) {
                        try InventoryDeletionLedger.recordRestore(kind: "photo", key: version.filename,
                                                                 at: version.updatedAt, in: context)
                    }
                    let active = duplicates.filter { !$0.isTombstoned }
                    for record in duplicates where record.isTombstoned { context.delete(record) }
                    if active.isEmpty {
                        context.insert(StoredInventoryImage(filename: version.filename, data: version.data,
                                                            updatedAt: version.updatedAt))
                    } else {
                        // Gleichnamige aktive CloudKit-Duplikate konvergieren ohne zusätzliche Records.
                        for record in active { update(record, to: version) }
                    }
                }
            }
            if context.hasChanges { try save(context) }
        } catch {
            context.rollback()
            throw error
        }
        phase("database-save")

        // Ein Dateifehler nach dem DB-Commit erhält die alten lokalen Fotos und das alte Receipt.
        // Der nächste Abgleich kann dadurch sicher erneut versuchen, die Cloud-Version anzuwenden.
        return Reconciliation(documents: documents, receiptsURL: receiptsURL, receiptData: receiptData, receiptOriginal: receiptOriginal,
            files: fileChanges, changed: !databaseChanges.isEmpty || !fileChanges.isEmpty)
    }

    /// Alle bytegenauen Vergleiche sowie Ersatz-/Rollbackdateien werden im Hintergrund
    /// vorbereitet. Auf dem MainActor bleiben ausschließlich atomare Dateiumbenennungen.
    struct Reconciliation: Sendable {
        let documents: URL
        let receiptsURL: URL
        let receiptData: Data
        let receiptOriginal: Data?
        fileprivate let files: [FileChange]
        let changed: Bool
        var localFilesChanged: Bool { !files.isEmpty }
        var deletedPhotos: [String: Data] {
            Dictionary(uniqueKeysWithValues: files.compactMap { change in
                guard change.replacement == nil, let data = change.original else { return nil }
                return (change.filename, data)
            })
        }
        var photoDeletionDates: [String: Date] {
            Dictionary(uniqueKeysWithValues: files.compactMap { change in
                guard change.replacement == nil, let date = change.deletedAt else { return nil }
                return (change.filename, date)
            })
        }

        @MainActor
        func apply() throws -> Bool {
            // Synchroner Adapter für die bestehenden isolierten Store-Checks.
            do {
                let staged = try stageFiles()
                try staged.applySynchronously()
                return changed
            } catch InventoryPhotoFileCoordinator.Failure.changed(let name) {
                throw InventoryCloudMediaError.localPhotoChanged(name)
            }
        }

        func applyInBackground(trace: (@Sendable (InventoryCloudMediaTiming) -> Void)? = nil) async throws -> Bool {
            let preparation = Task.detached(priority: .utility) {
                try stageFiles(trace: trace)
            }
            do {
                let staged = try await withTaskCancellationHandler {
                    try await preparation.value
                } onCancel: { preparation.cancel() }
                try await staged.apply(commitTrace: { duration, isMainThread in
                    trace?(.init(phase: "file-commit", duration: duration, isMainThread: isMainThread))
                })
                return changed
            } catch InventoryPhotoFileCoordinator.Failure.changed(let name) {
                throw InventoryCloudMediaError.localPhotoChanged(name)
            }
        }

        private func stageFiles(trace: (@Sendable (InventoryCloudMediaTiming) -> Void)? = nil) throws -> InventoryPhotoTransaction {
            let started = ContinuousClock.now
            let changes = files.map {
                InventoryPhotoTransaction.Change(url: documents.appendingPathComponent($0.filename),
                    original: $0.original, replacement: $0.replacement)
            }
            let staged = try InventoryPhotoTransaction.prepare(changes,
                lastCommit: .init(url: receiptsURL, original: receiptOriginal, replacement: receiptData))
            trace?(.init(phase: "file-stage", duration: ContinuousClock.now - started, isMainThread: Thread.isMainThread))
            return staged
        }
    }

    /// Alte Backups können frei benannte Fotos enthalten. Nur reine Bild-Dateinamen sind zulässig.
    static func isValidFilename(_ name: String) -> Bool {
        guard !name.contains("/"), !name.contains("\\"), !name.contains("\0"),
              !name.hasPrefix("create_draft_"), !name.hasPrefix("create_item_draft_"),
              name == URL(fileURLWithPath: name).lastPathComponent else { return false }
        let url = URL(fileURLWithPath: name)
        let extensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tif", "tiff", "bmp"]
        guard !name.hasPrefix("."), !url.deletingPathExtension().lastPathComponent.isEmpty,
              name.utf8.count <= 255 else { return false }
        return extensions.contains(url.pathExtension.lowercased())
    }

    private static func readLocalImages(in directory: URL) throws -> [String: LocalImage] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [:] }
        let urls = try FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey])
        var result: [String: LocalImage] = [:]
        for url in urls where isValidFilename(url.lastPathComponent) {
            let properties = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey])
            guard properties.isSymbolicLink != true, properties.isRegularFile == true else {
                throw InventoryCloudMediaError.unsafeFile(url.lastPathComponent)
            }
            let data = try Data(contentsOf: url)
            try validateImage(data, filename: url.lastPathComponent)
            result[url.lastPathComponent] = LocalImage(data: data, digest: digest(data),
                modifiedAt: properties.contentModificationDate ?? Date())
        }
        return result
    }

    private static func newestImage(in records: [StoredInventoryImage]) throws -> ImageVersion {
        var versions: [ImageVersion] = []
        for record in records {
            guard isValidFilename(record.filename), record.updatedAt.timeIntervalSinceReferenceDate.isFinite else {
                throw InventoryCloudMediaError.invalidAsset(record.filename)
            }
            if !record.isTombstoned, let data = record.data {
                try validateImage(data, filename: record.filename)
            }
            versions.append(ImageVersion(filename: record.filename, data: record.isTombstoned ? nil : record.data,
                                         updatedAt: record.updatedAt, isDeleted: record.isTombstoned))
        }
        // Beim selben Zeitpunkt gewinnt eine Alt-Löschung; sonst entscheidet der Hash deterministisch.
        return versions.max {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt < $1.updatedAt }
            if $0.isDeleted != $1.isDeleted { return !$0.isDeleted }
            return ($0.digest ?? "") < ($1.digest ?? "")
        }!
    }

    private static func deletedBefore(_ version: ImageVersion, states: [String: InventoryDeletionLedger.State],
                                      legacyDeletions: [String: Date]) -> Bool {
        let prior = [states[version.filename]?.deletedAt, legacyDeletions[version.filename]].compactMap { $0 }.max()
        return prior.map { version.updatedAt > $0 } ?? false
    }

    private static func resolve(filename: String, local: LocalImage?, remote: ImageVersion?, receipt: Receipt.Entry?,
                                deletedAt: Date?) -> Resolution? {
        guard let local else {
            // Ein hier schon bekanntes, verschwundenes Foto ist lokal gelöscht, kein Download-Auftrag.
            if let receipt, !receipt.isDeleted {
                if let remote, remote.isDeleted, remote.updatedAt >= receipt.updatedAt { return Resolution(remote) }
                return Resolution(ImageVersion(filename: filename, data: nil,
                    updatedAt: nextDate(after: [receipt.updatedAt, remote?.updatedAt, deletedAt].compactMap { $0 }), isDeleted: true))
            }
            if let receipt, receipt.isDeleted {
                if let remote, remote.updatedAt > receipt.updatedAt {
                    return remote.isAvailable ? Resolution(remote) : nil
                }
                return Resolution(ImageVersion(filename: filename, data: nil, updatedAt: receipt.updatedAt, isDeleted: true))
            }
            return remote.flatMap { $0.isAvailable ? Resolution($0) : nil }
        }

        // Ein bestätigter Löschauftrag darf bei einem Dateifehler keine automatische
        // Wiederherstellung auslösen. Nur eine tatsächlich danach geschriebene Datei darf zurückkehren.
        if let deletedAt, local.modifiedAt <= deletedAt, (receipt?.digest == local.digest || receipt == nil || receipt?.isDeleted == true) {
            if let remote, !remote.isDeleted, remote.updatedAt > deletedAt {
                return remote.isAvailable ? Resolution(remote) : nil
            }
            return Resolution(ImageVersion(filename: filename, data: nil, updatedAt: deletedAt, isDeleted: true))
        }
        if let remote, !remote.isAvailable { return nil }
        if let remote, !remote.isDeleted, local.digest == remote.digest {
            let updatedAt = receipt?.isDeleted == true
                ? nextDate(after: [remote.updatedAt, receipt!.updatedAt], proposed: local.modifiedAt)
                : max(remote.updatedAt, receipt?.updatedAt ?? .distantPast)
            return Resolution(ImageVersion(filename: filename, data: local.data,
                updatedAt: updatedAt, isDeleted: false))
        }
        let localChanged = receipt == nil || receipt?.digest != local.digest || receipt?.isDeleted == true
        if !localChanged {
            guard let remote else {
                // Ein importierter Löschmarker kann nach der nativen Record-Löschung
                // eintreffen. Den bekannten unveränderten Inhalt dann nicht erneut hochladen.
                return nil
            }
            if remote.updatedAt >= receipt!.updatedAt { return Resolution(remote) }
            return Resolution(ImageVersion(filename: filename, data: local.data, updatedAt: receipt!.updatedAt, isDeleted: false))
        }
        let localDate = max(local.modifiedAt, receipt?.updatedAt.addingTimeInterval(0.001) ?? .distantPast)
        if let remote, remote.updatedAt > (receipt?.updatedAt ?? .distantPast), remote.updatedAt >= localDate {
            return Resolution(remote)
        }
        return Resolution(ImageVersion(filename: filename, data: local.data,
            updatedAt: nextDate(after: [receipt?.updatedAt, remote?.updatedAt, deletedAt].compactMap { $0 }, proposed: localDate), isDeleted: false))
    }

    private static func nextDate(after previous: [Date], proposed: Date = Date()) -> Date {
        max(proposed, (previous.max() ?? .distantPast).addingTimeInterval(0.001))
    }

    private static func matches(_ record: StoredInventoryImage, _ version: ImageVersion) -> Bool {
        record.isTombstoned == version.isDeleted && record.updatedAt == version.updatedAt && record.data == version.data
    }

    private static func update(_ record: StoredInventoryImage, to version: ImageVersion) {
        guard !matches(record, version) else { return }
        record.data = version.data
        record.updatedAt = version.updatedAt
        record.isTombstoned = version.isDeleted
    }

    private static func validateImage(_ data: Data, filename: String) throws {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0,
              CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1
              ] as CFDictionary) != nil else {
            throw InventoryCloudMediaError.invalidImage(filename)
        }
    }

    nonisolated private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func readReceipt(at url: URL) throws -> Receipt {
        guard FileManager.default.fileExists(atPath: url.path) else { return Receipt() }
        let receipt: Receipt
        do { receipt = try JSONDecoder().decode(Receipt.self, from: Data(contentsOf: url)) }
        catch { throw InventoryCloudMediaError.invalidReceipt }
        guard receipt.version == 1, receipt.entries.allSatisfy({
            isValidFilename($0.key) && $0.value.updatedAt.timeIntervalSinceReferenceDate.isFinite &&
            ($0.value.isDeleted ? $0.value.digest == nil : $0.value.digest?.count == 64)
        }) else { throw InventoryCloudMediaError.invalidReceipt }
        return receipt
    }

    private struct LocalImage {
        let data: Data
        let digest: String
        let modifiedAt: Date
    }

    private struct ImageVersion {
        let filename: String
        let data: Data?
        let updatedAt: Date
        let isDeleted: Bool
        var digest: String? { data.map(InventoryCloudMediaStore.digest) }
        var isAvailable: Bool { isDeleted || data != nil }
    }

    private struct Resolution {
        let version: ImageVersion
        init(_ version: ImageVersion) { self.version = version }
    }

    fileprivate struct FileChange: Sendable {
        let filename: String
        let original: Data?
        let replacement: Data?
        var deletedAt: Date? = nil
    }

    private struct Receipt: Codable, Equatable {
        var version = 1
        var entries: [String: Entry] = [:]

        struct Entry: Codable, Equatable {
            let digest: String?
            let updatedAt: Date
            let isDeleted: Bool

            init(_ version: ImageVersion) {
                digest = version.digest
                updatedAt = version.updatedAt
                isDeleted = version.isDeleted
            }
        }
    }
}

enum InventoryCloudMediaError: LocalizedError {
    case invalidAsset(String)
    case invalidImage(String)
    case unsafeFile(String)
    case invalidReceipt
    case localPhotoChanged(String)

    var errorDescription: String? {
        switch self {
        case .invalidAsset(let name): return "Ein iCloud-Foto hat einen ungültigen Dateinamen (\(name)). Die lokalen Fotos bleiben erhalten."
        case .invalidImage(let name): return "Das Foto \(name) konnte nicht gelesen werden. Die lokalen Fotos bleiben erhalten."
        case .unsafeFile(let name): return "Das Foto \(name) liegt nicht als reguläre lokale Bilddatei vor."
        case .localPhotoChanged(let name): return "Das Foto \(name) wurde während des Abgleichs lokal geändert. Der Abgleich kann erneut versucht werden."
        case .invalidReceipt: return "Der lokale iCloud-Fotoabgleich konnte nicht gelesen werden. Die lokalen Fotos bleiben erhalten."
        }
    }
}

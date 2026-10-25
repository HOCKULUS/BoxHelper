import CryptoKit
import Foundation
import ImageIO

/// Reine Wertkopien für den Freigabeabgleich. JSON, Bildprüfung und Hashing laufen
/// in einem detached Task; weder SwiftData-Contexts noch UI-Zustand verlassen ihren Actor.
enum InventorySharingPreparation {
    struct Merge: Sendable {
        let after: InventorySnapshot
        let affected: Set<String>
        let records: [String: InventorySharedRecord]
        let downloads: [String]
        let photoVersions: [PhotoVersion]
        let photoDeletions: [InventorySharingPhotoCleanup.Candidate]
    }

    struct PhotoVersion: Sendable {
        let filename: String
        let digest: String?
    }

    static func prepare(before: InventorySnapshot, descriptor: InventoryShareDescriptor,
                        baseline: [String: InventorySharedRecord], newIDs: Set<String>,
                        otherIDs: Set<String>, remote: [String: InventorySharedRecord],
                        documents: URL) throws -> Merge {
        let known = Set(remote.keys).union(baseline.keys)
        var selection = descriptor.scope.select(from: before, isOwner: descriptor.isOwner,
                                                knownIDs: known, newIDs: newIDs)
        if descriptor.isOwner && descriptor.scope.kind == .inventory {
            // Angenommene Daten einer anderen Freigabe behalten ihren Ursprung.
            selection.boxes.removeAll { otherIDs.contains("box-\($0.id)") }
            selection.items.removeAll { otherIDs.contains("item-\($0.id)") }
            selection.locations.removeAll { otherIDs.contains("location-\($0.id)") }
        }
        if !descriptor.scope.sharesImages { selection = InventoryShareImages.removing(from: selection) }
        let local = try InventoryShareMerge.records(selection)
        let objectNames = known.union(local.keys).filter {
            $0.hasPrefix("box-") || $0.hasPrefix("item-") || $0.hasPrefix("location-")
        }
        guard objectNames.isDisjoint(with: otherIDs) else { throw InventorySharingError.overlappingShare }
        let excluded = InventoryShareMerge.identifiers(in: before).subtracting(local.keys).intersection(known)
        var merged: [String: InventorySharedRecord] = [:]
        for name in objectNames {
            let value = descriptor.canEdit
                ? try InventoryShareMerge.merge(base: baseline[name], local: local[name], remote: remote[name])
                : remote[name]
            if let value { merged[name] = value }
        }
        // Auch ein altes oder erst verspätet eingetroffenes Kind darf eine bereits
        // gelöschte Kiste nicht wieder mit sichtbarem Inhalt verknüpfen.
        merged = try InventoryShareMerge.repairDeletedParents(in: merged)
        var after = try InventoryShareMerge.apply(Array(merged.values), to: before, preserving: excluded)
        if descriptor.isOwner && !descriptor.scope.sharesImages {
            after = InventoryShareImages.restoring(in: after, from: before)
        }
        let shared = try InventoryShareMerge.apply(Array(merged.values), to: .empty, preserving: [])
        let references = InventoryShareMerge.photos(in: shared)
        let localReferences = InventoryShareMerge.photos(in: selection)
        var photos: [String: Data] = [:]
        var photoVersions: [PhotoVersion] = []
        for name in references.sorted() {
            let url = try photoURL(name, documents: documents)
            let key = "photo-" + digest(Data(name.utf8))
            let server = remote[key]
            if let server, server.filename != name || server.kind != "photo" { throw InventorySharingError.invalidData }
            let bytes = try? Data(contentsOf: url)
            photos[name] = bytes
            let localDigest = bytes.map(digest)
            photoVersions.append(.init(filename: name, digest: localDigest))
            let hash = localDigest.map { Data($0.utf8) }
            if let server, !server.isDeleted,
               !descriptor.canEdit || hash == nil || hash == baseline[key]?.body || hash == server.body {
                merged[key] = server
            } else if let bytes, let hash, descriptor.canEdit, localReferences.contains(name) {
                // Fremde Bildreferenzen dürfen keine gleichnamigen privaten Fotos veröffentlichen.
                guard CGImageSourceCreateWithData(bytes as CFData, nil) != nil else { throw InventorySharingError.invalidData }
                merged[key] = InventorySharedRecord(name: key, kind: "photo", body: hash, photo: bytes, filename: name,
                    changedAt: max(Date(), (server?.changedAt ?? .distantPast).addingTimeInterval(0.001)),
                    systemFields: server?.systemFields)
            } else { throw InventoryDraftError.missingPhoto(name) }
        }
        for (key, var record) in remote where record.kind == "photo" && !references.contains(record.filename ?? "") {
            // Bereits bestätigte Server-Tombstones gehören ebenfalls in die Baseline.
            // Sonst hält ein Empfänger die alte aktive Fotoversion dauerhaft fest.
            if record.isDeleted { merged[key] = record }
            else if descriptor.canEdit {
                record.isDeleted = true; record.photo = nil; record.body = nil
                record.changedAt = max(Date(), record.changedAt.addingTimeInterval(0.001))
                merged[key] = record
            }
        }
        // Auch Leser entfernen Fotos eines gelöschten Elternobjekts, wenn ein alter
        // schreibender Client dessen Asset noch aktiv gelassen hat. Sie verändern den
        // Server dabei nicht; die bekannte Baseline beweist die lokale Dateiversion.
        let previousPhotos = baseline.merging(remote) { _, latest in latest }
        let photoDeletions = previousPhotos.values.compactMap { record -> InventorySharingPhotoCleanup.Candidate? in
            guard record.kind == "photo", let filename = record.filename, !references.contains(filename) else { return nil }
            let previous = baseline[record.name].flatMap { $0.isDeleted ? nil : $0 }
                ?? (descriptor.canEdit ? remote[record.name].flatMap { $0.isDeleted ? nil : $0 } : nil)
            guard previous?.filename == filename, let body = previous?.body,
                  let hash = String(data: body, encoding: .utf8), hash.count == 64,
                  hash.allSatisfy({ $0.isHexDigit }) else { return nil }
            return .init(filename: filename, digest: hash)
        }.sorted { $0.filename < $1.filename }
        var downloads: [String] = []
        for (key, value) in merged where value.kind == "photo" && !value.isDeleted && value.photo == nil {
            guard let name = value.filename else { throw InventorySharingError.invalidData }
            let localBytes = photos[name]
            if localBytes.map({ Data(digest($0).utf8) }) != value.body {
                if let localBytes, !localReferences.contains(name),
                   baseline[key]?.body != Data(digest(localBytes).utf8) { throw InventorySharingError.invalidData }
                downloads.append(key)
            }
        }
        // Ein bestätigter Serverstand umfasst die gesamte Freigabe. Der lokale Inbox-
        // Commit braucht dagegen nur tatsächlich neue, geänderte oder entfernte UUIDs.
        // Unveränderte Kisten/Items erzeugen dadurch keinen vollständigen SQLite-Fetch.
        let affected = changedNames(from: before, to: after).intersection(Set(objectNames).subtracting(excluded))
        return Merge(after: after, affected: affected,
                     records: merged, downloads: downloads.sorted(), photoVersions: photoVersions,
                     photoDeletions: photoDeletions)
    }

    private static func changedNames(from before: InventorySnapshot, to after: InventorySnapshot) -> Set<String> {
        changedNames(before.boxes, after.boxes, prefix: "box")
            .union(changedNames(before.items, after.items, prefix: "item"))
            .union(changedNames(before.locations, after.locations, prefix: "location"))
    }

    private static func changedNames<Value: Identifiable & Equatable>(_ before: [Value], _ after: [Value],
                                                                     prefix: String) -> Set<String> where Value.ID == UUID {
        // Die DB liefert deduplizierte UUIDs. Der letzte Wert gewinnt auch für alte
        // Austauschbestände deterministisch, ebenso wie bei InventoryShareMerge.records.
        let old = Dictionary(before.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        let new = Dictionary(after.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        return Set(old.keys).union(new.keys).reduce(into: Set<String>()) { names, id in
            if old[id] != new[id] { names.insert("\(prefix)-\(id)") }
        }
    }

    struct PhotoChanges: Sendable {
        struct Replacement: Sendable {
            let url: URL
            let original: Data?
            let bytes: Data
        }
        let replacements: [Replacement]

        /// Der produktive Abgleich liest und staged Fotos auf dem Worker. Auf dem
        /// MainActor bleiben nur geschützte Renames, zwischen Dateien bleibt UI-Zeit.
        func applyInBackground() async throws -> Bool {
            let changes = replacements.map { InventoryPhotoTransaction.Change(url: $0.url, original: $0.original, replacement: $0.bytes) }
            let worker = Task.detached(priority: .utility) { try InventoryPhotoTransaction.prepare(changes) }
            do {
                let transaction = try await withTaskCancellationHandler(operation: { try await worker.value },
                                                                          onCancel: { worker.cancel() })
                try await transaction.apply()
                return !replacements.isEmpty
            } catch InventoryPhotoFileCoordinator.Failure.changed {
                throw InventorySharingError.conflict
            }
        }

        /// Synchroner Adapter für die bisherigen isolierten Prüfungen; der produktive
        /// Sharing-Service verwendet ausschließlich applyInBackground().
        @MainActor
        func apply() throws -> Bool {
            do {
                let changes = replacements.map { InventoryPhotoTransaction.Change(url: $0.url, original: $0.original, replacement: $0.bytes) }
                try InventoryPhotoTransaction.prepare(changes).applySynchronously()
                return !replacements.isEmpty
            } catch InventoryPhotoFileCoordinator.Failure.changed {
                throw InventorySharingError.conflict
            }
        }
    }

    static func preparePhotos(_ records: [InventorySharedRecord], documents: URL,
                              expected: [PhotoVersion] = []) throws -> PhotoChanges {
        // Auch Änderungen während der Netzwerkantwort werden geschützt. Die bloße
        // Inventarrevision erfasst eine einzeln ersetzte Fotodatei noch nicht immer.
        for version in expected {
            let url = try photoURL(version.filename, documents: documents)
            let current = try? Data(contentsOf: url)
            guard current.map(digest) == version.digest else { throw InventorySharingError.conflict }
        }
        var replacements: [PhotoChanges.Replacement] = []
        for record in records where record.kind == "photo" && !record.isDeleted {
            guard let name = record.filename else { throw InventorySharingError.invalidData }
            let url = try photoURL(name, documents: documents)
            let local = try? Data(contentsOf: url)
            if let hash = record.body, let local, Data(digest(local).utf8) == hash { continue }
            guard let bytes = record.photo, CGImageSourceCreateWithData(bytes as CFData, nil) != nil,
                  record.body == Data(digest(bytes).utf8) else { throw InventorySharingError.invalidData }
            replacements.append(.init(url: url, original: local, bytes: bytes))
        }
        return PhotoChanges(replacements: replacements)
    }

    static func photoURL(_ name: String, documents: URL) throws -> URL {
        guard !name.isEmpty, name != ".", name != "..", name == URL(fileURLWithPath: name).lastPathComponent,
              !name.hasPrefix("create_draft_"), !name.hasPrefix("create_item_draft_") else { throw InventorySharingError.invalidData }
        let url = documents.appendingPathComponent(name)
        guard url.resolvingSymlinksInPath().deletingLastPathComponent() == documents.resolvingSymlinksInPath() else {
            throw InventorySharingError.invalidData
        }
        return url
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

import CryptoKit
import Foundation
import SwiftData

/// Dateinamen sind unveränderliche Foto-IDs. Nur neue Referenzen lesen Bilddateien;
/// reine Textänderungen fassen vorhandene Assets und ihre Versionen nicht an.
@MainActor
enum InventoryDraftMedia {
    static func save(names: Set<String>, draftID: UUID, version: Date, context: ModelContext,
                     url: (String) throws -> URL) throws {
        let rows = try context.fetch(FetchDescriptor<StoredDraftPhoto>(predicate: #Predicate { $0.draftID == draftID }))
        let current = winners(rows)
        let keys = Set(rows.map { InventoryDeletionLedger.draftPhotoKey(draftID, filename: $0.filename) })
            .union(names.map { InventoryDeletionLedger.draftPhotoKey(draftID, filename: $0) })
        let states = try InventoryDeletionLedger.states(in: context, kind: "draft-photo", keys: Array(keys))
        for name in names.sorted() {
            let key = InventoryDeletionLedger.draftPhotoKey(draftID, filename: name)
            if !isDeleted(current[name], state: states[key]), let record = current[name], !record.isTombstoned,
               !record.digest.isEmpty { continue }
            guard let data = try? Data(contentsOf: url(name)) else { throw InventoryDraftError.missingPhoto(name) }
            let digest = hash(data)
            let photoVersion = InventoryDeletionLedger.nextVersion(after: [current[name]?.updatedAt ?? .distantPast,
                                                                           states[key]?.revision ?? .distantPast], proposed: version)
            // Das erneute Hinzufügen eines entfernten Fotos ist eine ausdrückliche
            // lokale Änderung; verspätete Cloud-Kopien können es nicht allein zurückholen.
            try InventoryDeletionLedger.recordRestore(kind: "draft-photo", key: key, at: photoVersion, in: context)
            context.insert(StoredDraftPhoto(draftID: draftID, filename: name, data: data, digest: digest, updatedAt: photoVersion))
        }
        for record in rows where !names.contains(record.filename) {
            let key = InventoryDeletionLedger.draftPhotoKey(draftID, filename: record.filename)
            let photoVersion = InventoryDeletionLedger.nextVersion(after: [record.updatedAt, states[key]?.revision ?? .distantPast], proposed: version)
            try InventoryDeletionLedger.recordDeletion(kind: "draft-photo", key: key, at: photoVersion, in: context)
            context.delete(record)
        }
    }

    static func materialize(names: [String], draftID: UUID, context: ModelContext,
                            url: (String) throws -> URL) throws {
        let records = winners(try context.fetch(FetchDescriptor<StoredDraftPhoto>(predicate: #Predicate { $0.draftID == draftID })))
        let states = try InventoryDeletionLedger.states(in: context, kind: "draft-photo",
            keys: names.map { InventoryDeletionLedger.draftPhotoKey(draftID, filename: $0) })
        // Alle Fotos vor dem ersten Schreibzugriff prüfen. Ein zeitversetzter Cloud-Import
        // darf niemals ein halbes Formular öffnen oder den bisherigen Entwurf ersetzen.
        let files = try names.map { name -> (URL, Data) in
            let key = InventoryDeletionLedger.draftPhotoKey(draftID, filename: name)
            guard !isDeleted(records[name], state: states[key]), let record = records[name], !record.isTombstoned, let data = record.data,
                  hash(data) == record.digest else { throw InventoryDraftError.missingPhoto(name) }
            return (try url(name), data)
        }
        for (file, data) in files {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            if (try? Data(contentsOf: file)) != data { try data.write(to: file, options: .atomic) }
        }
    }

    static func delete(draftID: UUID, version: Date, context: ModelContext) throws {
        for record in try context.fetch(FetchDescriptor<StoredDraftPhoto>(predicate: #Predicate { $0.draftID == draftID })) {
            let key = InventoryDeletionLedger.draftPhotoKey(draftID, filename: record.filename)
            try InventoryDeletionLedger.recordDeletion(kind: "draft-photo", key: key,
                at: max(version, record.updatedAt.addingTimeInterval(0.001)), in: context)
            context.delete(record)
        }
    }

    private static func winners(_ records: [StoredDraftPhoto]) -> [String: StoredDraftPhoto] {
        var result: [String: StoredDraftPhoto] = [:]
        for record in records {
            if let old = result[record.filename], old.updatedAt > record.updatedAt
                || (old.updatedAt == record.updatedAt && (old.isTombstoned || old.digest > record.digest)) { continue }
            result[record.filename] = record
        }
        return result
    }

    /// Ein ausdrücklich erneut angefügtes Foto darf vor seiner Restore-Historie
    /// eintreffen. Seine neuere Asset-Version unterscheidet es von alten Cloud-Kopien.
    private static func isDeleted(_ record: StoredDraftPhoto?, state: InventoryDeletionLedger.State?) -> Bool {
        guard let state, state.deletedAt > .distantPast else { return false }
        return record.map { $0.updatedAt <= state.deletedAt } ?? true
    }
    private static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}

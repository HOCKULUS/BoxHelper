import CloudKit
import Foundation

/// Der Transport ist austauschbar, damit Zwei-Nutzer-, Offline- und Konflikttests
/// weder einen Account noch echte Einladungen benötigen.
@MainActor
protocol InventorySharingBackend {
    func accountID() async throws -> String
    func discover() async throws -> [InventoryShareDescriptor]
    func create(title: String, scope: InventoryShareScope) async throws -> InventoryShareDescriptor
    func fetch(_ descriptor: InventoryShareDescriptor) async throws -> [InventorySharedRecord]
    func photo(named: String, in descriptor: InventoryShareDescriptor) async throws -> InventorySharedRecord
    func save(_ records: [InventorySharedRecord], in descriptor: InventoryShareDescriptor) async throws -> [InventorySharedRecord]
    func share(_ descriptor: InventoryShareDescriptor) async throws -> CKShare
    func publishShare(_ descriptor: InventoryShareDescriptor) async throws -> CKShare
    func end(_ descriptor: InventoryShareDescriptor) async throws
    func accept(_ metadata: CKShare.Metadata) async throws
    func subscribe() async throws
}

extension InventorySharingBackend {
    func publishShare(_ descriptor: InventoryShareDescriptor) async throws -> CKShare { try await share(descriptor) }
}

/// SwiftData übernimmt den privaten Sync. Zusammenarbeit verwendet eigene CloudKit-
/// Zonen und die Shared Database; der interne SwiftData-Store wird niemals angefasst.
@MainActor
final class InventorySharingCloudBackend: InventorySharingBackend {
    static let zonePrefix = "BoxHelperShared-"
    let container: CKContainer

    init() throws {
        // CKContainer darf in unsignierten Simulator-/Test-Builds nicht konstruiert werden.
        guard CloudSyncPreferences.supportsCloudKit else { throw InventoryCloudSyncError.unsupportedBuild }
        container = CKContainer(identifier: CloudSyncPreferences.containerIdentifier)
    }

    func accountID() async throws -> String { try await container.userRecordID().recordName }

    func discover() async throws -> [InventoryShareDescriptor] {
        var result: [InventoryShareDescriptor] = []
        for isOwner in [true, false] {
            let database = isOwner ? container.privateCloudDatabase : container.sharedCloudDatabase
            for zone in try await database.allRecordZones() where zone.zoneID.zoneName.hasPrefix(Self.zonePrefix) {
                let id = CKRecord.ID(recordName: "scope", zoneID: zone.zoneID)
                // Nach Abbruch beim Anlegen darf eine noch nicht veröffentlichte Zone existieren.
                let record: CKRecord
                do { record = try await database.record(for: id) }
                catch let error as CKError where error.code == .unknownItem { continue }
                guard let body = record["body"] as? Data else { throw InventorySharingError.invalidData }
                let manifest = try JSONDecoder().decode(Manifest.self, from: body)
                let share: CKShare
                do {
                    guard let value = try await database.record(for: CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zone.zoneID)) as? CKShare else { throw InventorySharingError.invalidData }
                    share = value
                }
                catch let error as CKError where error.code == .unknownItem { continue }
                result.append(InventoryShareDescriptor(zoneName: zone.zoneID.zoneName, ownerName: zone.zoneID.ownerName,
                                                      isOwner: isOwner, title: manifest.title, scope: manifest.scope,
                                                      canEdit: isOwner || share.currentUserParticipant?.permission == .readWrite,
                                                      participants: share.participants.filter { $0.role != .owner }.map {
                    InventoryShareParticipant(name: $0.userIdentity.nameComponents.map {
                        PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
                    } ?? "Teilnehmer", accepted: $0.acceptanceStatus == .accepted, canEdit: $0.permission == .readWrite)
                }))
            }
        }
        return result
    }

    func create(title: String, scope: InventoryShareScope) async throws -> InventoryShareDescriptor {
        let zone = CKRecordZone(zoneName: Self.zonePrefix + UUID().uuidString)
        _ = try await container.privateCloudDatabase.save(zone)
        let descriptor = InventoryShareDescriptor(zoneName: zone.zoneID.zoneName, ownerName: zone.zoneID.ownerName,
                                                  isOwner: true, title: title, scope: scope, canEdit: true)
        let manifest = InventorySharedRecord(name: "scope", kind: "scope", body: try InventoryShareMerge.encode(Manifest(title: title, scope: scope)))
        _ = try await save([manifest], in: descriptor)
        return descriptor
    }

    func fetch(_ descriptor: InventoryShareDescriptor) async throws -> [InventorySharedRecord] {
        var token: CKServerChangeToken?
        var records: [String: InventorySharedRecord] = [:]
        repeat {
            // Ohne Query und Index-Annahmen; bei großen Zonen werden alle Seiten gelesen.
            let page = try await database(descriptor).recordZoneChanges(
                inZoneWith: zoneID(descriptor), since: token,
                desiredKeys: ["kind", "body", "filename", "deleted", "changedAt"])
            for modification in page.modificationResultsByID.values {
                let record = try modification.get().record
                guard record.recordType == "BoxHelperCollaborationRecord" else { continue }
                let value = try decode(record)
                records[value.name] = value
            }
            for deletion in page.deletions { records.removeValue(forKey: deletion.recordID.recordName) }
            token = page.changeToken
            if !page.moreComing { break }
        } while true
        return records.values.sorted { $0.name < $1.name }
    }

    func photo(named: String, in descriptor: InventoryShareDescriptor) async throws -> InventorySharedRecord {
        try decode(await database(descriptor).record(for: CKRecord.ID(recordName: named, zoneID: zoneID(descriptor))))
    }

    func save(_ records: [InventorySharedRecord], in descriptor: InventoryShareDescriptor) async throws -> [InventorySharedRecord] {
        guard descriptor.canEdit else { throw InventorySharingError.readOnly }
        var result: [InventorySharedRecord] = []
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("BoxHelperShareAssets-\(UUID())")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        // CloudKit begrenzt die Zahl der Datensätze je Operation. Bestätigte Teilbatches
        // sind idempotent; der Client bestätigt seinen Ausgangsstand erst am Schluss.
        for offset in stride(from: 0, to: records.count, by: 100) {
            let batch = Array(records[offset..<min(offset + 100, records.count)])
            let values = try batch.map { try encode($0, zoneID: zoneID(descriptor), temporary: temporary) }
            let response = try await database(descriptor).modifyRecords(saving: values, deleting: [],
                                                                        savePolicy: .ifServerRecordUnchanged, atomically: true)
            for value in values {
                guard let saved = response.saveResults[value.recordID] else { throw InventorySharingError.invalidData }
                result.append(try decode(saved.get()))
            }
        }
        return result
    }

    func share(_ descriptor: InventoryShareDescriptor) async throws -> CKShare {
        try await loadShare(descriptor, createIfMissing: false)
    }

    func publishShare(_ descriptor: InventoryShareDescriptor) async throws -> CKShare {
        try await loadShare(descriptor, createIfMissing: true)
    }

    /// Nur die Erstveröffentlichung darf CKShare anlegen. Ein Widerruf auf einem
    /// anderen Gerät darf durch einen veralteten Verwaltungsdialog nie rückgängig werden.
    private func loadShare(_ descriptor: InventoryShareDescriptor, createIfMissing: Bool) async throws -> CKShare {
        let id = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID(descriptor))
        do {
            guard let share = try await database(descriptor).record(for: id) as? CKShare else { throw InventorySharingError.invalidData }
            return share
        } catch let error as CKError where error.code == .unknownItem && descriptor.isOwner && createIfMissing {
            let share = CKShare(recordZoneID: zoneID(descriptor))
            share.publicPermission = .none
            share[CKShare.SystemFieldKey.title] = descriptor.title as CKRecordValue
            guard let saved = try await container.privateCloudDatabase.save(share) as? CKShare else { throw InventorySharingError.invalidData }
            return saved
        }
    }

    /// In der privaten DB widerruft dies die Freigabe; in der Shared DB verlässt
    /// nur der aktuelle Teilnehmer die Freigabe. Inventar und private Fotos bleiben erhalten.
    func end(_ descriptor: InventoryShareDescriptor) async throws {
        let id = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID(descriptor))
        do { _ = try await database(descriptor).deleteRecord(withID: id) }
        catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound { }
    }

    func accept(_ metadata: CKShare.Metadata) async throws {
        guard metadata.containerIdentifier == CloudSyncPreferences.containerIdentifier,
              metadata.share.recordID.zoneID.zoneName.hasPrefix(Self.zonePrefix) else { throw InventorySharingError.invalidData }
        _ = try await container.accept(metadata)
    }

    func subscribe() async throws {
        for (database, id) in [(container.privateCloudDatabase, "BoxHelperCollaborationPrivate"),
                               (container.sharedCloudDatabase, "BoxHelperCollaborationShared")] {
            let subscription = CKDatabaseSubscription(subscriptionID: id)
            let info = CKSubscription.NotificationInfo(); info.shouldSendContentAvailable = true
            subscription.notificationInfo = info
            _ = try await database.save(subscription)
        }
    }

    private struct Manifest: Codable { var title: String; var scope: InventoryShareScope }
    private func zoneID(_ value: InventoryShareDescriptor) -> CKRecordZone.ID { CKRecordZone.ID(zoneName: value.zoneName, ownerName: value.ownerName) }
    private func database(_ value: InventoryShareDescriptor) -> CKDatabase { value.isOwner ? container.privateCloudDatabase : container.sharedCloudDatabase }

    private func encode(_ value: InventorySharedRecord, zoneID: CKRecordZone.ID, temporary: URL) throws -> CKRecord {
        let record: CKRecord
        if let fields = value.systemFields {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: fields); unarchiver.requiresSecureCoding = true
            defer { unarchiver.finishDecoding() }
            guard let restored = CKRecord(coder: unarchiver), restored.recordID.zoneID == zoneID,
                  restored.recordID.recordName == value.name else { throw InventorySharingError.invalidData }
            record = restored
        } else { record = CKRecord(recordType: "BoxHelperCollaborationRecord", recordID: CKRecord.ID(recordName: value.name, zoneID: zoneID)) }
        record["kind"] = value.kind as CKRecordValue
        record["body"] = value.body as CKRecordValue?
        record["filename"] = value.filename as CKRecordValue?
        record["deleted"] = NSNumber(value: value.isDeleted)
        record["changedAt"] = value.changedAt as CKRecordValue
        if let data = value.photo, !value.isDeleted {
            let url = temporary.appendingPathComponent(UUID().uuidString)
            try data.write(to: url, options: .atomic); record["asset"] = CKAsset(fileURL: url)
        } else { record["asset"] = nil }
        return record
    }

    private func decode(_ record: CKRecord) throws -> InventorySharedRecord {
        guard let kind = record["kind"] as? String,
              ["scope", "box", "item", "location", "photo"].contains(kind),
              let changedAt = record["changedAt"] as? Date else { throw InventorySharingError.invalidData }
        let deleted = (record["deleted"] as? NSNumber)?.boolValue ?? false
        var photo: Data?
        if kind == "photo", !deleted, let asset = record["asset"] as? CKAsset {
            guard let url = asset.fileURL else { throw InventorySharingError.invalidData }
            photo = try Data(contentsOf: url)
        }
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver); archiver.finishEncoding()
        return InventorySharedRecord(name: record.recordID.recordName, kind: kind, body: record["body"] as? Data,
                                     photo: photo, filename: record["filename"] as? String, isDeleted: deleted,
                                     changedAt: changedAt, systemFields: archiver.encodedData)
    }
}

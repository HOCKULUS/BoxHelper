import CloudKit
import Foundation

/// Die eigene Record-Art benötigt auch dann ein Asset-Feld, wenn die ersten
/// Entwicklungsfreigaben noch keine Fotos enthalten. Nur das explizite Debugargument
/// legt dafür einen synthetischen Datensatz an; die temporäre Zone wird wieder gelöscht.
@MainActor
enum InventorySharingDevelopmentSchema {
    private static var started = false

    static func initializeIfRequested() {
        #if DEBUG
        guard !started, CloudSyncPreferences.supportsCloudKit,
              ProcessInfo.processInfo.arguments.contains("-InitializeInventoryCloudKitSchema") else { return }
        started = true
        Task {
            do { try await initialize() }
            catch { InventoryCloudSyncState.shared.recordCollaborationError(error) }
        }
        #endif
    }

    #if DEBUG
    private static func initialize() async throws {
        let database = CKContainer(identifier: CloudSyncPreferences.containerIdentifier).privateCloudDatabase
        // Der Präfix unterscheidet sich bewusst von echten Freigaben.
        let zone = CKRecordZone(zoneName: "BoxHelperSchemaDevelopment-\(UUID())")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("BoxHelperSchema-\(UUID()).png")
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a3V8AAAAASUVORK5CYII=")!
        try png.write(to: file, options: .atomic)
        defer { try? FileManager.default.removeItem(at: file) }
        _ = try await database.save(zone)
        do {
            let record = CKRecord(recordType: "BoxHelperCollaborationRecord",
                                  recordID: CKRecord.ID(recordName: "schema", zoneID: zone.zoneID))
            record["kind"] = "photo" as CKRecordValue
            record["body"] = Data([0]) as CKRecordValue
            record["filename"] = "schema.png" as CKRecordValue
            record["deleted"] = NSNumber(value: false)
            record["changedAt"] = Date() as CKRecordValue
            record["asset"] = CKAsset(fileURL: file)
            _ = try await database.save(record)
        } catch {
            _ = try? await database.deleteRecordZone(withID: zone.zoneID)
            throw error
        }
        _ = try await database.deleteRecordZone(withID: zone.zoneID)
    }
    #endif
}

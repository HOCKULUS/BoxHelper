import CloudKit
import Foundation

/// Austauschbarer Transport: Tests löschen ausschließlich künstliche Zonen.
@MainActor
protocol InventoryCloudDeletionBackend {
    func privateZones() async throws -> [CKRecordZone.ID]
    func sharedZones() async throws -> [CKRecordZone.ID]
    func deletePrivateZone(_ id: CKRecordZone.ID) async throws
    func leaveSharedZone(_ id: CKRecordZone.ID) async throws
}

enum InventoryCloudDeletion {
    @MainActor
    static func deleteAll() async throws {
        try await InventoryCloudSyncState.shared.deleteCloudData {
            guard CloudSyncPreferences.supportsCloudKit else { throw InventoryCloudSyncError.unsupportedBuild }
            let container = CKContainer(identifier: CloudSyncPreferences.containerIdentifier)
            guard try await container.accountStatus() == .available else { throw InventoryCloudSyncError.noAccount }
            try await deleteAll(using: CloudBackend(container: container))
        }
    }

    @MainActor
    static func deleteAll(using backend: any InventoryCloudDeletionBackend) async throws {
        // Beide Listen vor dem ersten Löschen laden. Die Standardzone enthält keine
        // BoxHelper-Daten; Inventar und persönliche Zusatzdaten liegen in SwiftData-Zonen.
        let privateZones = try await backend.privateZones()
        let sharedZones = try await backend.sharedZones()
        for zone in sharedZones where zone.zoneName.hasPrefix("BoxHelperShared-") {
            try await backend.leaveSharedZone(zone)
        }
        for zone in privateZones where zone != CKRecordZone.default().zoneID {
            try await backend.deletePrivateZone(zone)
        }
    }

    @MainActor
    private struct CloudBackend: InventoryCloudDeletionBackend {
        let container: CKContainer

        func privateZones() async throws -> [CKRecordZone.ID] {
            try await container.privateCloudDatabase.allRecordZones().map(\.zoneID)
        }

        func sharedZones() async throws -> [CKRecordZone.ID] {
            try await container.sharedCloudDatabase.allRecordZones().map(\.zoneID)
        }

        func deletePrivateZone(_ id: CKRecordZone.ID) async throws {
            do { _ = try await container.privateCloudDatabase.deleteRecordZone(withID: id) }
            catch let error as CKError where error.code == .zoneNotFound || error.code == .unknownItem {
                // Ein anderes Gerät kann die Zone zwischen Auflistung und Löschung entfernen.
            }
        }

        func leaveSharedZone(_ id: CKRecordZone.ID) async throws {
            // Nur die eigene Teilnahme entfernen; Daten anderer Eigentümer bleiben bestehen.
            let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: id)
            do { _ = try await container.sharedCloudDatabase.deleteRecord(withID: shareID) }
            catch let error as CKError where error.code == .zoneNotFound || error.code == .unknownItem { }
        }
    }
}

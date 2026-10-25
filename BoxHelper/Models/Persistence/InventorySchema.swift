import Foundation
import SwiftData

/// Das aktuelle Schema hat ausschließlich sichere fachliche Feldnamen. Löschungen
/// verwenden native SwiftData-Operationen und einen getrennten UUID-/Dateinamenverlauf.
enum InventorySchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [StoredBox.self, StoredItem.self, StoredLocation.self, InventoryMigrationMarker.self,
         StoredInventoryImage.self, StoredFormDraft.self, StoredDraftPhoto.self,
         StoredCloudPreference.self, StoredInventoryDeletion.self]
    }
}

enum InventorySchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [InventorySchemaV1.self, InventorySchemaV2.self, InventorySchemaV3.self, InventorySchemaV4.self]
    }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: InventorySchemaV1.self, toVersion: InventorySchemaV2.self),
         .lightweight(fromVersion: InventorySchemaV2.self, toVersion: InventorySchemaV3.self),
         .custom(fromVersion: InventorySchemaV3.self, toVersion: InventorySchemaV4.self,
                 willMigrate: InventorySchemaV4Migration.captureLegacyDeletions,
                 didMigrate: InventorySchemaV4Migration.finishMigration)]
    }
}

/// Einheitliche Projektion für deterministische UUID-Deduplizierung nach CloudKit-Importen.
protocol InventoryRecord: PersistentModel {
    associatedtype Value: Encodable & Equatable
    var id: UUID { get }
    var position: Int { get }
    var updatedAt: Date { get }
    var isTombstoned: Bool { get set }
    var syncChangedAt: Date { get set }
    var value: Value { get }
    func eraseContent()
}

/// Der Marker wird zusammen mit allen übernommenen Tabellen in derselben Datenbank gespeichert.
/// Ein Einstellungen-Reset kann dadurch niemals gelöschte Altbestände erneut importieren.
@Model
final class InventoryMigrationMarker {
    var key: String = ""
    var completedAt: Date = Date()

    init(key: String) {
        self.key = key
        completedAt = Date()
    }
}

struct InventorySnapshot: Codable, Equatable, Sendable {
    var boxes: [MovingBox]
    var items: [Items]
    var locations: [Locations]

    static let empty = InventorySnapshot(boxes: [], items: [], locations: [])
}

struct InventoryDeletedIDs: Equatable, Sendable {
    var boxes: Set<UUID>
    var locations: Set<UUID>
    static let empty = InventoryDeletedIDs(boxes: [], locations: [])
}

/// Ein Cloud-Refresh liefert auch die Tombstones. Formulare brauchen dadurch keine
/// zusätzlichen Datenbankabfragen, um eine inzwischen gelöschte Auswahl zu erkennen.
struct InventoryRemoteSnapshot: Equatable, Sendable {
    let inventory: InventorySnapshot
    let deletedIDs: InventoryDeletedIDs
    var integrityCandidates: InventoryIntegrityCandidates = .empty
    var trashDeletionDates: [String: Date] = [:]
}

/// Der Worker meldet nur UUIDs. Die Reparatur prüft deren aktuelle Eltern direkt
/// vor jedem kurzen Commit erneut, damit zwischenzeitliche Verschiebungen erhalten bleiben.
struct InventoryIntegrityCandidates: Equatable, Sendable {
    var boxes: Set<UUID> = []
    var items: Set<UUID> = []
    var locations: Set<UUID> = []
    static let empty = InventoryIntegrityCandidates()
    var isEmpty: Bool { boxes.isEmpty && items.isEmpty && locations.isEmpty }

    func batches(maximumCount: Int = 25) -> [Self] {
        let limit = max(1, min(25, maximumCount))
        var result: [Self] = []
        func append(_ ids: Set<UUID>, keyPath: WritableKeyPath<Self, Set<UUID>>) {
            let sorted = ids.sorted { $0.uuidString < $1.uuidString }
            for offset in stride(from: 0, to: sorted.count, by: limit) {
                var batch = Self()
                batch[keyPath: keyPath] = Set(sorted[offset..<min(sorted.count, offset + limit)])
                result.append(batch)
            }
        }
        append(items, keyPath: \.items)
        append(boxes, keyPath: \.boxes)
        append(locations, keyPath: \.locations)
        return result
    }
}

enum InventoryStorageError: LocalizedError {
    case invalidLegacyData(String)
    case duplicateID(String)

    var errorDescription: String? {
        switch self {
        case .invalidLegacyData(let key):
            return "Die bisherigen Inventardaten (\(key)) konnten nicht übernommen werden. Die Originaldaten bleiben erhalten."
        case .duplicateID(let table):
            return "Die Inventardaten enthalten doppelte IDs (\(table)). Es wurden keine Änderungen gespeichert."
        }
    }
}

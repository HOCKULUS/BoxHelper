import Foundation
import SwiftData

/// Der fachliche Löschverlauf schützt logische UUIDs und Dateinamen vor verspäteten
/// Offline-Kopien. Die Inventarobjekte selbst werden mit ModelContext.delete gelöscht.
/// Sichere Feldnamen vermeiden eine Kollision mit Core Datas internem Löschstatus.
@Model
final class StoredInventoryDeletion {
    var kind: String = ""
    var logicalKey: String = ""
    var deletedAt: Date = Date.distantPast
    var restoredAt: Date = Date.distantPast

    init(kind: String, logicalKey: String, deletedAt: Date = .distantPast,
         restoredAt: Date = .distantPast) {
        self.kind = kind
        self.logicalKey = logicalKey
        self.deletedAt = deletedAt
        self.restoredAt = restoredAt
    }
}

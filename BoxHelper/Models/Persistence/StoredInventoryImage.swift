import Foundation
import SwiftData

/// CloudKit synchronisiert Bildinhalt als Asset; bestehende Views lesen weiterhin Documents-Dateien.
/// Keine Unique-Constraint: CloudKit unterstützt diese nicht. Der Dateiname ist der logische Schlüssel.
@Model
final class StoredInventoryImage {
    var filename: String = ""
    @Attribute(.externalStorage) var data: Data? = nil
    var updatedAt: Date = Date.distantPast
    // Übergangskennzeichen für alte Synczeilen; neue Löschungen verwenden ModelContext.delete.
    var isTombstoned: Bool = false

    init(filename: String, data: Data?, updatedAt: Date = Date(), isTombstoned: Bool = false) {
        self.filename = filename
        self.data = isTombstoned ? nil : data
        self.updatedAt = updatedAt
        self.isTombstoned = isTombstoned
    }
}

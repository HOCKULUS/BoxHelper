import Foundation
import SwiftData

/// Metadaten und Fotos werden lokal in derselben Transaktion gespeichert. Fotos haben
/// eigene Assets, damit eine Texteingabe keine unveränderten Fotos erneut hochlädt.
@Model
final class StoredFormDraft {
    var id: UUID = UUID()
    var kind: String = "box"
    var title: String = ""
    var deviceID: String = ""
    var deviceName: String = ""
    @Attribute(.externalStorage) var payload: Data?
    var photoNames: [String] = []
    var updatedAt: Date = Date()
    // Übergangskennzeichen für alte Synczeilen; neue Löschungen verwenden ModelContext.delete.
    var isTombstoned: Bool = false

    init(id: UUID, kind: String, title: String, deviceID: String, deviceName: String, payload: Data) {
        self.id = id
        self.kind = kind
        self.title = title
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.payload = payload
    }
}

@Model
final class StoredDraftPhoto {
    var draftID: UUID = UUID()
    var filename: String = ""
    @Attribute(.externalStorage) var data: Data?
    var digest: String = ""
    var updatedAt: Date = Date()
    // Übergangskennzeichen für alte Synczeilen; neue Löschungen verwenden ModelContext.delete.
    var isTombstoned: Bool = false

    init(draftID: UUID, filename: String, data: Data, digest: String, updatedAt: Date) {
        self.draftID = draftID; self.filename = filename; self.data = data
        self.digest = digest; self.updatedAt = updatedAt
    }
}

/// Einstellungen bleiben persönliche Daten und werden nie in eine CKShare aufgenommen.
@Model
final class StoredCloudPreference {
    var key: String = ""
    @Attribute(.externalStorage) var value: Data?
    var updatedAt: Date = Date()
    // Übergangskennzeichen für alte Synczeilen; neue Löschungen verwenden ModelContext.delete.
    var isTombstoned: Bool = false

    init(key: String, value: Data?) {
        self.key = key
        self.value = value
        isTombstoned = value == nil
    }
}

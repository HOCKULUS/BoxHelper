import Foundation
import Zip

/// Archivierung arbeitet mit Werttypen und benötigt keinen SwiftData-Context im Hintergrund.
enum InventoryBackupArchive {
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif"]

    static func export(_ snapshot: InventorySnapshot,
                       documents: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
                       progressHandler: ((Double) -> Void)? = nil) throws -> URL? {
        guard !snapshot.boxes.isEmpty || !snapshot.items.isEmpty || !snapshot.locations.isEmpty else { return nil }
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: directory) }

        progressHandler?(0.05)
        let images = try manager.contentsOfDirectory(at: documents, includingPropertiesForKeys: [.isRegularFileKey])
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
        let imageNames = Set(images.map(\.lastPathComponent))
        let referencedImages = Set(snapshot.boxes.flatMap(\.images) + snapshot.items.flatMap(\.images)
            + snapshot.locations.map(\.image).filter { !$0.isEmpty })
        // Fehlende Fotos werden als Fehler gemeldet, statt ein unvollständiges Backup anzubieten.
        guard referencedImages.isSubset(of: imageNames) else { throw IntentBackupError.invalidBackup }
        for name in referencedImages { try IntentBackupValidation.validateFilename(name) }
        progressHandler?(0.15)

        // JSON-Dateinamen und DTO-Schema bleiben mit bisherigen ZIP-Backups kompatibel.
        let encoder = JSONEncoder()
        let boxes = directory.appendingPathComponent("boxes.json")
        let items = directory.appendingPathComponent("items.json")
        let locations = directory.appendingPathComponent("locations.json")
        try encoder.encode(snapshot.boxes).write(to: boxes, options: .atomic)
        progressHandler?(0.30)
        try encoder.encode(snapshot.items).write(to: items, options: .atomic)
        progressHandler?(0.45)
        try encoder.encode(snapshot.locations).write(to: locations, options: .atomic)
        progressHandler?(0.60)

        // Nur das fertige ZIP liegt im Dokumentenverzeichnis; JSON-Zwischendateien bleiben temporär.
        let archive = documents.appendingPathComponent("\(UUID().uuidString.prefix(8)).zip")
        do {
            try Zip.zipFiles(paths: images + [boxes, items, locations], zipFilePath: archive, password: nil) { progress in
                progressHandler?(min(max(0.70 + progress * 0.30, 0), 1))
            }
            progressHandler?(1)
            return archive
        } catch {
            try? manager.removeItem(at: archive)
            throw error
        }
    }

    static func extract(from archive: URL) throws -> URL {
        let access = archive.startAccessingSecurityScopedResource()
        defer { if access { archive.stopAccessingSecurityScopedResource() } }
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try Zip.unzipFile(archive, destination: directory, overwrite: false, password: nil)
            return directory
        } catch {
            try? manager.removeItem(at: directory)
            throw error
        }
    }

    static func legacySettings(in directory: URL) throws -> [String: Any] {
        let url = directory.appendingPathComponent("userDefaults.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        guard var settings = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else {
            throw IntentBackupError.invalidBackup
        }
        // Inventardaten aus alten Einstellungen dürfen die abgeschlossene Migration nicht rückgängig machen.
        for key in ["movingBoxes", "itemsDatabase", "locationsDatabase"] { settings.removeValue(forKey: key) }
        // Die iCloud-Wahl gehört zu diesem Gerät und darf durch alte Backups nicht verändert werden.
        settings.removeValue(forKey: CloudSyncPreferences.enabledKey)
        // Gerätezeiger und Sync-Receipts dürfen weder Entwürfe anderer Geräte aktivieren
        // noch eine bereits gespeicherte Cloud-Einstellung als neue lokale Änderung markieren.
        for key in Array(settings.keys) where key.hasPrefix("activeCloudDraft.")
            || ["syncAppPreferencesWithICloud", "privateCloudPreferenceReceiptsV1", "createFormDraftV1",
                "create_item_form_draft_v1", "create_location_form_draft_v1"].contains(key) {
            settings.removeValue(forKey: key)
        }
        // JSON erlaubt null; UserDefaults dagegen nur Property-List-Werte. Vor dem Commit prüfen.
        guard PropertyListSerialization.propertyList(settings, isValidFor: .binary) else {
            throw IntentBackupError.invalidBackup
        }
        return settings
    }
}

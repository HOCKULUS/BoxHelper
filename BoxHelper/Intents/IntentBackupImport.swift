import Foundation
import UIKit

@MainActor
enum IntentBackupImport {
    static func commit(from directory: URL, replaceExisting: Bool, requireComplete: Bool? = nil,
                       documents: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) throws {
        let manager = FileManager.default
        // AppIntents verlangen beim Ersetzen vollständige Archive; die UI kann ältere
        // Kisten-Backups ausdrücklich zulassen und fehlende Tabellen als leer übernehmen.
        let backup = try IntentBackupContents(directory: directory, requireComplete: requireComplete ?? replaceExisting)
        var importedBoxes = backup.boxes
        var importedItems = backup.items
        var importedLocations = backup.locations

        let referencedNames = Set(importedBoxes.flatMap(\.images) + importedItems.flatMap(\.images)
                                  + importedLocations.map(\.image).filter { !$0.isEmpty })
        let archivedNames = Set(try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
            .filter { InventoryBackupArchive.imageExtensions.contains($0.pathExtension.lowercased())
                && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .map(\.lastPathComponent))
        let standaloneNames = archivedNames.subtracting(referencedNames)
        let filenames = referencedNames.union(archivedNames)
        var photos: [String: Data] = [:]
        // Alle Bildverweise prüfen, auch wenn ältere Objekte beim Zusammenführen entfallen.
        for name in filenames {
            try IntentBackupValidation.validateFilename(name)
            let source = directory.appendingPathComponent(name)
            let fallback = documents.appendingPathComponent(name)
            let url = manager.fileExists(atPath: source.path) ? source : fallback
            guard (!replaceExisting || url == source), let data = try? Data(contentsOf: url), UIImage(data: data) != nil else {
                throw IntentBackupError.invalidBackup
            }
            photos[name] = data
        }

        // Neue Dateinamen schützen vorhandene Fotos vor Namenskollisionen.
        var renamed = Dictionary(uniqueKeysWithValues: referencedNames.map {
            ($0, "\(UUID().uuidString).\(URL(fileURLWithPath: $0).pathExtension)")
        })
        // Einzelbilder ohne Objektzuordnung gehören ebenfalls zum Backup. Beim Merge werden
        // vorhandene Namen übersprungen; eine Wiederherstellung kann sie kontrolliert ersetzen.
        for name in standaloneNames where replaceExisting || !manager.fileExists(atPath: documents.appendingPathComponent(name).path) {
            renamed[name] = name
        }
        // Bildänderungen aktualisieren Zeitstempel; für den Versionsvergleich das Backup-Datum erhalten.
        for index in importedBoxes.indices {
            let updatedAt = importedBoxes[index].updatedAt
            importedBoxes[index].images = importedBoxes[index].images.map { renamed[$0]! }
            importedBoxes[index].updatedAt = updatedAt
        }
        for index in importedItems.indices {
            let updatedAt = importedItems[index].updatedAt
            importedItems[index].images = importedItems[index].images.map { renamed[$0]! }
            importedItems[index].updatedAt = updatedAt
        }
        for index in importedLocations.indices where !importedLocations[index].image.isEmpty {
            let updatedAt = importedLocations[index].updatedAt
            importedLocations[index].image = renamed[importedLocations[index].image]!
            importedLocations[index].updatedAt = updatedAt
        }

        let current = try InventoryPersistence.snapshot()
        let boxes = replaceExisting ? importedBoxes : IntentBackupValidation.merge(importedBoxes, into: current.boxes, updatedAt: { $0.updatedAt })
        let items = replaceExisting ? importedItems : IntentBackupValidation.merge(importedItems, into: current.items, updatedAt: { $0.updatedAt })
        let locations = replaceExisting ? importedLocations : IntentBackupValidation.merge(importedLocations, into: current.locations, updatedAt: { $0.updatedAt })
        let neededPhotos = Set(boxes.flatMap(\.images) + items.flatMap(\.images) + locations.map(\.image))
            .union(standaloneNames.compactMap { renamed[$0] })
        var written: [URL] = []
        var originals: [URL: Data] = [:]
        do {
            for (oldName, newName) in renamed where neededPhotos.contains(newName) {
                let url = documents.appendingPathComponent(newName)
                if manager.fileExists(atPath: url.path) { originals[url] = try Data(contentsOf: url) }
                try photos[oldName]!.write(to: url, options: .atomic)
                written.append(url)
            }
            // Vollständiges Wiederherstellen bleibt eine bewusste Bestandsersetzung.
            // Ein Merge schreibt nur tatsächlich neuere Backupobjekte, keine alten Kopien
            // unveränderter Datensätze und keine zwischenzeitlich eingetroffenen Cloud-UUIDs.
            if replaceExisting {
                try InventoryPersistence.saveInventory(boxes: boxes, items: items, locations: locations)
            } else {
                let latest = try InventoryPersistence.snapshot()
                try InventoryPersistence.mergeInventory(
                    boxes: changes(importedBoxes, comparedTo: latest.boxes, updatedAt: { $0.updatedAt }),
                    items: changes(importedItems, comparedTo: latest.items, updatedAt: { $0.updatedAt }),
                    locations: changes(importedLocations, comparedTo: latest.locations, updatedAt: { $0.updatedAt })
                )
            }
        } catch {
            // Auch ein Datenbankfehler entfernt neue Fotos und stellt überschriebene Einzelbilder wieder her.
            for url in written {
                if let original = originals[url] { try? original.write(to: url, options: .atomic) }
                else { try? manager.removeItem(at: url) }
            }
            throw error
        }
        // Erst nach dem bestätigten Import abgleichen, einschließlich unzugeordneter Einzelbilder.
        InventoryPersistence.mediaDidChange()
    }

    /// Dieselbe strikte Versionsregel wie beim bisherigen Backup-Merge, jetzt mit begrenztem Schreibumfang.
    private static func changes<Value: Identifiable>(_ imported: [Value], comparedTo current: [Value],
                                                     updatedAt: (Value) -> Date) -> [Value] where Value.ID == UUID {
        let byID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        return imported.filter { value in
            guard let existing = byID[value.id] else { return true }
            return updatedAt(value) > updatedAt(existing)
        }
    }
}

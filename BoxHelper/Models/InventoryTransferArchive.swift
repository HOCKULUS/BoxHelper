import Foundation
import UIKit
import Zip

struct PreparedInventoryImport: Identifiable {
    let id = UUID()
    let directory: URL
    let archive: URL
    var payload: InventoryTransfer?
    var isBackup: Bool { payload == nil }
}

/// ZIP-Arbeit und Validierung sind vom UI-Zustand getrennt und können im Hintergrund laufen.
enum InventoryTransferArchive {
    static let manifestName = "boxhelper-selection.json"
    static var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    static func export(_ payload: InventoryTransfer, documents: URL = InventoryTransferArchive.documents) throws -> URL {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            let manifest = directory.appendingPathComponent(manifestName)
            try JSONEncoder().encode(payload).write(to: manifest, options: .atomic)
            var files = [manifest]
            for name in payload.imageNames.sorted() {
                try IntentBackupValidation.validateFilename(name)
                let source = documents.appendingPathComponent(name)
                guard let data = try? Data(contentsOf: source), UIImage(data: data) != nil else {
                    throw IntentBackupError.invalidBackup
                }
                let destination = directory.appendingPathComponent(name)
                try data.write(to: destination)
                files.append(destination)
            }
            let archive = directory.appendingPathComponent("BoxHelper-\(payload.kind.rawValue).zip")
            try Zip.zipFiles(paths: files, zipFilePath: archive, password: nil, progress: nil)
            return archive
        } catch {
            try? manager.removeItem(at: directory)
            throw error
        }
    }

    /// Bilder bleiben beim Teilen eigenständige Dateien, damit sie direkt in Fotos, Dateien oder Mail weitergegeben werden können.
    static func exportImages(_ payload: InventoryTransfer, documents: URL = InventoryTransferArchive.documents) throws -> [URL] {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            var urls: [URL] = []
            for image in payload.images {
                try IntentBackupValidation.validateFilename(image.filename)
                let source = documents.appendingPathComponent(image.filename)
                let destination = directory.appendingPathComponent(image.filename)
                guard let data = try? Data(contentsOf: source), UIImage(data: data) != nil else {
                    throw IntentBackupError.invalidBackup
                }
                try data.write(to: destination, options: .atomic)
                urls.append(destination)
            }
            return urls
        } catch {
            try? manager.removeItem(at: directory)
            throw error
        }
    }

    /// Erzeugt aus einzelnen Bilddateien denselben Vorschau- und Duplikatpfad wie ein Selection-ZIP.
    static func prepareImageFiles(_ urls: [URL]) throws -> PreparedInventoryImport {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let contents = directory.appendingPathComponent("contents")
        try manager.createDirectory(at: contents, withIntermediateDirectories: true)
        do {
            var images: [TransferImage] = []
            var usedNames = Set<String>()
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let name = url.lastPathComponent
                try IntentBackupValidation.validateFilename(name)
                guard !usedNames.contains(name),
                      ["jpg", "jpeg", "png", "heic", "heif"].contains(url.pathExtension.lowercased()),
                      let data = try? Data(contentsOf: url), UIImage(data: data) != nil else {
                    throw IntentBackupError.invalidBackup
                }
                usedNames.insert(name)
                try data.write(to: contents.appendingPathComponent(name), options: .atomic)
                images.append(TransferImage(filename: name, title: url.deletingPathExtension().lastPathComponent))
            }
            guard !images.isEmpty else { throw IntentBackupError.invalidBackup }
            let payload = InventoryTransfer(kind: .images, images: images)
            try validatePhotos(payload.imageNames, in: contents)
            return PreparedInventoryImport(directory: directory, archive: directory, payload: payload)
        } catch {
            try? manager.removeItem(at: directory)
            throw error
        }
    }

    static func prepare(_ url: URL) throws -> PreparedInventoryImport {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            let archive = directory.appendingPathComponent("import.zip")
            try manager.copyItem(at: url, to: archive)
            let contents = directory.appendingPathComponent("contents")
            try Zip.unzipFile(archive, destination: contents, overwrite: false, password: nil)
            let manifest = contents.appendingPathComponent(manifestName)
            if manager.fileExists(atPath: manifest.path) {
                let payload = try JSONDecoder().decode(InventoryTransfer.self, from: Data(contentsOf: manifest))
                guard payload.format == "BoxHelper.Selection", payload.version == 1, payload.count > 0,
                      Set(payload.images.map(\.filename)).count == payload.images.count else {
                    throw IntentBackupError.invalidBackup
                }
                try IntentBackupValidation.validateIDs(payload.boxes)
                try IntentBackupValidation.validateIDs(payload.items)
                try IntentBackupValidation.validateIDs(payload.locations)
                try validatePhotos(payload.imageNames, in: contents)
                return PreparedInventoryImport(directory: directory, archive: archive, payload: payload)
            }
            // Ein Backup wird nur abgelegt. Die Wiederherstellung bleibt in den Einstellungen.
            let backup = try IntentBackupContents(directory: contents, requireComplete: true)
            try validatePhotos(Set(backup.boxes.flatMap(\.images) + backup.items.flatMap(\.images)
                + backup.locations.map(\.image).filter { !$0.isEmpty }), in: contents)
            return PreparedInventoryImport(directory: directory, archive: archive, payload: nil)
        } catch {
            try? manager.removeItem(at: directory)
            throw error
        }
    }

    static func validatePhotos(_ names: Set<String>, in directory: URL) throws {
        for name in names {
            try IntentBackupValidation.validateFilename(name)
            guard ["jpg", "jpeg", "png", "heic", "heif"].contains(URL(fileURLWithPath: name).pathExtension.lowercased()) else {
                throw IntentBackupError.invalidBackup
            }
            guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)), UIImage(data: data) != nil else {
                throw IntentBackupError.invalidBackup
            }
        }
    }

    static func storeBackup(_ prepared: PreparedInventoryImport) throws {
        let destination = documents.appendingPathComponent("BoxHelper-Backup-\(UUID().uuidString.prefix(8)).zip")
        try FileManager.default.copyItem(at: prepared.archive, to: destination)
        do {
            upsertBackupMetadata(for: destination, snapshot: try snapshotFromBackupZIP(at: destination))
        } catch {
            // Bei einem Lesefehler kein vermeintlich erfolgreich importiertes Backup hinterlassen.
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    /// Zuerst alle Daten und Bilder vorbereiten; bei Schreibfehlern die Bildänderungen zurückrollen.
    @MainActor
    static func commit(_ payload: InventoryTransfer, from directory: URL, overwrite: Bool,
                       documents: URL = InventoryTransferArchive.documents) throws {
        let manager = FileManager.default
        let current = try InventoryPersistence.snapshot()
        let currentBoxes = current.boxes, currentItems = current.items, currentLocations = current.locations
        var accepted = payload
        if !overwrite {
            accepted.boxes.removeAll { box in currentBoxes.contains { $0.id == box.id } }
            accepted.items.removeAll { item in currentItems.contains { $0.id == item.id } }
            accepted.locations.removeAll { location in currentLocations.contains { $0.id == location.id } }
            accepted.images.removeAll { manager.fileExists(atPath: documents.appendingPathComponent($0.filename).path) }
        }
        let contents = directory.appendingPathComponent("contents")
        try validatePhotos(accepted.imageNames, in: contents)

        // Objektbilder erhalten neue Dateinamen, damit vorhandene, gemeinsam genutzte Fotos erhalten bleiben.
        let standalone = Set(accepted.images.map(\.filename))
        let renamed = Dictionary(uniqueKeysWithValues: accepted.imageNames.map { name in
            (name, standalone.contains(name) ? name : "\(UUID().uuidString).\(URL(fileURLWithPath: name).pathExtension)")
        })
        for index in accepted.boxes.indices {
            let date = accepted.boxes[index].updatedAt
            accepted.boxes[index].images = accepted.boxes[index].images.map { renamed[$0]! }
            if let location = accepted.boxes[index].location_uuid,
               !(currentLocations + accepted.locations).contains(where: { $0.id == location }) {
                accepted.boxes[index].location_uuid = nil
            }
            accepted.boxes[index].updatedAt = date
        }
        for index in accepted.items.indices {
            let date = accepted.items[index].updatedAt
            accepted.items[index].images = accepted.items[index].images.map { renamed[$0]! }
            if let box = accepted.items[index].box_uuid,
               !(currentBoxes + accepted.boxes).contains(where: { $0.id == box }) {
                accepted.items[index].box_uuid = nil
            }
            accepted.items[index].updatedAt = date
        }
        for index in accepted.locations.indices where !accepted.locations[index].image.isEmpty {
            let date = accepted.locations[index].updatedAt
            accepted.locations[index].image = renamed[accepted.locations[index].image]!
            accepted.locations[index].updatedAt = date
        }
        var originals: [URL: Data] = [:]
        var written: [URL] = []
        do {
            for (old, new) in renamed {
                let destination = documents.appendingPathComponent(new)
                if manager.fileExists(atPath: destination.path) { originals[destination] = try Data(contentsOf: destination) }
                let data = try Data(contentsOf: contents.appendingPathComponent(old))
                try data.write(to: destination, options: .atomic)
                written.append(destination)
            }
            // Ein Cloud-Import kann während der Dateivorbereitung neue UUIDs geliefert haben.
            // Überschreiben betrifft ausschließlich die ausgewählten Importobjekte.
            if !overwrite {
                let latest = try InventoryPersistence.snapshot()
                accepted.boxes.removeAll { box in latest.boxes.contains { $0.id == box.id } }
                accepted.items.removeAll { item in latest.items.contains { $0.id == item.id } }
                accepted.locations.removeAll { location in latest.locations.contains { $0.id == location.id } }
            }
            try InventoryPersistence.mergeInventory(boxes: accepted.boxes, items: accepted.items,
                                                     locations: accepted.locations)
        } catch {
            for url in written {
                if let data = originals[url] { try? data.write(to: url, options: .atomic) }
                else { try? manager.removeItem(at: url) }
            }
            throw error
        }
        // Einzelbilder verändern keine Inventarzeile, benötigen aber trotzdem einen Cloud-Abgleich.
        InventoryPersistence.mediaDidChange()
    }
}

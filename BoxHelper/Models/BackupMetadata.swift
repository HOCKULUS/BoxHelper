import Foundation
import Zip

struct BackupSnapshot: Codable, Equatable {
    var boxCount: Int
    var itemCount: Int
    var locationCount: Int
    var imageCount: Int
    var lastUpdatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case boxCount
        case itemCount
        case locationCount
        case imageCount
        case lastUpdatedAt
    }

    init(boxCount: Int, itemCount: Int, locationCount: Int, imageCount: Int, lastUpdatedAt: Date?) {
        self.boxCount = boxCount
        self.itemCount = itemCount
        self.locationCount = locationCount
        self.imageCount = imageCount
        self.lastUpdatedAt = lastUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        boxCount = try container.decode(Int.self, forKey: .boxCount)
        itemCount = try container.decode(Int.self, forKey: .itemCount)
        locationCount = try container.decode(Int.self, forKey: .locationCount)
        // Rückwärtskompatibel: Altbestände ohne imageCount werden mit 0 geladen.
        imageCount = try container.decodeIfPresent(Int.self, forKey: .imageCount) ?? 0
        lastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt)
    }
}

struct BackupMetadataEntry: Codable, Equatable {
    var fileName: String
    var filePath: String
    var recordedAt: Date
    var snapshot: BackupSnapshot
}

private struct BackupMetadataStoreFile: Codable {
    var entries: [BackupMetadataEntry]
}

private let backupMetadataFileName = "backupMetadata.json"

private func backupMetadataFileURL() -> URL? {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
        .appendingPathComponent(backupMetadataFileName)
}

func loadBackupMetadataIndex() -> [String: BackupMetadataEntry] {
    guard let fileURL = backupMetadataFileURL(),
          let data = try? Data(contentsOf: fileURL) else {
        return [:]
    }

    let decoder = JSONDecoder()
    guard let store = try? decoder.decode(BackupMetadataStoreFile.self, from: data) else {
        return [:]
    }

    return Dictionary(uniqueKeysWithValues: store.entries.map { ($0.fileName, $0) })
}

private func saveBackupMetadataIndex(_ index: [String: BackupMetadataEntry]) {
    guard let fileURL = backupMetadataFileURL() else { return }
    let store = BackupMetadataStoreFile(entries: Array(index.values).sorted(by: { $0.fileName < $1.fileName }))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    do {
        let data = try encoder.encode(store)
        try data.write(to: fileURL, options: .atomic)
    } catch {
        print("Fehler beim Speichern der Backup-Metadaten: \(error)")
    }
}

func upsertBackupMetadata(for backupURL: URL, snapshot: BackupSnapshot) {
    var index = loadBackupMetadataIndex()
    let fileName = backupURL.lastPathComponent
    index[fileName] = BackupMetadataEntry(
        fileName: fileName,
        filePath: backupURL.path,
        recordedAt: Date(),
        snapshot: snapshot
    )
    saveBackupMetadataIndex(index)
}

func removeBackupMetadata(fileName: String) {
    var index = loadBackupMetadataIndex()
    index.removeValue(forKey: fileName)
    saveBackupMetadataIndex(index)
}

func pruneBackupMetadataToExistingZIPs(existingZIPNames: Set<String>) -> [String: BackupMetadataEntry] {
    var index = loadBackupMetadataIndex()
    let staleNames = Set(index.keys).subtracting(existingZIPNames)
    for staleName in staleNames {
        index.removeValue(forKey: staleName)
    }
    saveBackupMetadataIndex(index)
    return index
}

func currentBackupSnapshot() -> BackupSnapshot {
    let boxes = loadBoxes()
    let items = loadItems()
    let locations = loadLocations()
    let imageCount = countAllImagesInAppStorage()

    let latestBoxUpdate = boxes.map(\.updatedAt).max()
    let latestItemUpdate = items.map(\.updatedAt).max()
    let latestLocationUpdate = locations.map(\.updatedAt).max()
    let latestUpdate = [latestBoxUpdate, latestItemUpdate, latestLocationUpdate].compactMap { $0 }.max()

    return BackupSnapshot(
        boxCount: boxes.count,
        itemCount: items.count,
        locationCount: locations.count,
        imageCount: imageCount,
        lastUpdatedAt: latestUpdate
    )
}

func snapshotFromBackupZIP(at zipURL: URL) throws -> BackupSnapshot {
    let fileManager = FileManager.default
    guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        throw NSError(domain: "BackupMetadata", code: 1, userInfo: [NSLocalizedDescriptionKey: "Dokumentenverzeichnis nicht gefunden"])
    }

    let tempDirectory = try fileManager.url(
        for: .itemReplacementDirectory,
        in: .userDomainMask,
        appropriateFor: documentsDirectory,
        create: true
    )

    defer {
        try? fileManager.removeItem(at: tempDirectory)
    }

    // Für Metadaten reicht ein temporäres Entpacken der JSON-Dateien.
    try Zip.unzipFile(zipURL, destination: tempDirectory, overwrite: true, password: nil, progress: nil)

    let boxes: [MovingBox] = try decodeFirstExistingFile(
        in: tempDirectory,
        candidateNames: ["boxes.json", "movingBoxes.json"]
    )
    let items: [Items] = try decodeFirstExistingFile(
        in: tempDirectory,
        candidateNames: ["items.json"]
    )
    let locations: [Locations] = try decodeFirstExistingFile(
        in: tempDirectory,
        candidateNames: ["locations.json"]
    )
    let imageCount = countImageFilesRecursively(in: tempDirectory)

    let latestBoxUpdate = boxes.map(\.updatedAt).max()
    let latestItemUpdate = items.map(\.updatedAt).max()
    let latestLocationUpdate = locations.map(\.updatedAt).max()
    let latestUpdate = [latestBoxUpdate, latestItemUpdate, latestLocationUpdate].compactMap { $0 }.max()

    return BackupSnapshot(
        boxCount: boxes.count,
        itemCount: items.count,
        locationCount: locations.count,
        imageCount: imageCount,
        lastUpdatedAt: latestUpdate
    )
}

private func countImageFilesRecursively(in directory: URL) -> Int {
    let fileManager = FileManager.default
    let allowedExtensions: Set<String> = ["jpg", "jpeg", "png"]
    let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]

    guard let enumerator = fileManager.enumerator(
        at: directory,
        includingPropertiesForKeys: Array(resourceKeys),
        options: [.skipsHiddenFiles]
    ) else {
        return 0
    }

    var count = 0
    for case let fileURL as URL in enumerator {
        guard let values = try? fileURL.resourceValues(forKeys: resourceKeys),
              values.isRegularFile == true else {
            continue
        }

        if allowedExtensions.contains(fileURL.pathExtension.lowercased()) {
            count += 1
        }
    }
    return count
}

private func decodeFirstExistingFile<T: Decodable>(in directory: URL, candidateNames: [String]) throws -> [T] {
    let fileManager = FileManager.default
    for fileName in candidateNames {
        let fileURL = directory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([T].self, from: data)
        }
    }
    return []
}

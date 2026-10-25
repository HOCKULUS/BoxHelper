import Foundation

/// Decode all databases before the import can write photos or inventory.
struct IntentBackupContents {
    let boxes: [MovingBox]
    let items: [Items]
    let locations: [Locations]

    init(directory: URL, requireComplete: Bool) throws {
        let manager = FileManager.default
        let decoder = JSONDecoder()
        let boxesFile = manager.fileExists(atPath: directory.appendingPathComponent("boxes.json").path)
            ? "boxes.json" : "movingBoxes.json"
        do {
            boxes = try decoder.decode([MovingBox].self, from: Data(contentsOf: directory.appendingPathComponent(boxesFile)))
            // Merge supports older backups. Replacement requires all databases to avoid accidental data loss.
            func decodeOptional<T: Decodable>(_ type: T.Type, _ filename: String, fallback: T) throws -> T {
                let url = directory.appendingPathComponent(filename)
                if manager.fileExists(atPath: url.path) { return try decoder.decode(type, from: Data(contentsOf: url)) }
                guard !requireComplete else { throw IntentBackupError.invalidBackup }
                return fallback
            }
            items = try decodeOptional([Items].self, "items.json", fallback: [])
            locations = try decodeOptional([Locations].self, "locations.json", fallback: [])
            try IntentBackupValidation.validateIDs(boxes)
            try IntentBackupValidation.validateIDs(items)
            try IntentBackupValidation.validateIDs(locations)
        } catch { throw IntentBackupError.invalidBackup }
    }
}

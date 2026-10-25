import Foundation

/// Pure validation/merge rules, shared with the standalone backup checks.
enum IntentBackupValidation {
    static func validateIDs<Object: Identifiable>(_ objects: [Object]) throws where Object.ID == UUID {
        guard Set(objects.map(\.id)).count == objects.count else { throw IntentBackupError.invalidBackup }
    }

    static func validateFilename(_ name: String) throws {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\\") else {
            throw IntentBackupError.invalidBackup
        }
    }

    /// Preserve stable ordering and keep the newer object when a backup shares an existing ID.
    static func merge<Object: Identifiable>(_ imported: [Object], into existing: [Object],
                                           updatedAt: (Object) -> Date) -> [Object] where Object.ID == UUID {
        var result = existing
        var indices: [UUID: Int] = [:]
        for (index, object) in result.enumerated() { indices[object.id] = index }
        for object in imported {
            if let index = indices[object.id] {
                if updatedAt(object) > updatedAt(result[index]) { result[index] = object }
            } else {
                indices[object.id] = result.count
                result.append(object)
            }
        }
        return result
    }
}

enum IntentBackupError: LocalizedError {
    case invalidBackup

    var errorDescription: String? {
        NSLocalizedString("The ZIP backup is invalid or contains missing image files. No inventory data was changed.",
                          comment: "Backup shortcut validation error")
    }
}

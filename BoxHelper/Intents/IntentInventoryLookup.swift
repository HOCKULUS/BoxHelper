import Foundation

/// Shared validation for shortcut inputs. Ambiguous names must never silently select the first object.
enum IntentInventoryError: LocalizedError {
    case notFound, ambiguousName, emptyName, invalidItemID, invalidImage, imageUnavailable, saveFailed

    var errorDescription: String? {
        let key: String
        switch self {
        case .notFound: key = "The requested inventory object was not found."
        case .ambiguousName: key = "Several objects have this name. Please use the ID."
        case .emptyName: key = "Please enter a name."
        case .invalidItemID: key = "Please provide a valid item ID (UUID)."
        case .invalidImage: key = "Please provide at least one valid image."
        case .imageUnavailable: key = "An image file is missing or cannot be read."
        case .saveFailed: key = "The images could not be saved."
        }
        return NSLocalizedString(key, comment: "Inventory shortcut error")
    }
}

enum IntentInventoryLookup {
    static func resolve<Object: Identifiable>(_ reference: String, in objects: [Object],
                                             name: (Object) -> String) throws -> Object where Object.ID == UUID {
        let reference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if let id = UUID(uuidString: reference) {
            guard let object = objects.first(where: { $0.id == id }) else { throw IntentInventoryError.notFound }
            return object
        }
        guard !reference.isEmpty else { throw IntentInventoryError.emptyName }
        let matches = objects.filter {
            name($0).trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(reference) == .orderedSame
        }
        guard let object = matches.first else { throw IntentInventoryError.notFound }
        guard matches.count == 1 else { throw IntentInventoryError.ambiguousName }
        return object
    }

    /// Unknown names may create locations; unknown IDs and ambiguous names must always fail.
    static func existingOrNewName<Object: Identifiable>(_ reference: String, in objects: [Object],
                                                       name: (Object) -> String) throws -> Object? where Object.ID == UUID {
        do {
            return try resolve(reference, in: objects, name: name)
        } catch IntentInventoryError.notFound {
            guard UUID(uuidString: reference.trimmingCharacters(in: .whitespacesAndNewlines)) == nil else {
                throw IntentInventoryError.notFound
            }
            return nil
        }
    }

    /// Keep the input order, remove blank tags, and merge case-insensitive duplicates.
    static func normalizedTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags.compactMap {
            let tag = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tag.isEmpty, seen.insert(tag.lowercased()).inserted else { return nil }
            return tag
        }
    }
}

import Foundation

struct ImageInventoryReport {
    let assignedImages: [URL]
    let unassignedImages: [URL]

    var hasUnassignedImages: Bool {
        !unassignedImages.isEmpty
    }
}

struct ImageDeletionResult {
    let deletedFiles: Int
    let detachedReferences: Int
}

func buildImageInventoryReport() -> ImageInventoryReport {
    let allImageFiles = listImageFilesInDocumentsDirectory()
    let referencedNames = referencedImageFileNames(
        boxes: loadBoxes(),
        items: loadItems(),
        locations: loadLocations()
    )

    let assigned = allImageFiles.filter { referencedNames.contains($0.lastPathComponent.lowercased()) }
    let unassigned = allImageFiles.filter { !referencedNames.contains($0.lastPathComponent.lowercased()) }

    return ImageInventoryReport(
        assignedImages: assigned.sorted(by: { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }),
        unassignedImages: unassigned.sorted(by: { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending })
    )
}

func deleteImages(_ imageURLs: [URL], detachReferences: Bool) -> ImageDeletionResult {
    let fileManager = FileManager.default
    var deletedFiles = 0
    let namesToDelete = Set(imageURLs.map { $0.lastPathComponent.lowercased() })

    for imageURL in imageURLs {
        do {
            if fileManager.fileExists(atPath: imageURL.path) {
                try fileManager.removeItem(at: imageURL)
                deletedFiles += 1
            }
        } catch {
            print("Fehler beim Löschen von Bild \(imageURL.lastPathComponent): \(error)")
        }
    }

    let detachedCount = detachReferences ? detachImageReferences(fileNames: namesToDelete) : 0
    return ImageDeletionResult(deletedFiles: deletedFiles, detachedReferences: detachedCount)
}

private func listImageFilesInDocumentsDirectory() -> [URL] {
    let fileManager = FileManager.default
    guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return []
    }

    let allowedExtensions: Set<String> = ["jpg", "jpeg", "png"]

    do {
        let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
        return fileURLs.filter { allowedExtensions.contains($0.pathExtension.lowercased()) }
    } catch {
        print("Fehler beim Lesen des Dokumentenverzeichnisses: \(error)")
        return []
    }
}

private func referencedImageFileNames(boxes: [MovingBox], items: [Items], locations: [Locations]) -> Set<String> {
    var names = Set<String>()

    for box in boxes {
        for imageName in box.images {
            if let normalized = normalizeImageFileName(imageName) {
                names.insert(normalized)
            }
        }
    }

    for item in items {
        for imageName in item.images {
            if let normalized = normalizeImageFileName(imageName) {
                names.insert(normalized)
            }
        }
    }

    for location in locations {
        if let normalized = normalizeImageFileName(location.image) {
            names.insert(normalized)
        }
    }

    return names
}

private func detachImageReferences(fileNames: Set<String>) -> Int {
    guard !fileNames.isEmpty else { return 0 }
    var detachedReferences = 0

    var boxes = loadBoxes()
    var items = loadItems()
    var locations = loadLocations()

    for index in boxes.indices {
        let originalCount = boxes[index].images.count
        boxes[index].images.removeAll { imageName in
            guard let normalized = normalizeImageFileName(imageName) else { return false }
            return fileNames.contains(normalized)
        }
        detachedReferences += max(0, originalCount - boxes[index].images.count)
    }

    for index in items.indices {
        let originalCount = items[index].images.count
        items[index].images.removeAll { imageName in
            guard let normalized = normalizeImageFileName(imageName) else { return false }
            return fileNames.contains(normalized)
        }
        detachedReferences += max(0, originalCount - items[index].images.count)
    }

    for index in locations.indices {
        guard let normalized = normalizeImageFileName(locations[index].image) else { continue }
        if fileNames.contains(normalized) {
            locations[index].image = ""
            detachedReferences += 1
        }
    }

    saveBoxes(boxes)
    saveItems(items)
    saveLocations(locations)
    return detachedReferences
}

private func normalizeImageFileName(_ rawValue: String) -> String? {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return URL(fileURLWithPath: trimmed).lastPathComponent.lowercased()
}

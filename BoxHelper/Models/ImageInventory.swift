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

@MainActor
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

@MainActor
func deleteImages(_ imageURLs: [URL], detachReferences: Bool) -> ImageDeletionResult {
    let fileManager = FileManager.default
    let namesToDelete = Set(imageURLs.map { $0.lastPathComponent.lowercased() })
    let detachedCount: Int
    let retainedNames: Set<String>
    do {
        // Bei einem DB-Fehler bleiben sowohl Referenzen als auch die Originaldateien erhalten.
        detachedCount = detachReferences ? try detachImageReferences(fileNames: namesToDelete) : 0
        let confirmed = try InventoryPersistence.snapshot()
        retainedNames = referencedImageFileNames(boxes: confirmed.boxes, items: confirmed.items, locations: confirmed.locations)
    } catch {
        InventoryStorageState.shared.report(error)
        return ImageDeletionResult(deletedFiles: 0, detachedReferences: 0)
    }

    var deletedFiles = 0
    var committedPhotoDeletion = false
    for imageURL in imageURLs where !retainedNames.contains(imageURL.lastPathComponent.lowercased()) {
        do {
            // Auch ausstehende Cloud-Fotos ohne lokale Datei müssen nativ gelöscht
            // werden, damit ein verspätetes Asset nicht als loses Foto erscheint.
            try InventoryPersistence.deleteCloudPhotos([imageURL.lastPathComponent])
            committedPhotoDeletion = true
            if fileManager.fileExists(atPath: imageURL.path) {
                try InventoryPhotoFileCoordinator.remove(imageURL)
                deletedFiles += 1
            }
        } catch {
            InventoryStorageState.shared.report(error)
        }
    }
    // Auch ein bestätigter Auftrag ohne Dateilöschung exportiert Änderungen.
    if committedPhotoDeletion { InventoryPersistence.mediaDidChange() }
    return ImageDeletionResult(deletedFiles: deletedFiles, detachedReferences: detachedCount)
}

private func listImageFilesInDocumentsDirectory() -> [URL] {
    let fileManager = FileManager.default
    guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return []
    }

    let allowedExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif"]

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

@MainActor
private func detachImageReferences(fileNames: Set<String>) throws -> Int {
    guard !fileNames.isEmpty else { return 0 }
    var detachedReferences = 0

    let inventory = try InventoryPersistence.snapshot()
    var boxes = inventory.boxes
    var items = inventory.items
    var locations = inventory.locations

    for index in boxes.indices {
        let originalCount = boxes[index].images.count
        let retained = boxes[index].images.filter { imageName in
            guard let normalized = normalizeImageFileName(imageName) else { return true }
            return !fileNames.contains(normalized)
        }
        // Auch eine erfolglose removeAll-Mutation würde didSet/updatedAt auslösen.
        // Unbetroffene Cloud-Datensätze bleiben deshalb vollständig unverändert.
        guard retained.count != originalCount else { continue }
        boxes[index].images = retained
        detachedReferences += originalCount - retained.count
    }

    for index in items.indices {
        let originalCount = items[index].images.count
        let retained = items[index].images.filter { imageName in
            guard let normalized = normalizeImageFileName(imageName) else { return true }
            return !fileNames.contains(normalized)
        }
        guard retained.count != originalCount else { continue }
        items[index].images = retained
        detachedReferences += originalCount - retained.count
    }

    for index in locations.indices {
        guard let normalized = normalizeImageFileName(locations[index].image) else { continue }
        if fileNames.contains(normalized) {
            locations[index].image = ""
            detachedReferences += 1
        }
    }

    try InventoryPersistence.applyInventoryChanges(from: inventory,
        to: InventorySnapshot(boxes: boxes, items: items, locations: locations))
    return detachedReferences
}

private func normalizeImageFileName(_ rawValue: String) -> String? {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return URL(fileURLWithPath: trimmed).lastPathComponent.lowercased()
}

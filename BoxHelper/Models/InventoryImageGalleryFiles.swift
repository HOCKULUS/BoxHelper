import Foundation

/// Reine Dateimetadaten: Die Galerie liest weder Dateiattribute noch Fotos im View-Body.
struct InventoryLooseGalleryPhoto: Equatable, Sendable {
    let url: URL
    let createdAt: Date
    let updatedAt: Date
}

enum InventoryImageGalleryFiles {
    /// Der Scanner erhält nur Wertkopien. SQL-Modelle und UI-Zustand verlassen ihren Actor nicht.
    static func scan(in directory: URL, referencedNames: Set<String>) throws -> [InventoryLooseGalleryPhoto] {
        let manager = FileManager.default
        guard manager.fileExists(atPath: directory.path) else { return [] }
        let keys: Set<URLResourceKey> = [.creationDateKey, .contentModificationDateKey, .isRegularFileKey]
        let urls = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys))
        let extensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif"]
        var files: [InventoryLooseGalleryPhoto] = []
        for url in urls {
            try Task.checkCancellation()
            guard extensions.contains(url.pathExtension.lowercased()),
                  !referencedNames.contains(url.lastPathComponent.lowercased()) else { continue }
            let values = try url.resourceValues(forKeys: keys)
            guard values.isRegularFile == true else { continue }
            files.append(InventoryLooseGalleryPhoto(url: url, createdAt: values.creationDate ?? .distantPast,
                                                    updatedAt: values.contentModificationDate ?? .distantPast))
        }
        return files.sorted {
            $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending
        }
    }

    /// Die View kann einen älteren Scan abbrechen, sobald Inventar oder Fotodateien neuer sind.
    static func scanInBackground(in directory: URL, referencedNames: Set<String>) async throws -> [InventoryLooseGalleryPhoto] {
        try Task.checkCancellation()
        let worker = Task.detached(priority: .utility) { try scan(in: directory, referencedNames: referencedNames) }
        return try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
    }

    static func referencedNames(in inventory: InventorySnapshot) -> Set<String> {
        Set((inventory.boxes.flatMap(\.images) + inventory.items.flatMap(\.images) + inventory.locations.map(\.image))
            .compactMap { name -> String? in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : URL(fileURLWithPath: trimmed).lastPathComponent.lowercased()
            })
    }
}

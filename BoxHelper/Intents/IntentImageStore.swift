import AppIntents
import UIKit
import UniformTypeIdentifiers

/// Photo import is shared by item and location shortcuts; all inputs are validated before writing files.
@MainActor
enum IntentImageStore {
    @available(iOS 18.0, *)
    static func prepare(_ files: [IntentFile]) async throws -> [UIImage] {
        guard !files.isEmpty else { throw IntentInventoryError.invalidImage }
        let storedSize = UserDefaults.standard.object(forKey: "sliderValue2") as? Double ?? 500
        let size = storedSize.isFinite && storedSize > 0 ? storedSize : 500
        var images: [UIImage] = []
        for file in files {
            let data = try await file.data(contentType: .image)
            guard let image = UIImage(data: data),
                  let resized = image.resizeImage(targetSize: CGSize(width: size, height: size)) else {
                throw IntentInventoryError.invalidImage
            }
            images.append(resized)
        }
        return images
    }

    static func tags(for images: [UIImage]) async -> [String] {
        // The existing generator performs OCR off main and respects the app's tag settings.
        await withCheckedContinuation { continuation in
            generateAutomaticTagsIfEnabled(from: images) { continuation.resume(returning: $0) }
        }
    }

    static func save(_ images: [UIImage]) throws -> [String] {
        var urls: [URL] = []
        do {
            for image in images {
                guard let data = image.compressImage(),
                      let url = UserDefaultsManager.shared.saveImage(data, withName: "\(UUID().uuidString).jpg") else {
                    throw IntentInventoryError.saveFailed
                }
                urls.append(url)
            }
            return urls.map(\.lastPathComponent)
        } catch {
            // A partially failed import must not leave unassigned photos behind.
            for url in urls { try? FileManager.default.removeItem(at: url) }
            throw error
        }
    }

    /// Neue Fotos bei einem Datenbankfehler entfernen; bestehende Bilddateien bleiben erhalten.
    static func commit(_ names: [String], saving: () throws -> Void) throws {
        do {
            try saving()
        } catch {
            names.forEach { UserDefaultsManager.shared.deleteImage(named: $0) }
            throw error
        }
    }

    static func files(named names: [String]) throws -> [IntentFile] {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return try names.map { name in
            guard !name.isEmpty, name == URL(fileURLWithPath: name).lastPathComponent else {
                throw IntentInventoryError.imageUnavailable
            }
            let url = directory.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url), UIImage(data: data) != nil else {
                throw IntentInventoryError.imageUnavailable
            }
            // Return actual file contents so later actions can share or process the photos.
            return IntentFile(data: data, filename: name, type: UTType(filenameExtension: url.pathExtension) ?? .image)
        }
    }
}

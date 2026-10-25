import Foundation
import ImageIO
import UIKit

/// Listenbilder werden auf Zielgröße dekodiert. Dateiprüfung, ImageIO und optionales
/// Zuschneiden laufen ausdrücklich in einem Detached Task statt auf dem MainActor.
@MainActor
final class InventoryThumbnailLoader {
    static let shared = InventoryThumbnailLoader()

    struct Request: Hashable, Sendable {
        let fileURL: URL
        let maxPixelSize: Int?
        let variant: String

        init(filename: String, maxPixelSize: CGFloat, variant: String = "default",
             directory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
            fileURL = directory.appendingPathComponent(filename)
            self.maxPixelSize = max(1, Int(maxPixelSize.rounded(.up)))
            self.variant = variant
        }

        /// Einzelbildansichten dürfen die Originalauflösung behalten. Auch diese
        /// Dekodierung wird außerhalb des UI-Threads vollständig vorbereitet.
        init(filename: String, variant: String = "original",
             directory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
            fileURL = directory.appendingPathComponent(filename)
            maxPixelSize = nil
            self.variant = variant
        }
    }

    /// Eine neue Medienrevision prüft Dateien erneut, löscht aber keine unveränderten Bilder.
    struct TaskIdentity: Hashable {
        let request: Request
        let mediaRevision: Int
    }

    private struct RunningTask {
        let id = UUID()
        let task: Task<DecodedImage?, Never>
    }
    private var runningTasks: [TaskIdentity: RunningTask] = [:]

    func cachedImage(for request: Request) -> UIImage? {
        InventoryThumbnailMemoryCache.shared.image(for: request)?.image
    }

    func load(_ request: Request, mediaRevision: Int,
              transform: @escaping @Sendable (UIImage) -> UIImage = { $0 }) async -> UIImage? {
        guard !Task.isCancelled else { return nil }
        let identity = TaskIdentity(request: request, mediaRevision: mediaRevision)
        let running: RunningTask
        if let running = runningTasks[identity] {
            let result = await running.task.value
            guard !Task.isCancelled else { return nil }
            return result?.image
        } else {
            let task = Task.detached(priority: .utility) {
                Self.decode(request, transform: transform)
            }
            running = RunningTask(task: task)
            runningTasks[identity] = running
        }
        let result = await running.task.value
        if runningTasks[identity]?.id == running.id { runningTasks[identity] = nil }
        // Mehrere sichtbare Zeilen können denselben Worker nutzen. Beim Verlassen einer
        // Zeile bleibt dessen Cache nutzbar, die abgebrochene View erhält aber kein Ergebnis.
        guard !Task.isCancelled else { return nil }
        return result?.image
    }

    private nonisolated static func decode(_ request: Request,
                                          transform: @Sendable (UIImage) -> UIImage) -> DecodedImage? {
        let cache = InventoryThumbnailMemoryCache.shared
        // Ein Cloud-Download kann eine Datei während des Dekodierens atomar ersetzen.
        // Dann einmal mit der neuen Version wiederholen, statt das alte Bild einzulagern.
        for _ in 0..<2 {
            guard !Task.isCancelled, let version = FileVersion.read(request.fileURL) else {
                cache.remove(request)
                return nil
            }
            if let cached = cache.image(for: request), cached.version == version {
                return cached.decoded
            }
            guard let source = CGImageSourceCreateWithURL(request.fileURL as CFURL, nil) else { return nil }
            let prepared: UIImage?
            if let size = request.maxPixelSize {
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                    kCGImageSourceThumbnailMaxPixelSize: size
                ]
                prepared = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { UIImage(cgImage: $0) }
            } else {
                let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
                let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
                let orientation = imageOrientation(properties?[kCGImagePropertyOrientation] as? Int ?? 1)
                prepared = CGImageSourceCreateImageAtIndex(source, 0, options).map {
                    UIImage(cgImage: $0, scale: 1, orientation: orientation)
                }
            }
            guard let prepared, !Task.isCancelled else { return nil }
            let decoded = DecodedImage(image: transform(prepared))
            guard FileVersion.read(request.fileURL) == version else { continue }
            cache.insert(decoded, for: request, version: version)
            return decoded
        }
        return nil
    }

    private nonisolated static func imageOrientation(_ value: Int) -> UIImage.Orientation {
        switch value {
        case 2: .upMirrored
        case 3: .down
        case 4: .downMirrored
        case 5: .leftMirrored
        case 6: .right
        case 7: .rightMirrored
        case 8: .left
        default: .up
        }
    }
}

/// Die UIImage wird nach der Erzeugung ausschließlich gelesen. Diese Hülle erlaubt
/// die Übergabe zwischen Worker und MainActor auch mit älteren UIKit-SDKs.
private struct DecodedImage: @unchecked Sendable {
    let image: UIImage
}

private struct FileVersion: Equatable, Sendable {
    let modificationDate: Date
    let size: UInt64
    let fileNumber: UInt64

    static func read(_ url: URL) -> FileVersion? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attributes[.modificationDate] as? Date,
              let size = attributes[.size] as? NSNumber,
              let number = attributes[.systemFileNumber] as? NSNumber else { return nil }
        // Die Dateinummer erkennt auch atomare Ersetzungen mit gleichem Datum und Größe.
        return FileVersion(modificationDate: date, size: size.uint64Value, fileNumber: number.uint64Value)
    }
}

/// NSCache synchronisiert Zugriffe intern. Einträge und Bilder bleiben unveränderlich;
/// es wird nur der Eintrag einer tatsächlich geänderten Datei ersetzt.
private final class InventoryThumbnailMemoryCache: @unchecked Sendable {
    static let shared = InventoryThumbnailMemoryCache()

    final class Entry: NSObject {
        let decoded: DecodedImage
        let version: FileVersion
        var image: UIImage { decoded.image }

        init(decoded: DecodedImage, version: FileVersion) {
            self.decoded = decoded
            self.version = version
        }
    }

    private let cache = NSCache<NSString, Entry>()
    private init() {
        cache.countLimit = 800
        // Einzelbildansichten nutzen volle Auflösung; deren Speicher zählt deshalb
        // ebenfalls gegen ein festes Budget statt nur gegen die Anzahl der Einträge.
        cache.totalCostLimit = 96 * 1_024 * 1_024
    }

    private func key(_ request: InventoryThumbnailLoader.Request) -> NSString {
        "\(request.fileURL.path)#\(request.maxPixelSize.map(String.init) ?? "original")#\(request.variant)" as NSString
    }

    func image(for request: InventoryThumbnailLoader.Request) -> Entry? {
        cache.object(forKey: key(request))
    }

    func insert(_ image: DecodedImage, for request: InventoryThumbnailLoader.Request, version: FileVersion) {
        let cost = image.image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(Entry(decoded: image, version: version), forKey: key(request), cost: cost)
    }

    func remove(_ request: InventoryThumbnailLoader.Request) { cache.removeObject(forKey: key(request)) }
}

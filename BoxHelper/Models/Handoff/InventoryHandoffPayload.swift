import Foundation
import ImageIO

/// Nur dieses kleine Protokoll beschreibt Handoff. Formular und Fotos bleiben
/// im Arbeitsspeicher und werden ausschließlich durch die Continuation-Streams übertragen.
enum InventoryHandoffPayload {
    static let version = 1
    static let kinds: Set<String> = ["box", "item", "location"]
    static let tabs: Set<String> = ["boxes", "items", "locations", "images"]
    static let maximumFormBytes = 1_048_576
    static let maximumPhotoBytes = 8_388_608
    static let maximumPhotoCount = 64
    static let maximumCombinedPhotoBytes = 33_554_432
    static let maximumFrameBytes = 48_234_496
    static let maximumSearchBytes = 1_800

    struct Photo: Codable, Sendable, Equatable {
        let name: String
        let data: Data
    }

    struct Form: Codable, Sendable {
        var version = InventoryHandoffPayload.version
        var revision = UUID()
        let id: UUID
        let kind: String
        let data: Data
        let photos: [Photo]

        func validate() throws -> NormalizedForm {
            guard version == InventoryHandoffPayload.version else { throw InventoryHandoffError.unsupportedVersion }
            let normalized = try normalize(data, kind: kind)
            guard photos.count <= maximumPhotoCount,
                  Set(photos.map(\.name)).count == photos.count,
                  Set(photos.map(\.name)) == normalized.names else { throw InventoryHandoffError.invalidPhotos }
            var total = 0
            for photo in photos {
                total += photo.data.count
                guard total <= maximumCombinedPhotoBytes else { throw InventoryHandoffError.tooLarge }
                try validatePhoto(photo.data)
            }
            return normalized
        }
    }

    struct NormalizedForm: Sendable {
        let data: Data
        let names: Set<String>
        let title: String
    }

    static func normalize(_ data: Data, kind: String, enforceLimits: Bool = true) throws -> NormalizedForm {
        guard kinds.contains(kind), !data.isEmpty, (!enforceLimits || data.count <= maximumFormBytes),
              var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InventoryHandoffError.invalidForm
        }
        // Die Empfängerview darf erst nach einer vollständig dekodierbaren Form ersetzt
        // werden. Unbekannte zusätzliche Felder bleiben für spätere Appversionen erhalten.
        if kind == "box" { _ = try JSONDecoder().decode(BoxForm.self, from: data) }
        else { _ = try JSONDecoder().decode(QuickForm.self, from: data) }
        if let assigned = object["assignedBoxes"] as? [String] { object["assignedBoxes"] = assigned.sorted() }
        var names = object["imageFileNames"] as? [String] ?? []
        if let name = object["locationImageFileName"] as? String { names.append(name) }
        if let name = object["pendingNewItemImageFileName"] as? String { names.append(name) }
        for item in object["items"] as? [[String: Any]] ?? [] { names += item["images"] as? [String] ?? [] }
        guard !enforceLimits || Set(names).count <= maximumPhotoCount else { throw InventoryHandoffError.tooLarge }
        for name in names { try validateName(name, kind: kind) }
        let normalized = try JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
        guard !enforceLimits || normalized.count <= maximumFormBytes else { throw InventoryHandoffError.tooLarge }
        return .init(data: normalized, names: Set(names),
            title: object[kind == "box" ? "boxName" : "title"] as? String ?? "")
    }

    static func validateName(_ name: String, kind: String) throws {
        guard kinds.contains(kind), !name.isEmpty, name.utf8.count <= 255,
              !name.contains("/"), !name.contains("\\"), !name.contains("\0"),
              name != ".", name != "..", name == URL(fileURLWithPath: name).lastPathComponent else {
            throw InventoryHandoffError.invalidPhotos
        }
        let file = URL(fileURLWithPath: name)
        if kind == "box" {
            guard name.hasPrefix("create_draft_") || name.hasPrefix("create_item_draft_"),
                  ["jpg", "jpeg", "png", "heic", "heif"].contains(file.pathExtension.lowercased()) else {
                throw InventoryHandoffError.invalidPhotos
            }
        } else {
            guard file.pathExtension.lowercased() == "jpg",
                  UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil else {
                throw InventoryHandoffError.invalidPhotos
            }
        }
    }

    static func validatePhoto(_ data: Data) throws {
        guard !data.isEmpty, data.count <= maximumPhotoBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.doubleValue > 0, height.doubleValue > 0,
              width.doubleValue * height.doubleValue <= 64_000_000,
              CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1
              ] as CFDictionary) != nil else { throw InventoryHandoffError.invalidPhotos }
    }

    private struct BoxForm: Decodable {
        let boxName: String
        let items: [Item]
        let missingitems: [String]
        let newItem: String
        let pendingNewItemImageFileName: String?
        let newmissingItem: String
        let selectedCategory: UUID?
        let newCategory: String
        let recognizedTexts: [String]
        let notes: String?
        let imageFileNames: [String]
        let pregeneratedUUID: UUID?
        let missingUUID: UUID?
    }

    private struct Item: Decodable {
        let id: UUID
        let name: String
        let box_uuid: UUID?
        let description: String?
        let images: [String]?
        let category: String
        let isFragile: Bool?
        let isHeavy: Bool?
        let tags: [String]?
        let createdAt: Date?
        let updatedAt: Date?
    }

    private struct QuickForm: Decodable {
        let title: String
        let selectedBox: UUID?
        let selectedLocation: UUID?
        let isCreatingLocation: Bool
        let newBoxName: String
        let newLocationName: String
        let pendingBoxes: [String]
        let assignedBoxes: Set<UUID>
        let locationColor: String
        let tags: [String]
        let isFragile: Bool?
        let isHeavy: Bool?
        let isCameraExpanded: Bool
        let imageFileNames: [String]
        let locationImageFileName: String?
    }
}

enum InventoryHandoffError: LocalizedError {
    case invalidForm, invalidPhotos, unsupportedVersion, tooLarge, unavailable, incomplete, timedOut, incomingPending

    var errorDescription: String? {
        switch self {
        case .invalidForm: "Die übertragenen Formulardaten konnten nicht gelesen werden."
        case .invalidPhotos: "Die Fotos des übertragenen Formulars sind ungültig oder unvollständig."
        case .unsupportedVersion: "Diese Handoff-Übertragung benötigt eine passende Appversion."
        case .tooLarge: "Das Formular enthält zu viele oder zu große Daten für Handoff."
        case .unavailable: "Das Formular ist auf dem anderen Gerät nicht mehr für Handoff verfügbar."
        case .incomplete: "Die Handoff-Übertragung wurde unterbrochen. Das bisherige Formular bleibt erhalten."
        case .timedOut: "Die Handoff-Übertragung hat zu lange gedauert. Bitte versuche es erneut."
        case .incomingPending: "Das eingehende Formular wird gerade übernommen."
        }
    }
}

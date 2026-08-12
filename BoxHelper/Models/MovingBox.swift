//
//  Model.swift
//  ios-app-test
//

import CoreImage.CIFilterBuiltins
import Foundation

struct MovingBox: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String {
        didSet {
            updatedAt = Date()
        }
    }
    /*var items_uuid: [UUID]? { // Depatched use item.box_uuid instead
        didSet {
            updatedAt = Date()
        }
    }*/
    var items: [String] { // Depatched use item.box_uuid instead
        didSet {
            updatedAt = Date()
        }
    }
    var images: [String] {
        didSet {
            updatedAt = Date()
        }
    }
    var category: String { // Depatched use location_uuid instead
        didSet {
            updatedAt = Date()
        }
    }
    var location_uuid: UUID? {
        didSet {
            updatedAt = Date()
        }
    }
    var color: String {
        didSet {
            updatedAt = Date()
        }
    }
    var tags: [String]? {
        didSet {
            updatedAt = Date()
        }
    }
    var notes: String? { // Optionales Feld für Notizen
        didSet {
            updatedAt = Date()
        }
    }
    
    var createdAt: Date // Erstellungsdatum
    var updatedAt: Date // Änderungsdatum

    // Initialisierer
    init(
        id: UUID = UUID(),
        name: String,
        //items_uuid: [UUID],
        items: [String],
        images: [String],
        category: String = "",
        location_uuid: UUID? = nil,
        color: String = colorToString(randomColor())!,
        tags: [String]? = nil, // Standardwert für Tags
        notes: String? = nil, // Standardwert für Notizen
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        //self.items_uuid = items_uuid
        self.items = items
        self.images = images
        self.category = category
        self.location_uuid = location_uuid
        self.color = color
        self.tags = tags ?? [] // Fallback auf leere Liste
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Custom Decodable init zum Setzen einer Standardfarbe und Datumswerten, falls sie fehlen
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Werte regulär decodieren
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        //self.items_uuid = try container.decodeIfPresent([UUID].self, forKey: .items_uuid) ?? []
        self.items = try container.decode([String].self, forKey: .items)
        self.images = try container.decode([String].self, forKey: .images)
        self.category = try container.decode(String.self, forKey: .category)
        self.location_uuid = try container.decodeIfPresent(UUID.self, forKey: .location_uuid)
        self.color = try container.decodeIfPresent(String.self, forKey: .color) ?? colorToString(randomColor())!
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? [] // Fallback auf leere Liste
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}


/*
// Funktion zum Generieren des QR-Codes von einem String
func generateQRCodeImage(from string: String) -> UIImage? {
    guard let data = string.data(using: .ascii) else { return nil }
    let filter = CIFilter.qrCodeGenerator()
    filter.setValue(data, forKey: "inputMessage")

    if let outputImage = filter.outputImage {
        let transform = CGAffineTransform(scaleX: 10, y: 10) // QR-Code skalieren
        let scaledImage = outputImage.transformed(by: transform)

        if let cgImage = CIContext().createCGImage(scaledImage, from: scaledImage.extent) {
            return UIImage(cgImage: cgImage)
        }
    }

    return nil
}
*/




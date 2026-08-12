//
//  Location.swift
//  BoxHelper
//
//  Created by HOCKULUS on 09.01.25.
//

import Foundation

struct Locations: Identifiable, Codable {
    var id = UUID() // Eindeutige ID
    var name: String { // Name des Standorts
        didSet {
            updatedAt = Date()
        }
    }
    var color: String { // Farbe als String, z.B. "red", "blue", "green"
        didSet {
            updatedAt = Date()
        }
    }
    var image: String { // Bilddateiname als String, z.B. "location_image.jpg"
        didSet {
            updatedAt = Date()
        }
    }
    var createdAt: Date // Erstellungsdatum
    var updatedAt: Date // Änderungsdatum

    // Initialisierer
    init(
        id: UUID,
        name: String = "Default",
        color: String = colorToString(randomColor())!,
        image: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.image = image
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Custom Decodable init
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.color = try container.decode(String.self, forKey: .color)
        self.image = try container.decode(String.self, forKey: .image)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

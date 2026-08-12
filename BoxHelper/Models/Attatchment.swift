//
//  Attatchment.swift
//  BoxHelper
//
//  Created by HOCKULUS on 22.07.25.
//

import Foundation

struct Attatchment: Identifiable, Codable {
    var id = UUID() // Eindeutige ID
    var name: String {
        didSet {
            updatedAt = Date()
        }
    }
    var target_uuid: UUID {
        didSet {
            updatedAt = Date()
        }
    }
    var type: String {
        didSet {
            updatedAt = Date()
        }
    }
    var content: String {
        didSet {
            updatedAt = Date()
        }
    }
    var createdAt: Date // Erstellungsdatum
    var updatedAt: Date // Änderungsdatum

    // Initialisierer
    init(
        id: UUID,
        name: String,
        target_uuid: UUID,
        type: String = "",
        content: String = "", // Standardwert für Bilder
        tags: [String]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.target_uuid = target_uuid
        self.type = type
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Custom Decodable init
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.target_uuid = try container.decode(UUID.self, forKey: .target_uuid)
        self.type = try container.decode(String.self, forKey: .type)
        self.content = try container.decode(String.self, forKey: .content)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

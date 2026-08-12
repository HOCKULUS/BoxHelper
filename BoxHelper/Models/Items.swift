//
//  Items.swift
//  BoxHelper
//
//  Created by HOCKULUS on 04.12.24.
//

import Foundation

struct Items: Identifiable, Codable {
    var id = UUID() // Eindeutige ID
    var name: String {
        didSet {
            updatedAt = Date()
        }
    }
    var box_uuid: UUID {
        didSet {
            updatedAt = Date()
        }
    }
    var description: String? {
        didSet {
            updatedAt = Date()
        }
    }
    var images: [String] { // Array für Bilder
        didSet {
            updatedAt = Date()
        }
    }
    var category: String {
        didSet {
            updatedAt = Date()
        }
    }
    var isFragile: Bool {
        didSet {
            updatedAt = Date()
        }
    }
    var isHeavy: Bool {
        didSet {
            updatedAt = Date()
        }
    }
    var tags: [String]? {
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
        box_uuid: UUID,
        description: String? = nil,
        images: [String] = [], // Standardwert für Bilder
        category: String = "",
        isFragile: Bool = false,
        isHeavy: Bool = false,
        tags: [String]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.box_uuid = box_uuid
        self.description = description
        self.images = images
        self.category = category
        self.isFragile = isFragile
        self.isHeavy = isFragile
        self.tags = tags ?? []
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Custom Decodable init
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.box_uuid = try container.decode(UUID.self, forKey: .box_uuid)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.images = try container.decodeIfPresent([String].self, forKey: .images) ?? []
        self.category = try container.decode(String.self, forKey: .category)
        self.isFragile = try container.decodeIfPresent(Bool.self, forKey: .isFragile) ?? false
        self.isHeavy = try container.decodeIfPresent(Bool.self, forKey: .isHeavy) ?? false
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

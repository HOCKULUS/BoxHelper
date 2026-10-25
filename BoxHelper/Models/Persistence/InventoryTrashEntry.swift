import Foundation

/// Der Papierkorb enthält Wertkopien, niemals SwiftData-Objekte. Fotos werden im
/// lokalen UserDefaults-Archiv dedupliziert und zusammen mit den Einträgen entfernt.
struct InventoryTrashEntry: Identifiable, Codable, Equatable, Sendable {
    enum Payload: Codable, Equatable, Sendable {
        case box(MovingBox)
        case item(Items)
        case location(Locations)
        case image(String, [PhotoLink])
    }

    struct PhotoLink: Codable, Equatable, Sendable {
        enum Owner: Codable, Equatable, Sendable { case box(UUID), item(UUID), location(UUID) }
        let owner: Owner
        let index: Int
    }

    enum Source: String, Codable, Sendable { case local, cloud }
    let id: UUID
    let deletedAt: Date
    let source: Source
    let payload: Payload

    init(payload: Payload, source: Source, deletedAt: Date) {
        self.id = UUID()
        self.payload = payload
        self.source = source
        self.deletedAt = deletedAt
    }

    init(id: UUID, deletedAt: Date, source: Source, payload: Payload) {
        self.id = id
        self.deletedAt = deletedAt
        self.source = source
        self.payload = payload
    }

    var key: String {
        switch payload {
        case .box(let value): "box:\(value.id)"
        case .item(let value): "item:\(value.id)"
        case .location(let value): "location:\(value.id)"
        case .image(let name, _): "image:\(name.lowercased())"
        }
    }

    var name: String {
        switch payload {
        case .box(let value): value.name
        case .item(let value): value.name
        case .location(let value): value.name
        case .image(let name, _): name
        }
    }

    var symbol: String {
        switch payload {
        case .box: "shippingbox.fill"
        case .item: "square.grid.2x2.fill"
        case .location: "mappin.and.ellipse"
        case .image: "photo.fill"
        }
    }

    var images: [String] {
        switch payload {
        case .box(let value): value.images
        case .item(let value): value.images
        case .location(let value): value.image.isEmpty ? [] : [value.image]
        case .image(let name, _): [name]
        }
    }
}

extension Notification.Name {
    static let inventoryTrashDidChange = Notification.Name("inventoryTrashDidChange")
    static let inventoryTrashLocalDeletion = Notification.Name("inventoryTrashLocalDeletion")
}

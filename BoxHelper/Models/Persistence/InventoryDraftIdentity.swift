import CryptoKit
import Foundation

/// Ein auf zwei Geräten abgeschlossener Entwurf erhält dieselben Objekt-UUIDs.
/// Auch ein Abbruch nach dem Inventar-Commit kann dadurch keine Kopien erzeugen.
enum InventoryDraftIdentity {
    static func component(_ name: String, of draftID: UUID) -> UUID {
        var bytes = Array(SHA256.hash(data: Data((draftID.uuidString + "/" + name).utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x80
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    static func isCompleted(_ id: UUID, kind: String, in inventory: InventorySnapshot) -> Bool {
        switch kind {
        case "item": inventory.items.contains { $0.id == id }
        case "location": inventory.locations.contains { $0.id == id }
        case "box": inventory.boxes.contains { $0.id == id }
        default: false
        }
    }
}

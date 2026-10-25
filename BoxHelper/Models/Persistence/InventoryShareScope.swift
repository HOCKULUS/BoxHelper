import Foundation

extension Notification.Name {
    static let inventoryShareAccepted = Notification.Name("inventoryShareAccepted")
}

/// Die Freigabe speichert Wurzel-UUIDs, keine veraltete Liste von Kindobjekten.
/// Neue Items in einer geteilten Kiste und neue Kisten am geteilten Standort folgen mit.
struct InventoryShareScope: Codable, Equatable, Sendable {
    enum Kind: String, Codable, CaseIterable { case inventory, locations, boxes }
    var kind: Kind
    var roots: Set<UUID>
    enum Access: String, Codable { case readOnly, readWrite }
    // Optionale Felder erhalten bestehende Freigaben und lokale Sync-Checkpoints.
    var access: Access? = nil
    var includeImages: Bool? = nil
    var allowsEditing: Bool { access != .readOnly }
    var sharesImages: Bool { allowsEditing || includeImages != false }

    func select(from inventory: InventorySnapshot, isOwner: Bool,
                knownIDs: Set<String> = [], newIDs: Set<String> = []) -> InventorySnapshot {
        switch kind {
        case .inventory:
            if isOwner { return inventory }
            // Bereits vorhandene private Daten eines eingeladenen Nutzers werden niemals
            // automatisch hochgeladen. Neue unabhängige Daten benötigen seine Zuordnung.
            let allowed = knownIDs.union(newIDs)
            let locations = inventory.locations.filter { allowed.contains("location-\($0.id)") }
            let locationIDs = Set(locations.map(\.id))
            let boxes = inventory.boxes.filter {
                allowed.contains("box-\($0.id)") || $0.location_uuid.map(locationIDs.contains) == true
            }
            let boxIDs = Set(boxes.map(\.id))
            let items = inventory.items.filter {
                allowed.contains("item-\($0.id)") || $0.box_uuid.map(boxIDs.contains) == true
            }
            return InventorySnapshot(boxes: boxes, items: items, locations: locations)
        case .locations:
            let locations = inventory.locations.filter { roots.contains($0.id) }
            let boxes = inventory.boxes.filter { $0.location_uuid.map(roots.contains) == true }
            let boxIDs = Set(boxes.map(\.id))
            return InventorySnapshot(boxes: boxes, items: inventory.items.filter { $0.box_uuid.map(boxIDs.contains) == true }, locations: locations)
        case .boxes:
            return InventorySnapshot(boxes: inventory.boxes.filter { roots.contains($0.id) },
                                     items: inventory.items.filter { $0.box_uuid.map(roots.contains) == true }, locations: [])
        }
    }
}

struct InventoryShareDescriptor: Codable, Equatable, Identifiable, Sendable {
    var zoneName: String
    var ownerName: String
    var isOwner: Bool
    var title: String
    var scope: InventoryShareScope
    var canEdit: Bool
    var isAvailable: Bool = true
    var participants: [InventoryShareParticipant]? = nil

    var statusDescription: String {
        guard isAvailable else { return "Freigabe beendet" }
        guard isOwner else { return "Angenommen" }
        let accepted = participants?.filter { $0.accepted }.count ?? 0
        let pending = participants?.filter { !$0.accepted }.count ?? 0
        if accepted > 0 && pending > 0 { return "\(accepted) angenommen, \(pending) ausstehend" }
        if accepted > 0 { return "\(accepted) angenommen" }
        return pending > 0 ? "\(pending) ausstehend" : "Einladung ausstehend"
    }
    var id: String { ownerName + "/" + zoneName }
}

/// Teilnehmerstatus stammt aus CKShare und ist damit auf allen Geräten gleich.
struct InventoryShareParticipant: Codable, Equatable, Sendable {
    var name: String
    var accepted: Bool
    var canEdit: Bool
}

/// CKRecord-Systemfelder enthalten den Change-Tag für optimistische Schreibkonflikte.
/// Fotos werden als CKAsset transportiert und nie in einen großen Inventar-JSON gepackt.
struct InventorySharedRecord: Codable, Equatable, Sendable {
    var name: String
    var kind: String
    var body: Data?
    var photo: Data?
    var filename: String?
    var isDeleted = false
    var changedAt: Date = Date()
    var systemFields: Data?
}

enum InventorySharingError: LocalizedError {
    case disabled, emptySelection, overlappingShare, existingShare, readOnly, invalidData, conflict, accountChanged
    var errorDescription: String? {
        switch self {
        case .disabled: "Aktiviere iCloud und starte die App neu, um Daten gemeinsam zu bearbeiten."
        case .emptySelection: "Wähle mindestens einen Standort oder eine Kiste aus."
        case .overlappingShare: "Diese Daten gehören bereits zu einer Freigabe. Verwalte die bestehende Freigabe."
        case .existingShare: "Du hast bereits eine aktive Freigabe. Beende sie, um eine neue zu erstellen."
        case .readOnly: "Für diese Freigabe hast du keine Bearbeitungsrechte."
        case .invalidData: "Die Freigabe enthält ungültige Daten. Deine lokalen Daten bleiben erhalten."
        case .conflict: "Die Daten wurden gleichzeitig geändert. Der Abgleich wird erneut versucht."
        case .accountChanged: "Der iCloud-Account hat sich geändert. Starte die App neu, bevor du Freigaben öffnest."
        }
    }
}

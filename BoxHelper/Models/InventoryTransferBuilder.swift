import Foundation

/// Baut vollständige, selbsttragende Auswahl-Archive für die vier Bestandslisten.
enum InventoryTransferBuilder {
    static func boxes(_ selected: [MovingBox], allItems: [Items], allLocations: [Locations]) -> InventoryTransfer {
        let boxIDs = Set(selected.map(\.id))
        let items = allItems.filter { item in
            guard let boxID = item.box_uuid else { return false }
            return boxIDs.contains(boxID)
        }
        let locationIDs = Set(selected.compactMap(\.location_uuid))
        let locations = allLocations.filter { locationIDs.contains($0.id) }
        return InventoryTransfer(kind: .boxes, boxes: selected, items: items, locations: locations)
    }

    static func items(_ selected: [Items], allBoxes: [MovingBox], allLocations: [Locations]) -> InventoryTransfer {
        let boxIDs = Set(selected.compactMap(\.box_uuid))
        let boxes = allBoxes.filter { boxIDs.contains($0.id) }
        let locationIDs = Set(boxes.compactMap(\.location_uuid))
        let locations = allLocations.filter { locationIDs.contains($0.id) }
        return InventoryTransfer(kind: .items, boxes: boxes, items: selected, locations: locations)
    }

    static func locations(_ selected: [Locations], allBoxes: [MovingBox], allItems: [Items]) -> InventoryTransfer {
        let locationIDs = Set(selected.map(\.id))
        let boxes = allBoxes.filter { box in
            guard let locationID = box.location_uuid else { return false }
            return locationIDs.contains(locationID)
        }
        let boxIDs = Set(boxes.map(\.id))
        let items = allItems.filter { item in
            guard let boxID = item.box_uuid else { return false }
            return boxIDs.contains(boxID)
        }
        return InventoryTransfer(kind: .locations, boxes: boxes, items: items, locations: selected)
    }

    static func images(_ selected: [TransferImage]) -> InventoryTransfer {
        InventoryTransfer(kind: .images, images: selected)
    }
}

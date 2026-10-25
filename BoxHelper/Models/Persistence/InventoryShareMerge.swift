import Foundation

/// Ein Dreiwegevergleich überträgt nur lokal bearbeitete Felder. Der unveränderte
/// Ausgangsstand bleibt bis zur Serverbestätigung erhalten, auch über Offline-Neustarts.
enum InventoryShareMerge {
    /// Nur die Eltern-UUID wird gespeichert, kein gelöschter Nutzinhalt. Damit kann
    /// eine später eintreffende Verschiebung eine abgeleitete Kaskade korrigieren.
    private struct CascadeCause: Codable { let deletedBox: UUID }
    /// Mitgliedschaft benötigt nur Identitäten, keine JSON-Payloads aller Objekte.
    static func identifiers(in inventory: InventorySnapshot) -> Set<String> {
        Set(inventory.boxes.map { "box-\($0.id)" }
            + inventory.items.map { "item-\($0.id)" }
            + inventory.locations.map { "location-\($0.id)" })
    }
    static func records(_ inventory: InventorySnapshot) throws -> [String: InventorySharedRecord] {
        var result: [String: InventorySharedRecord] = [:]
        for box in inventory.boxes { let record = try record(box, kind: "box", id: box.id, date: box.updatedAt); result[record.name] = record }
        for item in inventory.items { let record = try record(item, kind: "item", id: item.id, date: item.updatedAt); result[record.name] = record }
        for location in inventory.locations { let record = try record(location, kind: "location", id: location.id, date: location.updatedAt); result[record.name] = record }
        return result
    }

    static func merge(base: InventorySharedRecord?, local: InventorySharedRecord?,
                      remote: InventorySharedRecord?) throws -> InventorySharedRecord? {
        guard let base else {
            guard let remote else { return local }
            guard let local, !remote.isDeleted else { return remote }
            return local.changedAt > remote.changedAt ? withServerVersion(local, remote: remote) : remote
        }
        let server = remote ?? base
        if base.isDeleted {
            guard let local else { return server }
            // Eine explizite Wiederherstellung, etwa per Import, darf Tombstones ersetzen.
            return withServerVersion(local, remote: server)
        }
        if server.isDeleted {
            if server.kind == "item", let body = server.body,
               let cause = try? JSONDecoder().decode(CascadeCause.self, from: body) {
                if let local {
                    let item: Items = try decode(local)
                    if item.box_uuid != cause.deletedBox {
                        // Das Item ist inzwischen unzugeordnet oder in einer anderen
                        // Kiste. Diese Bewegung darf die Eltern-Kaskade überholen.
                        return withServerVersion(local, remote: server)
                    }
                } else {
                    let previous: Items = try decode(base)
                    if previous.box_uuid != cause.deletedBox {
                        // Das zuvor schon verschobene Item wurde ausdrücklich lokal
                        // gelöscht. Diesen neuen Befehl nicht als alte Kaskade behalten.
                        var explicit = server
                        explicit.body = nil
                        explicit.changedAt = max(Date(), server.changedAt.addingTimeInterval(0.001))
                        return explicit
                    }
                }
            }
            return server
        }
        guard let local else {
            var deleted = server
            deleted.body = nil; deleted.photo = nil; deleted.isDeleted = true
            deleted.changedAt = max(Date(), server.changedAt.addingTimeInterval(0.001))
            return deleted
        }
        if local.body == base.body { return server }
        var result = server
        switch local.kind {
        case "box":
            let old: MovingBox = try decode(base); let edited: MovingBox = try decode(local); let latest: MovingBox = try decode(server)
            result.body = try encode(InventoryFieldChanges.boxes(from: [old], to: [edited], in: [latest])[0])
        case "item":
            let old: Items = try decode(base); let edited: Items = try decode(local); let latest: Items = try decode(server)
            result.body = try encode(InventoryFieldChanges.items(from: [old], to: [edited], in: [latest])[0])
        case "location":
            let old: Locations = try decode(base); let edited: Locations = try decode(local); let latest: Locations = try decode(server)
            result.body = try encode(InventoryFieldChanges.locations(from: [old], to: [edited], in: [latest])[0])
        default: throw InventorySharingError.invalidData
        }
        if result.body != server.body { result.changedAt = max(Date(), server.changedAt.addingTimeInterval(0.001)) }
        return result
    }

    /// UUID-Felder sind keine SwiftData-Beziehungen. Diese Domänenregeln halten die
    /// Freigabe deshalb auch bei alten Löschfehlern und verspäteten Kindern konsistent.
    /// Ein lediglich fehlender Eltern-Datensatz gilt ausdrücklich nicht als gelöscht.
    static func repairDeletedParents(in records: [String: InventorySharedRecord]) throws -> [String: InventorySharedRecord] {
        var result = records
        let deletedBoxes = try Dictionary(uniqueKeysWithValues: records.values.filter { $0.kind == "box" && $0.isDeleted }.map {
            (try identity($0), $0.changedAt)
        })
        let deletedLocations = try Set(records.values.filter { $0.kind == "location" && $0.isDeleted }.map(identity))
        for (name, var record) in records where !record.isDeleted {
            switch record.kind {
            case "item":
                let item: Items = try decode(record)
                guard let boxID = item.box_uuid, let causeRevision = deletedBoxes[boxID] else { continue }
                record.isDeleted = true
                record.body = try encode(CascadeCause(deletedBox: boxID))
                record.photo = nil
                record.changedAt = max(record.changedAt, causeRevision)
            case "box":
                var box: MovingBox = try decode(record)
                guard let locationID = box.location_uuid, deletedLocations.contains(locationID) else { continue }
                box.location_uuid = nil
                record.body = try encode(box)
                record.changedAt = max(Date(), record.changedAt.addingTimeInterval(0.001))
            default: continue
            }
            result[name] = record
        }
        return result
    }

    /// Nur UUIDs aus der Freigabe verändern. Bei einem Herausverschieben bleibt das
    /// private Objekt auf diesem Gerät erhalten, während die Freigabe einen Tombstone erhält.
    static func apply(_ records: [InventorySharedRecord], to inventory: InventorySnapshot,
                      preserving excluded: Set<String>) throws -> InventorySnapshot {
        var result = inventory
        for record in records where !excluded.contains(record.name) {
            switch record.kind {
            case "box":
                let id = try identity(record)
                result.boxes.removeAll { $0.id == id }
                if !record.isDeleted { let value: MovingBox = try decode(record); guard value.id == id else { throw InventorySharingError.invalidData }; result.boxes.append(value) }
            case "item":
                let id = try identity(record)
                result.items.removeAll { $0.id == id }
                if !record.isDeleted { let value: Items = try decode(record); guard value.id == id else { throw InventorySharingError.invalidData }; result.items.append(value) }
            case "location":
                let id = try identity(record)
                result.locations.removeAll { $0.id == id }
                if !record.isDeleted { let value: Locations = try decode(record); guard value.id == id else { throw InventorySharingError.invalidData }; result.locations.append(value) }
            default: break
            }
        }
        // Serverlisten enthalten keine Geräte-Sortierung. Vorhandene Objekte behalten ihre Plätze.
        result.boxes = ordered(result.boxes, like: inventory.boxes)
        result.items = ordered(result.items, like: inventory.items)
        result.locations = ordered(result.locations, like: inventory.locations)
        return result
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return try encoder.encode(value)
    }

    static func photos(in inventory: InventorySnapshot) -> Set<String> {
        Set(inventory.boxes.flatMap(\.images) + inventory.items.flatMap(\.images) + inventory.locations.map(\.image).filter { !$0.isEmpty })
    }

    static func select(_ inventory: InventorySnapshot, names: Set<String>) -> InventorySnapshot {
        InventorySnapshot(boxes: inventory.boxes.filter { names.contains("box-\($0.id)") },
                          items: inventory.items.filter { names.contains("item-\($0.id)") },
                          locations: inventory.locations.filter { names.contains("location-\($0.id)") })
    }

    private static func identity(_ record: InventorySharedRecord) throws -> UUID {
        guard record.name.hasPrefix(record.kind + "-"), let id = UUID(uuidString: String(record.name.dropFirst(record.kind.count + 1))) else { throw InventorySharingError.invalidData }
        return id
    }
    private static func decode<T: Decodable>(_ record: InventorySharedRecord) throws -> T {
        guard let data = record.body else { throw InventorySharingError.invalidData }
        return try JSONDecoder().decode(T.self, from: data)
    }
    private static func record<T: Encodable>(_ value: T, kind: String, id: UUID, date: Date) throws -> InventorySharedRecord {
        InventorySharedRecord(name: "\(kind)-\(id)", kind: kind, body: try encode(value), changedAt: date)
    }
    private static func withServerVersion(_ local: InventorySharedRecord, remote: InventorySharedRecord) -> InventorySharedRecord {
        var result = local; result.systemFields = remote.systemFields
        result.changedAt = max(Date(), remote.changedAt.addingTimeInterval(0.001))
        return result
    }
    private static func ordered<T: Identifiable>(_ values: [T], like old: [T]) -> [T] where T.ID == UUID {
        let order = Dictionary(uniqueKeysWithValues: old.enumerated().map { ($0.element.id, $0.offset) })
        return values.sorted { (order[$0.id] ?? Int.max, $0.id.uuidString) < (order[$1.id] ?? Int.max, $1.id.uuidString) }
    }
}

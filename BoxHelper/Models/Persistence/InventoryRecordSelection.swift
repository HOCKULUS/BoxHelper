import Foundation

/// Deterministische UUID-Auswahl ohne JSON-Codierung eindeutiger Datensätze.
/// Die Modelle verlassen den Context ihres Aufrufers nicht.
enum InventoryRecordSelection {
    static func winners<Record: InventoryRecord>(_ records: [Record]) throws -> [Record] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var selected: [UUID: Record] = [:]
        var payloads: [UUID: Data] = [:]
        for record in records {
            if let previous = selected[record.id] {
                let candidateDate = revision(of: record)
                let previousDate = revision(of: previous)
                if candidateDate < previousDate { continue }
                if candidateDate == previousDate {
                    if record.isTombstoned != previous.isTombstoned {
                        if !record.isTombstoned { continue }
                    } else {
                        // JSON ist ausschließlich für echte Versionsgleichstände nötig.
                        // Eindeutige UUIDs werden ohne Payload-Codierung ausgewählt.
                        let oldPayload: Data
                        if let cached = payloads[record.id] { oldPayload = cached }
                        else { oldPayload = try encoder.encode(previous.value); payloads[record.id] = oldPayload }
                        let newPayload = try encoder.encode(record.value)
                        guard oldPayload.lexicographicallyPrecedes(newPayload)
                            || (oldPayload == newPayload && record.position < previous.position) else { continue }
                        payloads[record.id] = newPayload
                        selected[record.id] = record
                        continue
                    }
                }
                payloads.removeValue(forKey: record.id)
            }
            selected[record.id] = record
        }
        // Cloud-Geräte können dieselbe Listenposition vergeben; UUIDs brechen Gleichstände.
        return selected.values.sorted {
            if $0.position != $1.position { return $0.position < $1.position }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
    private static func revision<Record: InventoryRecord>(of record: Record) -> Date {
        max(record.updatedAt, record.syncChangedAt)
    }
}

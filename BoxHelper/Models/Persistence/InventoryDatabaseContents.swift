import CryptoKit
import Foundation
import SQLite3
import SwiftData

/// Vergleicht persistente Werte unabhängig von Core Datas internen Objekt-IDs.
/// Die Prüfung liest ausschließlich: Sie öffnet keinen zweiten schreibenden Store.
enum InventoryDatabaseContents {
    struct Table {
        let columns: [String]
        let rows: [Data]
    }
    typealias Snapshot = [String: Table]

    private struct PreferenceIdentity: Hashable {
        let key: String
        let date: Date
        let isDeleted: Bool
    }

    /// Lightweight Migration kann ein SQL-NULL beim Wechsel zu External Storage als
    /// leeres Data materialisieren. Die Altquelle bestimmt, welche Werte wirklich nil
    /// waren. Der anschließende vollständige Vergleich prüft auch diese Korrektur.
    @MainActor
    static func restoreNilPreferences(in context: ModelContext, from source: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open_v2(source.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            if let database { sqlite3_close(database) }
            throw CheckError.unreadable
        }
        defer { sqlite3_close(database) }
        let tables = try columns(of: "ZSTOREDCLOUDPREFERENCE", database: database)
        guard Set(["ZKEY", "ZUPDATEDAT", "ZISDELETED", "ZVALUE"]).isSubset(of: Set(tables)) else { return }
        var statement: OpaquePointer?
        let sql = "SELECT ZKEY, ZUPDATEDAT, ZISDELETED FROM ZSTOREDCLOUDPREFERENCE WHERE ZVALUE IS NULL"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { throw CheckError.unreadable }
        defer { sqlite3_finalize(statement) }
        var missing: [PreferenceIdentity: Int] = [:]
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { break }
            guard status == SQLITE_ROW, let key = sqlite3_column_text(statement, 0) else { throw CheckError.unreadable }
            let identity = PreferenceIdentity(key: String(cString: key),
                date: Date(timeIntervalSinceReferenceDate: sqlite3_column_double(statement, 1)),
                isDeleted: sqlite3_column_int64(statement, 2) != 0)
            missing[identity, default: 0] += 1
        }
        let records = try context.fetch(FetchDescriptor<InventorySchemaV3.StoredCloudPreference>())
        // Bereits korrekt gelesene NULLs zuerst zuordnen; danach nur leere Werte ändern.
        for record in records.sorted(by: { $0.value == nil && $1.value != nil }) {
            let identity = PreferenceIdentity(key: record.key, date: record.updatedAt, isDeleted: record.isDeleted)
            guard let remaining = missing[identity], remaining > 0,
                  record.value == nil || record.value?.isEmpty == true else { continue }
            if record.value != nil { record.value = nil }
            missing[identity] = remaining - 1
        }
        if context.hasChanges { try context.save() }
    }

    static func capture(at url: URL, entities: Set<String>, matching original: Snapshot? = nil) throws -> Snapshot {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            if let database { sqlite3_close(database) }
            throw CheckError.unreadable
        }
        defer { sqlite3_close(database) }
        // Alle Tabellen stammen aus demselben Lesesnapshot, auch wenn ein anderer
        // Prozess zwischenzeitlich eine SQLite-Transaktion bestätigt.
        guard sqlite3_exec(database, "BEGIN DEFERRED TRANSACTION", nil, nil, nil) == SQLITE_OK else { throw CheckError.unreadable }
        defer { sqlite3_exec(database, "ROLLBACK", nil, nil, nil) }
        var result: Snapshot = [:]
        for entity in entities.sorted() {
            let name = "Z" + entity.uppercased()
            let available = try columns(of: name, database: database)
            let selected = original?[entity]?.columns ?? available.filter { !["Z_PK", "Z_ENT", "Z_OPT"].contains($0) }
            guard !selected.isEmpty, Set(selected).isSubset(of: Set(available)) else { throw CheckError.changedFields }
            let sql = "SELECT " + selected.map(quoted).joined(separator: ",") + " FROM " + quoted(name)
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { throw CheckError.unreadable }
            defer { sqlite3_finalize(statement) }
            var rows: [Data] = []
            while true {
                let status = sqlite3_step(statement)
                if status == SQLITE_DONE { break }
                guard status == SQLITE_ROW else { throw CheckError.unreadable }
                var row = Data()
                for column in selected.indices { appendValue(statement, column: Int32(column), to: &row) }
                rows.append(Data(SHA256.hash(data: row)))
            }
            result[entity] = Table(columns: selected, rows: rows.sorted { $0.lexicographicallyPrecedes($1) })
        }
        return result
    }

    static func requireEqual(_ original: Snapshot, _ migrated: Snapshot,
                             plainPreferences: Table? = nil) throws {
        guard original.keys.sorted() == migrated.keys.sorted(), original.allSatisfy({ key, value in
            if migrated[key]?.columns == value.columns && migrated[key]?.rows == value.rows { return true }
            // Der frühere Preference-BLOB war normales Data. External Storage ergänzt
            // Speicherkennungen, selbst wenn der fachliche Inhalt unverändert bleibt.
            // Nur diese bekannte Umstellung darf alternativ mit decodierten Werten
            // verglichen werden; sämtliche übrigen Spalten und Zeilen bleiben exakt.
            return key == "StoredCloudPreference" && plainPreferences?.columns == value.columns
                && plainPreferences?.rows == value.rows
        }) else { throw CheckError.changedValues }
    }

    @MainActor
    static func capturePlainPreferences(in context: ModelContext) throws -> Table {
        let columns = ["ZISDELETED", "ZKEY", "ZUPDATEDAT", "ZVALUE"]
        let rows = try context.fetch(FetchDescriptor<InventorySchemaV3.StoredCloudPreference>()).map { record in
            var row = Data()
            row.append(UInt8(SQLITE_INTEGER))
            appendInteger(Int64(record.isDeleted ? 1 : 0), to: &row)
            appendBytes(Data(record.key.utf8), type: SQLITE_TEXT, to: &row)
            row.append(UInt8(SQLITE_FLOAT))
            appendInteger(record.updatedAt.timeIntervalSinceReferenceDate.bitPattern, to: &row)
            if let value = record.value { appendBytes(value, type: SQLITE_BLOB, to: &row) }
            else { row.append(UInt8(SQLITE_NULL)) }
            return Data(SHA256.hash(data: row))
        }
        return Table(columns: columns, rows: rows.sorted { $0.lexicographicallyPrecedes($1) })
    }

    private static func columns(of table: String, database: OpaquePointer?) throws -> [String] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA table_info(" + quoted(table) + ")", -1, &statement, nil) == SQLITE_OK else {
            throw CheckError.unreadable
        }
        defer { sqlite3_finalize(statement) }
        var result: [String] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return result.sorted() }
            guard status == SQLITE_ROW, let name = sqlite3_column_text(statement, 1) else { throw CheckError.unreadable }
            result.append(String(cString: name))
        }
    }

    private static func appendValue(_ statement: OpaquePointer?, column: Int32, to row: inout Data) {
        let type = sqlite3_column_type(statement, column)
        row.append(UInt8(type))
        switch type {
        case SQLITE_INTEGER:
            appendInteger(sqlite3_column_int64(statement, column), to: &row)
        case SQLITE_FLOAT:
            appendInteger(sqlite3_column_double(statement, column).bitPattern, to: &row)
        case SQLITE_TEXT, SQLITE_BLOB:
            appendInteger(UInt64(sqlite3_column_bytes(statement, column)), to: &row)
            if let bytes = sqlite3_column_blob(statement, column) {
                row.append(Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, column))))
            }
        default: break // NULL hat bereits eine eigene Typmarkierung.
        }
    }

    private static func appendInteger<T: FixedWidthInteger>(_ value: T, to row: inout Data) {
        var bytes = value.littleEndian
        withUnsafeBytes(of: &bytes) { row.append(contentsOf: $0) }
    }

    private static func appendBytes(_ value: Data, type: Int32, to row: inout Data) {
        row.append(UInt8(type))
        appendInteger(UInt64(value.count), to: &row)
        row.append(value)
    }

    private static func quoted(_ name: String) -> String { "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
    private enum CheckError: LocalizedError {
        case unreadable, changedFields, changedValues
        var errorDescription: String? {
            switch self {
            case .unreadable: "Die vorhandene Datenbank konnte nicht vollständig geprüft werden."
            case .changedFields: "Die Migration würde vorhandene Datenfelder entfernen."
            case .changedValues: "Die Migration hat vorhandene Daten verändert; sie wurde nicht übernommen."
            }
        }
    }
}

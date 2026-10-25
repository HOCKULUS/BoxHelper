import Combine
import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

extension Notification.Name {
    static let resumeInventoryDraft = Notification.Name("resumeInventoryDraft")
    static let inventoryDraftsDidChange = Notification.Name("inventoryDraftsDidChange")
    static let inventoryDraftWillResume = Notification.Name("inventoryDraftWillResume")
}

struct InventoryFormDraftSummary: Identifiable {
    let id: UUID
    let kind: String
    let title: String
    let deviceName: String
    let updatedAt: Date
}

enum InventoryDraftError: LocalizedError {
    case invalidPhoto, missingPhoto(String), unavailable
    var errorDescription: String? {
        switch self {
        case .invalidPhoto: "Der Entwurf enthält einen ungültigen Bilddateinamen."
        case .missingPhoto(let name): "Ein Entwurfsfoto ist noch nicht verfügbar: \(name). Der bisherige Entwurf bleibt erhalten."
        case .unavailable: "Dieser Entwurf ist nicht mehr verfügbar."
        }
    }
}

/// Pro Gerät und Formular wird eine aktive Entwurfs-ID gehalten. Andere Geräte dürfen
/// eigene Entwürfe anlegen; beim Fortsetzen wird die ausgewählte ID ausdrücklich übernommen.
@MainActor
final class InventoryFormDraftStore: ObservableObject {
    static let shared = InventoryFormDraftStore(container: { try InventoryPersistence.prepare().container })
    @Published private(set) var revision = 0
    private let container: () throws -> ModelContainer
    private let defaults: UserDefaults
    private let documents: URL
    private let deviceID: String
    private let deviceName: String
    private let didSave: () -> Void
    private var loadedVersions: [UUID: Date] = [:]

    init(container: @escaping () throws -> ModelContainer, defaults: UserDefaults = .standard,
         documents: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
         deviceID: String? = nil, deviceName: String? = nil, didSave: @escaping () -> Void = {}) {
        self.container = container
        self.defaults = defaults
        self.documents = documents
        self.deviceID = deviceID ?? Self.installationID()
#if canImport(UIKit)
        self.deviceName = deviceName ?? UIDevice.current.name
#else
        self.deviceName = deviceName ?? Host.current().localizedName ?? "Gerät"
#endif
        self.didSave = didSave
    }

    func summaries() throws -> [InventoryFormDraftSummary] {
        let context = ModelContext(try container())
        if try InventoryLegacyDraftUpgrade.migrate(in: context) { publish() }
        return try winners(in: context).values.filter { !$0.isTombstoned && $0.payload != nil }
            .sorted { $0.updatedAt == $1.updatedAt ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt > $1.updatedAt }
            .map { InventoryFormDraftSummary(id: $0.id, kind: $0.kind, title: $0.title,
                                            deviceName: $0.deviceName, updatedAt: $0.updatedAt) }
    }

    func load(kind: String) throws -> Data? {
        let context = ModelContext(try container())
        if try InventoryLegacyDraftUpgrade.migrate(in: context) { publish() }
        guard let id = activeID(kind), let record = try winners(in: context)[id],
              !record.isTombstoned, let payload = record.payload else { return nil }
        guard try normalize(form: payload, kind: kind).names == Set(record.photoNames) else { throw InventoryDraftError.invalidPhoto }
        try InventoryDraftMedia.materialize(names: record.photoNames, draftID: id, context: context,
                                           url: { try self.photoURL($0, kind: kind) })
        loadedVersions[id] = record.updatedAt
        return payload
    }

    /// Beim automatischen Fortsetzen wird der neueste bereits vollständig verfügbare
    /// Formularstand gewählt. Fotos werden vor dem Wechsel der aktiven ID geprüft.
    func loadLatest(kind: String) throws -> (id: UUID, form: Data, updatedAt: Date)? {
        let context = ModelContext(try container())
        if try InventoryLegacyDraftUpgrade.migrate(in: context) { publish() }
        guard let record = try winners(in: context).values
            .filter({ $0.kind == kind && !$0.isTombstoned && $0.payload != nil })
            .sorted(by: { $0.updatedAt == $1.updatedAt ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt > $1.updatedAt })
            .first, let payload = record.payload else { return nil }
        guard try normalize(form: payload, kind: kind).names == Set(record.photoNames) else {
            throw InventoryDraftError.invalidPhoto
        }
        try InventoryDraftMedia.materialize(names: record.photoNames, draftID: record.id, context: context,
                                           url: { try self.photoURL($0, kind: kind) })
        defaults.set(record.id.uuidString, forKey: pointerKey(kind))
        loadedVersions[record.id] = record.updatedAt
        return (record.id, payload, record.updatedAt)
    }

    @discardableResult
    func save(form: Data, kind: String, preferredID: UUID? = nil) throws -> (id: UUID, updatedAt: Date) {
        let normalized = try normalize(form: form, kind: kind)
        let context = ModelContext(try container())
        context.autosaveEnabled = false
        // Die laufende Handoff-Sitzung und der Cloud-Entwurf teilen dieselbe Identität.
        let selectedID = preferredID ?? activeID(kind)
        var id = selectedID ?? UUID()
        let requestedID = id
        let records = try context.fetch(FetchDescriptor<StoredFormDraft>(
            predicate: #Predicate { $0.id == requestedID }))
        let latest = winners(records)[id]
        let state = try InventoryDeletionLedger.states(in: context, kind: "draft", keys: [id.uuidString])[id.uuidString]
        let deletion = state?.isDeleted == true ? state?.deletedAt : nil
        let outdated = latest.map { $0.updatedAt <= (state?.deletedAt ?? .distantPast) } ?? false
        if deletion == nil, !outdated, let latest, !latest.isTombstoned, latest.payload == normalized.form {
            defaults.set(id.uuidString, forKey: pointerKey(kind))
            loadedVersions[id] = latest.updatedAt
            return (id, latest.updatedAt)
        }

        // Ein inzwischen auf einem anderen Gerät veränderter/abgeschlossener Entwurf
        // wird nicht überschrieben. Die noch offene lokale Eingabe erhält eine eigene ID.
        let missingKnownDraft = latest == nil && selectedID != nil
            && (preferredID == nil || loadedVersions[id] != nil || activeID(kind) == id)
        if deletion != nil || outdated || missingKnownDraft { id = UUID() }
        else if let latest, latest.isTombstoned || loadedVersions[id] == nil
            || loadedVersions[id].map({ latest.updatedAt > $0 }) == true { id = UUID() }
        let title = try formTitle(form, kind: kind)
        let matching = records.filter { $0.id == id }
        let version = InventoryDeletionLedger.nextVersion(after: matching.map(\.updatedAt))
        try InventoryDraftMedia.save(names: normalized.names, draftID: id, version: version, context: context,
                                    url: { try self.photoURL($0, kind: kind) })
        if matching.isEmpty {
            let record = StoredFormDraft(id: id, kind: kind, title: title, deviceID: deviceID,
                                         deviceName: deviceName, payload: normalized.form)
            record.updatedAt = version
            record.photoNames = normalized.names.sorted()
            context.insert(record)
        } else {
            for record in matching {
                record.payload = normalized.form; record.photoNames = normalized.names.sorted()
                record.title = title; record.deviceID = deviceID
                record.deviceName = deviceName; record.updatedAt = version; record.isTombstoned = false
            }
        }
        do { try context.save() } catch { context.rollback(); throw error }
        defaults.set(id.uuidString, forKey: pointerKey(kind))
        loadedVersions[id] = version
        publish()
        return (id, version)
    }

    func clear(kind: String) throws {
        guard let id = activeID(kind) else { return }
        try delete(id: id)
        defaults.removeObject(forKey: pointerKey(kind))
    }

    func delete(id: UUID) throws {
        let context = ModelContext(try container())
        context.autosaveEnabled = false
        let records = try context.fetch(FetchDescriptor<StoredFormDraft>(
            predicate: #Predicate { $0.id == id }))
        let previous = try InventoryDeletionLedger.states(in: context, kind: "draft", keys: [id.uuidString])[id.uuidString]
        let version = InventoryDeletionLedger.nextVersion(after: records.map(\.updatedAt) + [previous?.revision ?? .distantPast])
        // Die Formularzeile wird wirklich gelöscht. Die kleine UUID-Historie schützt
        // weiterhin vor verspäteten Cloud-Duplikaten und noch geöffneten Formularen.
        try InventoryDeletionLedger.recordDeletion(kind: "draft", key: id.uuidString, at: version, in: context)
        for record in records { context.delete(record) }
        try InventoryDraftMedia.delete(draftID: id, version: version, context: context)
        do { try context.save() } catch { context.rollback(); throw error }
        loadedVersions.removeValue(forKey: id)
        publish()
    }

    /// Der Aufrufer zeigt vor dem Fortsetzen den vorhandenen lokalen Entwurf an.
    /// Er bleibt als eigener Datensatz erhalten und kann später wieder gewählt werden.
    func resume(id: UUID) throws -> String {
        guard let record = try winners(in: ModelContext(container()))[id], !record.isTombstoned,
              record.payload != nil else { throw InventoryDraftError.unavailable }
        NotificationCenter.default.post(name: .inventoryDraftWillResume, object: record.kind)
        let context = ModelContext(try container())
        guard let latest = try winners(in: context)[id], !latest.isTombstoned,
              let payload = latest.payload else { throw InventoryDraftError.unavailable }
        guard try normalize(form: payload, kind: record.kind).names == Set(latest.photoNames) else { throw InventoryDraftError.invalidPhoto }
        try InventoryDraftMedia.materialize(names: latest.photoNames, draftID: id, context: context,
                                           url: { try self.photoURL($0, kind: record.kind) })
        defaults.set(true, forKey: "saveCreateFormData")
        defaults.set(id.uuidString, forKey: pointerKey(record.kind))
        loadedVersions[id] = latest.updatedAt
        return record.kind
    }

    /// Erst nach dem vollständigen Datenbank-Commit wird die jeweilige Altquelle entfernt.
    func migrateLegacyDrafts() throws {
        if try InventoryLegacyDraftUpgrade.migrate(in: ModelContext(container())) { publish() }
        for kind in ["box", "item", "location"] {
            let key = kind == "box" ? "createFormDraftV1" : "create_\(kind)_form_draft_v1"
            guard var form = defaults.data(forKey: key) else { continue }
            if kind == "box", let id = defaults.string(forKey: "pregeneratedUUID"), UUID(uuidString: id) != nil,
               var object = try JSONSerialization.jsonObject(with: form) as? [String: Any], object["pregeneratedUUID"] == nil {
                object["pregeneratedUUID"] = id
                form = try JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
            }
            if activeID(kind) == nil { try save(form: form, kind: kind) }
            defaults.removeObject(forKey: key)
        }
    }

    func remoteDidChange() { revision += 1 }
    func activeDraftID(kind: String) -> UUID? { activeID(kind) }

    private func normalize(form: Data, kind: String) throws -> (form: Data, names: Set<String>) {
        guard var object = try JSONSerialization.jsonObject(with: form) as? [String: Any],
              object[kind == "box" ? "boxName" : "title"] is String else { throw InventoryDraftError.unavailable }
        if let assigned = object["assignedBoxes"] as? [String] { object["assignedBoxes"] = assigned.sorted() }
        var names = object["imageFileNames"] as? [String] ?? []
        if let name = object["locationImageFileName"] as? String { names.append(name) }
        if let name = object["pendingNewItemImageFileName"] as? String { names.append(name) }
        for item in object["items"] as? [[String: Any]] ?? [] { names += item["images"] as? [String] ?? [] }
        for name in names { _ = try photoURL(name, kind: kind) }
        return (try JSONSerialization.data(withJSONObject: object, options: .sortedKeys), Set(names))
    }

    private func photoURL(_ name: String, kind: String) throws -> URL {
        guard ["box", "item", "location"].contains(kind), !name.isEmpty, name != ".", name != "..",
              name == URL(fileURLWithPath: name).lastPathComponent else { throw InventoryDraftError.invalidPhoto }
        if kind == "box" {
            guard name.hasPrefix("create_draft_") || name.hasPrefix("create_item_draft_") else { throw InventoryDraftError.invalidPhoto }
            return documents.appendingPathComponent(name)
        }
        guard UUID(uuidString: URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent) != nil,
              URL(fileURLWithPath: name).pathExtension.lowercased() == "jpg" else { throw InventoryDraftError.invalidPhoto }
        return documents.appendingPathComponent("CreateFormDrafts/\(kind)").appendingPathComponent(name)
    }

    private func formTitle(_ form: Data, kind: String) throws -> String {
        let object = try JSONSerialization.jsonObject(with: form) as? [String: Any] ?? [:]
        return (object[kind == "box" ? "boxName" : "title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func winners(in context: ModelContext) throws -> [UUID: StoredFormDraft] {
        let selected = winners(try context.fetch(FetchDescriptor<StoredFormDraft>()))
        let deletions = try InventoryDeletionLedger.states(in: context, kind: "draft")
        return selected.filter { id, record in
            let state = deletions[id.uuidString]
            // Ein Restore-Ereignis allein macht die vor dem Delete gespeicherte
            // Inhaltszeile nicht wieder gültig. Auf ihre jüngere Payload warten.
            return state?.isDeleted != true && record.updatedAt > (state?.deletedAt ?? .distantPast)
        }
    }

    private func winners(_ records: [StoredFormDraft]) -> [UUID: StoredFormDraft] {
        var result: [UUID: StoredFormDraft] = [:]
        for record in records {
            if let old = result[record.id], old.updatedAt > record.updatedAt
                || (old.updatedAt == record.updatedAt && (old.isTombstoned || (old.payload ?? Data()).lexicographicallyPrecedes(record.payload ?? Data()))) { continue }
            result[record.id] = record
        }
        return result
    }

    private func activeID(_ kind: String) -> UUID? { defaults.string(forKey: pointerKey(kind)).flatMap(UUID.init(uuidString:)) }
    private func pointerKey(_ kind: String) -> String { "activeCloudDraft.\(deviceID).\(kind)" }
    private func publish() {
        revision += 1
        InventoryCloudSyncState.shared.markPendingChanges()
        didSave()
        NotificationCenter.default.post(name: .inventoryDraftsDidChange, object: nil)
    }
    private static func installationID() -> String {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BoxHelper", isDirectory: true)
        let url = support.appendingPathComponent("draft-device-id.txt")
        if let value = try? String(contentsOf: url, encoding: .utf8), UUID(uuidString: value) != nil { return value }
        let id = UUID().uuidString
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try? id.write(to: url, atomically: true, encoding: .utf8)
        return id
    }
}

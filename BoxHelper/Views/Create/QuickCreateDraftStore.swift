import Foundation

/// Der aktuelle Formularstand geht an Handoff und bei aktiviertem Formularsync an iCloud.
/// Bilddateien bleiben Arbeitskopien; die Stores sichern ihre Bytes vor dem Ersetzen.
struct QuickCreateDraft: Codable, Equatable {
    var title = ""
    var selectedBox: UUID?
    var selectedLocation: UUID?
    var isCreatingLocation = false
    var newBoxName = ""
    var newLocationName = ""
    var pendingBoxes: [String] = []
    var assignedBoxes: Set<UUID> = []
    var locationColor = "0,0.5,1"
    var tags: [String] = []
    // Optional für ältere Entwürfe, die diese Eigenschaften noch nicht gespeichert haben.
    var isFragile: Bool?
    var isHeavy: Bool?
    var isCameraExpanded = false
    var imageFileNames: [String] = []
    var locationImageFileName: String?
}

@MainActor
final class QuickCreateDraftStore {
    private let directory: URL
    private let handoff: InventoryHandoffStore

    init(directory: URL? = nil, handoff: InventoryHandoffStore = .shared) {
        self.handoff = handoff
        // Ein eigenes Verzeichnis schützt die Arbeitsfotos vor der Inventarbereinigung.
        self.directory = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CreateFormDrafts", isDirectory: true)
    }

    func load(for mode: CreateMode) -> QuickCreateDraft? {
        guard mode != .box else { return nil }
        do {
            guard let data = try handoff.load(kind: mode.rawValue) else { return nil }
            return try JSONDecoder().decode(QuickCreateDraft.self, from: data)
        } catch { print("Handoff-Formular konnte nicht gelesen werden: \(error)"); return nil }
    }

    func save(_ draft: QuickCreateDraft, for mode: CreateMode, isInitial: Bool = false) throws {
        guard mode != .box else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        // Laden würde einen eingehenden Handoff bereits quittieren. Schreibzugriffe
        // gehen deshalb direkt an den Store, der verspätete alte Views zurückweist.
        try handoff.save(form: encoder.encode(draft), kind: mode.rawValue, isInitial: isInitial)
    }

    /// Neue Dateien zuerst schreiben und den Handoff-Stand übernehmen. Erst danach
    /// die alten Arbeitsfotos entfernen; Fehler erhalten den bisherigen Formularstand.
    func replaceMedia(in draft: QuickCreateDraft, images: [Data], locationImage: Data?,
                      for mode: CreateMode) throws -> QuickCreateDraft {
        guard mode != .box else { return draft }
        let folder = directory.appendingPathComponent(mode.rawValue, isDirectory: true)
        let media = mode == .item ? images : locationImage.map { [$0] } ?? []
        var createdFiles: [URL] = []
        do {
            if !media.isEmpty { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
            for data in media {
                let url = folder.appendingPathComponent("\(UUID().uuidString).jpg")
                try data.write(to: url, options: .atomic)
                createdFiles.append(url)
            }
            var updated = draft
            updated.imageFileNames = mode == .item ? createdFiles.map(\.lastPathComponent) : []
            updated.locationImageFileName = mode == .location ? createdFiles.first?.lastPathComponent : nil
            try save(updated, for: mode)
            for name in draft.imageFileNames + [draft.locationImageFileName].compactMap({ $0 }) {
                if let url = imageURL(named: name, for: mode) { try? FileManager.default.removeItem(at: url) }
            }
            return updated
        } catch {
            for url in createdFiles { try? FileManager.default.removeItem(at: url) }
            throw error
        }
    }

    func imageData(named name: String, for mode: CreateMode) -> Data? {
        guard let url = imageURL(named: name, for: mode) else { return nil }
        return try? Data(contentsOf: url)
    }

    func clear(for mode: CreateMode) {
        guard mode != .box else { return }
        let current: QuickCreateDraft?
        do {
            current = try handoff.currentForm(kind: mode.rawValue).map {
                try JSONDecoder().decode(QuickCreateDraft.self, from: $0)
            }
            try handoff.clear(kind: mode.rawValue)
        }
        catch { print("Handoff-Sitzung konnte nicht abgeschlossen werden: \(error)"); return }
        // Nur Fotos dieser laufenden Sitzung entfernen. Historische Dateien können
        // noch zu alten Datenbankentwürfen gehören und bleiben im selben Ordner erhalten.
        for name in (current?.imageFileNames ?? []) + [current?.locationImageFileName].compactMap({ $0 }) {
            if let url = imageURL(named: name, for: mode) { try? FileManager.default.removeItem(at: url) }
        }
    }

    func clearAll() {
        clear(for: .item)
        clear(for: .location)
    }

    func imageURL(named name: String, for mode: CreateMode) -> URL? {
        // Übertragene Dateinamen dürfen das lokale Arbeitsverzeichnis nicht verlassen.
        guard mode != .box, !name.isEmpty, name != ".", name != "..",
              name == URL(fileURLWithPath: name).lastPathComponent else { return nil }
        return directory.appendingPathComponent(mode.rawValue, isDirectory: true).appendingPathComponent(name)
    }
}

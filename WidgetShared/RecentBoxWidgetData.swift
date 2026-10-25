import Foundation

/// Kleiner, versionierter Austausch zwischen App und Widget. Die Erweiterung öffnet
/// bewusst keinen SwiftData-/CloudKit-Store und erhält nur die sichtbaren Kisten.
struct RecentBoxWidgetData: Codable, Equatable, Sendable {
    static let kind = "RecentBoxesWidget"
    static let appGroup = "group.de.hockulus.boxhelper"
    // Ein gemeinsamer Snapshot versorgt auch das größte Raster mit 8 × 4 Kisten.
    static let maximumBoxCount = 32

    let version: Int
    let boxes: [Box]

    init(boxes: [Box]) {
        version = 1
        self.boxes = Array(boxes.prefix(Self.maximumBoxCount))
    }

    struct Box: Codable, Identifiable, Equatable, Sendable {
        let id: UUID
        let name: String
        // Optional, damit bereits gespeicherte Widget-Snapshots weiter lesbar bleiben.
        let locationName: String?
        let locationID: UUID?
        // Symbolfarbe des Standorts; ohne Zuordnung bleibt die Farbe neutral.
        let color: String
        let updatedAt: Date

        init(id: UUID, name: String, locationName: String? = nil, locationID: UUID? = nil,
             color: String, updatedAt: Date) {
            self.id = id
            self.name = name
            self.locationName = locationName
            self.locationID = locationID
            self.color = color
            self.updatedAt = updatedAt
        }

        /// Eine UUID-Reihenfolge hält Kacheln bei identischen Änderungsdaten stabil.
        static func newestFirst(_ lhs: Self, _ rhs: Self) -> Bool {
            if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}

enum RecentBoxWidgetStore {
    private static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: RecentBoxWidgetData.appGroup)?
            .appendingPathComponent("recent-boxes-v1.json")
    }

    static func read(from url: URL? = nil) -> RecentBoxWidgetData? {
        guard let url = url ?? fileURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(RecentBoxWidgetData.self, from: data),
              snapshot.version == 1 else { return nil }
        return RecentBoxWidgetData(boxes: snapshot.boxes)
    }

    /// Atomarer Austausch verhindert teilweise gelesene JSON-Dateien. Unveränderte
    /// Inhalte verbrauchen keine zusätzliche WidgetKit-Aktualisierung.
    @discardableResult
    static func write(_ snapshot: RecentBoxWidgetData, to url: URL? = nil) throws -> Bool {
        guard let url = url ?? fileURL else { throw StoreError.missingAppGroup }
        guard read(from: url) != snapshot else { return false }
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
        return true
    }

    private enum StoreError: Error {
        case missingAppGroup
    }
}

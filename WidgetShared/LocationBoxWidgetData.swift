import Foundation

/// Jeder Standort enthält seinen vollständigen Kistenbestand. Eine globale Begrenzung
/// würde Standorte mit älteren Kisten aus der Widget-Auswahl verdrängen.
struct LocationBoxWidgetData: Codable, Equatable, Sendable {
    static let kind = "LocationBoxesWidget"
    let version: Int
    let locations: [Location]

    init(locations: [Location]) {
        version = 1
        self.locations = locations
    }

    struct Location: Codable, Identifiable, Equatable, Sendable {
        let id: UUID
        let name: String
        let color: String
        let boxes: [RecentBoxWidgetData.Box]
    }

    func location(id: UUID) -> Location? { locations.first { $0.id == id } }
}

enum LocationBoxWidgetStore {
    private static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: RecentBoxWidgetData.appGroup)?
            .appendingPathComponent("location-boxes-v1.json")
    }

    static func read(from url: URL? = nil) -> LocationBoxWidgetData? {
        guard let url = url ?? fileURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(LocationBoxWidgetData.self, from: data),
              snapshot.version == 1 else { return nil }
        return snapshot
    }

    @discardableResult
    static func write(_ snapshot: LocationBoxWidgetData, to url: URL? = nil) throws -> Bool {
        guard let url = url ?? fileURL else { throw StoreError.missingAppGroup }
        guard read(from: url) != snapshot else { return false }
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
        return true
    }

    private enum StoreError: Error { case missingAppGroup }
}

import AppIntents
import Foundation

struct WidgetLocationEntity: AppEntity {
    let id: UUID
    let name: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Location"
    static let defaultQuery = WidgetLocationQuery()

    var displayName: String { name.isEmpty ? String(localized: "Unnamed location") : name }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", image: .init(systemName: "location.fill"))
    }
}

/// Der Bearbeiten-Dialog liest denselben App-Group-Snapshot wie die Timeline.
/// Gespeicherte UUIDs bleiben auch nach einer Umbenennung eindeutig zugeordnet.
struct WidgetLocationQuery: EntityStringQuery {
    var storeURL: URL?

    func entities(for identifiers: [UUID]) async throws -> [WidgetLocationEntity] {
        let entities = Dictionary(allEntities().map { ($0.id, $0) },
                                  uniquingKeysWith: { first, _ in first })
        return identifiers.compactMap { entities[$0] }
    }

    func suggestedEntities() async throws -> [WidgetLocationEntity] { allEntities() }

    func entities(matching string: String) async throws -> [WidgetLocationEntity] {
        let search = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return allEntities().filter { search.isEmpty || $0.displayName.localizedStandardContains(search) }
    }

    func defaultResult() async -> WidgetLocationEntity? { allEntities().first }

    private func allEntities() -> [WidgetLocationEntity] {
        (LocationBoxWidgetStore.read(from: storeURL)?.locations ?? []).map {
            WidgetLocationEntity(id: $0.id, name: $0.name)
        }
    }
}

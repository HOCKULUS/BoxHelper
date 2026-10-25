import Foundation

/// Unveränderliche Suchdaten lassen sich unabhängig von Speech und SwiftUI prüfen.
struct LocationDictationChoice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let color: String
    let usageCount: Int
}

enum LocationDictationSelection: Equatable {
    case existing(UUID)
    case new(String)
}

/// Exakte Namen stehen vor Teiltreffern; danach folgen häufig verwendete Standorte.
enum LocationDictationMatcher {
    static func normalized(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    static func matches(_ choices: [LocationDictationChoice], query: String,
                        preferredID: UUID? = nil) -> [LocationDictationChoice] {
        let query = normalized(query)
        return choices.filter { query.isEmpty || normalized($0.name).contains(query) }.sorted { left, right in
            // Die Formularauswahl bleibt bei leerem Diktat vorne. Sobald ein anderer
            // Name eingegeben wird, gilt wieder die normale Such- und Nutzungsreihenfolge.
            if query.isEmpty, let preferredID, (left.id == preferredID) != (right.id == preferredID) {
                return left.id == preferredID
            }
            let leftExact = !query.isEmpty && normalized(left.name) == query
            let rightExact = !query.isEmpty && normalized(right.name) == query
            if leftExact != rightExact { return leftExact }
            if left.usageCount != right.usageCount { return left.usageCount > right.usageCount }
            let comparison = left.name.localizedStandardCompare(right.name)
            if comparison != .orderedSame { return comparison == .orderedAscending }
            return left.id.uuidString < right.id.uuidString
        }
    }

    /// Nur ein exakter gesprochener Name ersetzt die sichtbare Vorauswahl.
    /// Teiltreffer erhalten keinen Rahmen, weil sie noch keine eindeutige Auswahl sind.
    static func selectedID(in choices: [LocationDictationChoice], query: String,
                           preferredID: UUID?) -> UUID? {
        if normalized(query).isEmpty {
            return choices.first(where: { $0.id == preferredID })?.id
        }
        guard case .existing(let id) = resolve(query: query, choices: choices) else { return nil }
        return id
    }

    /// Teiltreffer bleiben sieben Sekunden anklickbar. Ein exakter Name oder
    /// ein neuer Name ohne Treffer wird schon nach zwei Sekunden Ruhe abgeschlossen.
    static func silenceSeconds(for query: String, choices: [LocationDictationChoice]) -> Double {
        let query = normalized(query)
        let results = matches(choices, query: query)
        if query.isEmpty { return results.isEmpty ? 2 : 7 }
        return results.isEmpty || results.contains(where: { normalized($0.name) == query }) ? 2 : 7
    }

    static func resolve(query: String, choices: [LocationDictationChoice]) -> LocationDictationSelection? {
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let normalizedName = normalized(name)
        if let exact = matches(choices, query: name).first(where: { normalized($0.name) == normalizedName }) {
            return .existing(exact.id)
        }
        // Auch bei einem einzigen Teiltreffer niemals ungefragt einen anderen Namen übernehmen.
        return .new(name)
    }
}

import Foundation

/// Ein gemeinsamer, dauerhafter Anzeigemodus für die Kamera in Items und Kisten.
enum FeedObjectMarkingStyle: String, CaseIterable {
    static let storageKey = "feedObjectMarkingStyle"

    case hidden, rectangle, dots, reticle, matrix

    /// Jeder einzelne Tipp schaltet weiter, unabhängig von Tempo und Diagnosezähler.
    var next: Self {
        switch self {
        case .hidden: return .rectangle
        case .rectangle: return .dots
        case .dots: return .reticle
        case .reticle: return .matrix
        case .matrix: return .hidden
        }
    }
}

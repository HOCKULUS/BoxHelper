import SwiftUI

/// Gemeinsame Maße halten Support, Update-Karten und Scrollrand deckungsgleich.
enum LaunchLayout {
    static let cardCornerRadius: CGFloat = 26
    static let maximumContentWidth: CGFloat = 800

    static var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
    }
}

/// Alle Launch-Karten nutzen dieselbe feste weiße Fläche mit leichter Transparenz.
struct LaunchCardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Color.white.opacity(0.85), in: LaunchLayout.cardShape)
    }
}

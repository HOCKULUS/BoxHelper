import SwiftUI

/// Die bewegte Maske gibt das Mesh nach außen frei, wie die umgekehrte Feed-Maske.
/// Sprachpegel vergrößern sowohl den Leuchtkörper als auch seine weichen Wellen.
struct DictationIntelligenceGlow: View {
    let phase: Float
    let audioLevel: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width, geometry.size.height) / 2
            // Auch normale und leisere Sprache soll deutlich sichtbar pulsieren.
            let energy = reduceMotion ? 0 : sqrt(min(1, max(0, audioLevel)))

            MeshGradientView(maskTimer: .constant(phase), gradientSpeed: .constant(0.03))
                .blur(radius: 12)
                .mask {
                    DictationWaveShape(phase: CGFloat(phase), energy: energy,
                                       isAnimated: !reduceMotion)
                        .fill(.white)
                        .blur(radius: radius * 0.1)
                        .animation(.easeOut(duration: 0.12), value: energy)
                }
                .mask {
                    // Zusätzlicher Auslauf innerhalb der Zeichenfläche: Selbst
                    // bei lautem Sprechen erreicht keine sichtbare Kante den Rand.
                    RadialGradient(stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.65),
                        .init(color: .white.opacity(0.6), location: 0.8),
                        .init(color: .white.opacity(0.15), location: 0.92),
                        .init(color: .clear, location: 1)
                    ], center: .center, startRadius: 0,
                       endRadius: radius)
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

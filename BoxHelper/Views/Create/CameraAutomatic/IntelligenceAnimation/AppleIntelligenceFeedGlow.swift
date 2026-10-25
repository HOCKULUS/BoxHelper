import SwiftUI

/// Originaler Ebenenaufbau aus TopScrech/Apple-Intelligence-Animation (MIT).
/// Die Live-Vorschau ersetzt den Demo-Hintergrund; Bedienelemente liegen außerhalb dieses Modifiers.
struct AppleIntelligenceFeedGlow: ViewModifier {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()
    @State private var isVisible = false

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            // Die iPhone-breite Zeichenfläche erhält die Größenverhältnisse des Originals
            // auch in der kleinen, quadratischen Vorschau.
            let scale = geometry.size.width / 393
            let canvas = CGSize(width: 393, height: geometry.size.height / max(scale, 0.001))

            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !isActive || reduceMotion)) { timeline in
                // Gleichbleibende Bewegung, unabhängig von Motivwechsel und Countdown.
                let phase = reduceMotion ? Float(0) : Float(timeline.date.timeIntervalSince(startedAt) * 3)

                ZStack {
                    MeshGradientView(maskTimer: .constant(phase), gradientSpeed: .constant(0.03))
                        .blur(radius: 6 * scale)
                        .scaleEffect(1.3)
                        .opacity(isVisible ? 1 : 0)

                    RoundedRectangle(cornerRadius: 52 * scale, style: .continuous)
                        .stroke(.white, lineWidth: 4 * scale)
                        .blur(radius: 4 * scale)
                        .opacity(isVisible ? 1 : 0)

                    // Der unveränderte Kamerainhalt liegt vor dem Mesh.
                    // Seine bewegte, weiche Maske gibt den Leuchtrand frei.
                    // Der Kameraview behält beim Aktivieren seine strukturelle Position.
                    content
                        .mask {
                            AnimatedRectangle(size: canvas, cornerRadius: 48, t: CGFloat(phase))
                                .frame(width: canvas.width, height: canvas.height)
                                .scaleEffect(isVisible ? 1 : 1.2)
                                .blur(radius: isVisible ? 28 : 8)
                                .scaleEffect(scale)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 52 * scale, style: .continuous))
        }
        // Außerhalb der laufenden Timeline steuern: Beide Richtungen verwenden
        // dieselbe Kurve, auch wenn die Vorschau bereits aktiv eingeblendet wird.
        .onChange(of: isActive, initial: true) { _, active in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.65)) {
                isVisible = active
            }
        }
    }
}

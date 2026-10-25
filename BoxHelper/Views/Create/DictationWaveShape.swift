import SwiftUI

/// Kreisförmiges Gegenstück zur bewegten Feed-Maske. Überlagerte Sinuswellen
/// wandern um den Umfang und verformen ihn ausschließlich nach außen.
struct DictationWaveShape: Shape {
    var phase: CGFloat
    var energy: Double
    let isAnimated: Bool

    var animatableData: AnimatablePair<CGFloat, Double> {
        get { AnimatablePair(phase, energy) }
        set {
            phase = newValue.first
            energy = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let extent = min(rect.width, rect.height) / 2
        let level = CGFloat(min(1, max(0, energy)))
        let radius = extent * (0.48 + 0.22 * level)
        let amplitude = isAnimated ? extent * (0.035 + 0.105 * level) : 0
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()

        // Kleine Winkelschritte und die anschließende Unschärfe halten den Rand
        // rund. Ganzzahlige Wellenfrequenzen schließen die Kontur ohne Naht.
        for index in 0..<180 {
            let angle = CGFloat(index) / 180 * 2 * .pi
            let wave = 0.5 + 0.3 * sin(3 * angle - phase)
                + 0.2 * sin(5 * angle + phase * 0.7)
            let distance = radius + amplitude * wave
            let point = CGPoint(x: center.x + cos(angle) * distance,
                                y: center.y + sin(angle) * distance)
            if index == 0 { path.move(to: point) }
            else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

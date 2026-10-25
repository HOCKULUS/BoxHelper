import Foundation
import CoreGraphics

/// Ein Objekt liefert genau einen Mittelpunkt und einen kreisrunden Einflussbereich.
struct FeedObjectFocus {
    let center: CGPoint
    let radius: CGFloat

    init(rect: CGRect) {
        center = CGPoint(x: rect.midX, y: rect.midY)
        // Das gedachte Quadrat umfasst die längere Objektseite. Auch bei schmalen
        // Objekten bleibt der Bereich rund und wächst mit der Objektgröße.
        radius = max(rect.width, rect.height) / 2
    }

    func proximity(to point: CGPoint) -> Double {
        guard radius > 0 else { return 0 }
        let distance = hypot(point.x - center.x, point.y - center.y) / radius
        guard distance < 1 else { return 0 }
        // Nur die Entfernung zum Mittelpunkt zählt, keine Rechteckkanten.
        let falloff = 1 - distance * distance
        return Double(falloff * falloff)
    }
}

/// Glättet ausschließlich die Darstellung zwischen Messungen; Auslöser und
/// bestätigte Objektpositionen der Kamera bleiben davon unabhängig.
struct FeedObjectFocusAnimation {
    static let duration = 0.3

    private struct Motion {
        let start: CGRect
        let target: CGRect
        let startedAt: Double

        func rect(at now: Double) -> CGRect {
            let progress = CGFloat(min(1, max(0, (now - startedAt) / FeedObjectFocusAnimation.duration)))
            guard progress > 0 else { return start }
            guard progress < 1 else { return target }
            // Sanftes Anfahren und Abbremsen statt eines Sprungs pro Kameramessung.
            let fraction = progress * progress * (3 - 2 * progress)
            return CGRect(x: start.minX + (target.minX - start.minX) * fraction,
                          y: start.minY + (target.minY - start.minY) * fraction,
                          width: start.width + (target.width - start.width) * fraction,
                          height: start.height + (target.height - start.height) * fraction)
        }
    }

    private var motions: [Motion] = []

    mutating func update(_ regions: [CGRect], at now: Double) {
        var remaining = regions.compactMap(FeedSaliencyRegionGeometry.normalized)
        var previous = motions
        var updated: [Motion] = []

        // Räumlich nächste Paare zuerst zuordnen. Eine andere Reihenfolge der
        // Vision-Ergebnisse darf Punkte verschiedener Objekte nicht vertauschen.
        while !previous.isEmpty, !remaining.isEmpty {
            var pair = (old: 0, new: 0)
            var nearest = CGFloat.infinity
            for old in previous.indices {
                for new in remaining.indices {
                    let distance = Self.distance(previous[old].target, remaining[new])
                    if distance < nearest {
                        nearest = distance
                        pair = (old, new)
                    }
                }
            }
            let motion = previous.remove(at: pair.old)
            let target = remaining.remove(at: pair.new)
            // Eine neue Messung setzt am aktuell sichtbaren Punkt an, auch wenn
            // die vorherige Bewegung noch nicht abgeschlossen war.
            updated.append(Motion(start: motion.rect(at: now), target: target, startedAt: now))
        }
        updated.append(contentsOf: remaining.map { Motion(start: $0, target: $0, startedAt: now) })
        motions = updated
    }

    func regions(at now: Double, animated: Bool = true) -> [CGRect] {
        motions.map { animated ? $0.rect(at: now) : $0.target }
    }

    private static func distance(_ first: CGRect, _ second: CGRect) -> CGFloat {
        hypot(first.midX - second.midX, first.midY - second.midY)
            + abs(first.width - second.width) + abs(first.height - second.height)
    }
}

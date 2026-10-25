import SwiftUI

/// Rein visuelle Markierungen bestätigter, geglätteter Funde. Keine zusätzliche Objektsuche.
struct CreateObjectRegionsOverlay: View {
    let regions: [CGRect]
    let style: FeedObjectMarkingStyle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()
    @State private var focusAnimation = FeedObjectFocusAnimation()

    var body: some View {
        GeometryReader { geometry in
            let rectangles = regions.compactMap { FeedSaliencyRegionGeometry.previewRect($0, size: geometry.size) }
            if style == .rectangle {
                rectanglePath(rectangles).stroke(.black.opacity(0.6), lineWidth: 4)
                rectanglePath(rectangles).stroke(.green, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            } else if style != .hidden {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                    let phase = reduceMotion ? Float(0) : Float(timeline.date.timeIntervalSince(startedAt) * 3)
                    let movingRectangles = focusAnimation.regions(at: ProcessInfo.processInfo.systemUptime, animated: !reduceMotion)
                        .compactMap { FeedSaliencyRegionGeometry.previewRect($0, size: geometry.size) }
                    let focuses = movingRectangles.map(FeedObjectFocus.init)
                    if style == .matrix {
                        proximityMatrix(focuses: focuses)
                    } else {
                        // Gleicher Mesh-Verlauf wie beim Diktat, ausschließlich durch die Markierungen sichtbar.
                        MeshGradientView(maskTimer: .constant(phase), gradientSpeed: .constant(0.03))
                            .mask {
                                if style == .dots { centerDots(focuses) }
                                else { reticlePath(rectangles).stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [8, 5])) }
                            }
                    }
                }
            }
        }
        .onChange(of: regions, initial: true) { _, regions in
            focusAnimation.update(regions, at: ProcessInfo.processInfo.systemUptime)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func rectanglePath(_ rectangles: [CGRect]) -> Path {
        Path { path in
            for rect in rectangles { path.addRect(rect) }
        }
    }

    private func reticlePath(_ rectangles: [CGRect]) -> Path {
        Path { path in
            for rect in rectangles {
                path.addEllipse(in: rect)
                // Ein kurzer zentraler Suchindikator statt eines weiteren Rechtecks.
                path.move(to: CGPoint(x: rect.midX - 4, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.midX + 4, y: rect.midY))
                path.move(to: CGPoint(x: rect.midX, y: rect.midY - 4))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.midY + 4))
            }
        }
    }

    private func centerDots(_ focuses: [FeedObjectFocus]) -> some View {
        Canvas { context, _ in
            for focus in focuses {
                // Genau ein runder Punkt pro Objekt; sein Durchmesser skaliert
                // mit dem gedachten Objektquadrat, ohne den Feed zu verdecken.
                drawDot(at: focus.center, radius: focus.radius * 0.12, opacity: 1, context: &context)
            }
        }
    }

    private func proximityMatrix(focuses: [FeedObjectFocus]) -> some View {
        Canvas { context, size in
            // Exakt 50 × 50 Punkte. Jedes Objekt beeinflusst das Raster ausgehend
            // von einem Mittelpunkt in einem runden, objektgroßen Bereich.
            for row in 0..<50 {
                for column in 0..<50 {
                    let point = CGPoint(x: (CGFloat(column) + 0.5) * size.width / 50,
                                        y: (CGFloat(row) + 0.5) * size.height / 50)
                    let proximity = focuses.reduce(0.0) { max($0, $1.proximity(to: point)) }
                    drawDot(at: point, radius: 0.45 + CGFloat(proximity) * 1.15,
                            opacity: 0.06 + proximity * 0.64, context: &context)
                }
            }
        }
    }

    private func drawDot(at point: CGPoint, radius: CGFloat, opacity: Double, context: inout GraphicsContext) {
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
    }
}

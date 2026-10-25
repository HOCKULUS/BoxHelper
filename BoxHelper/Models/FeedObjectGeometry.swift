import Foundation
import CoreGraphics

/// Bestätigte, geglättete Rechtecke statt kurzlebiger Einzelframe-Funde.
/// Keine Klassen, Kategorien oder Objektbilder werden gespeichert.
struct FeedObjectTracker: Sendable {
    private struct Track: Sendable {
        var rect: CGRect
        var hits = 1
        var missed = 0
        var confirmed = false
    }
    private var tracks: [Track] = []
    private var lastTime: Double?
    private(set) var regions: [CGRect] = []

    mutating func update(_ detections: [CGRect], at now: Double) {
        if let lastTime, now - lastTime > 2.5 { tracks.removeAll { !$0.confirmed } }
        lastTime = now
        var remaining = detections.compactMap(FeedSaliencyRegionGeometry.normalized)
        for index in tracks.indices {
            let reference = tracks[index].rect
            let match = remaining.indices.min { FeedObjectGeometry.distance(reference, remaining[$0]) < FeedObjectGeometry.distance(reference, remaining[$1]) }
            if let match, FeedObjectGeometry.distance(reference, remaining[match]) < 0.35 {
                let detected = remaining.remove(at: match)
                tracks[index].rect = FeedObjectGeometry.smoothed(reference, detected)
                tracks[index].hits += 1
                tracks[index].missed = 0
                if tracks[index].hits >= 3 { tracks[index].confirmed = true }
            } else {
                tracks[index].missed += 1
                // Ein Fund muss dreimal direkt hintereinander auftreten.
                if !tracks[index].confirmed { tracks[index].hits = 0 }
            }
        }
        tracks.removeAll { $0.missed >= 3 || (!$0.confirmed && $0.missed > 0) }
        tracks.append(contentsOf: remaining.map { Track(rect: $0) })
        // Vision liefert wenige Regionen; auch bei unerwarteten Ergebnissen begrenzen.
        tracks = Array(tracks.prefix(16))
        regions = tracks.filter(\.confirmed).map(\.rect)
    }
}

enum FeedObjectGeometry {
    static let threshold = 0.18
    static func distance(_ a: CGRect, _ b: CGRect) -> Double {
        let center = hypot(a.midX - b.midX, a.midY - b.midY)
        let size = abs(a.width - b.width) + abs(a.height - b.height)
        return min(1, Double(center * 2 + size))
    }
    static func smoothed(_ old: CGRect, _ new: CGRect) -> CGRect {
        let alpha: CGFloat = 0.35
        return CGRect(x: old.minX + (new.minX - old.minX) * alpha,
                      y: old.minY + (new.minY - old.minY) * alpha,
                      width: old.width + (new.width - old.width) * alpha,
                      height: old.height + (new.height - old.height) * alpha)
    }
    /// Größe und Koordinaten beider Referenzen zählen. Reihenfolge der Vision-
    /// Ergebnisse ist unerheblich; hinzugekommene/fehlende Bereiche zählen mit.
    static func difference(_ current: [CGRect], _ reference: [CGRect]) -> Double {
        guard !current.isEmpty || !reference.isEmpty else { return 0 }
        var unmatched = reference
        var sum = 0.0
        for rect in current {
            if let index = unmatched.indices.min(by: { distance(rect, unmatched[$0]) < distance(rect, unmatched[$1]) }) {
                sum += distance(rect, unmatched.remove(at: index))
            } else { sum += 1 }
        }
        sum += Double(unmatched.count)
        return min(1, sum / Double(max(current.count, reference.count)))
    }
}

/// Gemeinsame Skala: 1 erreicht die Aufnahmeschwelle, keine Wahrscheinlichkeit.
enum FeedSceneFusion {
    static func score(image: Double, objects: Double, useImage: Bool, useObjects: Bool) -> Double {
        let image = max(0, min(2, image)), objects = max(0, min(2, objects))
        switch (useImage, useObjects) {
        case (true, true): return 0.85 * image + 0.15 * objects
        case (true, false): return image
        case (false, true): return objects
        default: return 0
        }
    }
}

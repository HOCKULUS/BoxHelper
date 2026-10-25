import Foundation

/// Räumliches Glätten unterdrückt Sensorrauschen, während zusammenhängende lokale
/// Änderungen erhalten bleiben. Keine Bilderkennung und keine Wahrscheinlichkeit.
enum FeedSceneComparison {
    struct Measurement: Sendable {
        let score: Double
        let globalDifference: Double
        let regionalDifference: Double
        let changedArea: Double
    }

    private struct Cell {
        let brightness: Double
        let texture: Double
    }

    static func measure(_ frame: [UInt8], against reference: [UInt8], compensatesExposure: Bool = true) -> Measurement {
        guard !frame.isEmpty, frame.count == reference.count else {
            return Measurement(score: 1, globalDifference: 1, regionalDifference: 1, changedArea: 1)
        }
        let side = Int(Double(frame.count).squareRoot())
        guard side * side == frame.count else {
            let delta = zip(frame, reference).map { Double(Int($0) - Int($1)) / 255 }
            let shift = compensatesExposure ? median(delta) : 0
            let score = delta.reduce(0) { $0 + abs($1 - shift) } / Double(delta.count)
            return Measurement(score: score, globalDifference: score, regionalDifference: score, changedArea: 1)
        }
        let grid = min(16, side)
        let current = cells(frame, side: side, grid: grid)
        let baseline = cells(reference, side: side, grid: grid)
        // Der Median der Zellverschiebungen kompensiert globale Helligkeit,
        // ohne dass ein kleines Motiv den Ausgleich für das ganze Bild verschiebt.
        let shift = compensatesExposure ? median(zip(current, baseline).map { $0.brightness - $1.brightness }) : 0
        let deltas = zip(current, baseline).map {
            let delta = min(1, abs($0.brightness - $1.brightness - shift) + 0.35 * abs($0.texture - $1.texture))
            return delta < 0.000000000001 ? 0 : delta
        }
        let global = deltas.reduce(0, +) / Double(deltas.count)
        var regional = global
        if grid >= 2 {
            // Vier benachbarte Zellen statt eines einzelnen auffälligen Pixels.
            for row in 0..<(grid - 1) {
                for column in 0..<(grid - 1) {
                    let index = row * grid + column
                    regional = max(regional, (deltas[index] + deltas[index + 1]
                        + deltas[index + grid] + deltas[index + grid + 1]) / 4)
                }
            }
        }
        return Measurement(score: max(global, regional * 0.6), globalDifference: global,
                           regionalDifference: regional,
                           changedArea: Double(deltas.filter { $0 >= 0.02 }.count) / Double(deltas.count))
    }

    private static func cells(_ frame: [UInt8], side: Int, grid: Int) -> [Cell] {
        let size = max(1, side / grid)
        return (0..<(grid * grid)).map { index in
            let top = (index / grid) * size
            let left = (index % grid) * size
            var sum = 0.0
            var texture = 0.0
            var edges = 0
            for y in top..<(top + size) {
                for x in left..<(left + size) {
                    let value = Double(frame[y * side + x]) / 255
                    sum += value
                    if x > left {
                        texture += abs(value - Double(frame[y * side + x - 1]) / 255)
                        edges += 1
                    }
                    if y > top {
                        texture += abs(value - Double(frame[(y - 1) * side + x]) / 255)
                        edges += 1
                    }
                }
            }
            return Cell(brightness: sum / Double(size * size), texture: edges > 0 ? texture / Double(edges) : 0)
        }
    }

    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}

/// Begrenzte Frame-Sammlung für robuste Referenzen; nur kleine Messframes im RAM.
enum FeedStableReference {
    static func median(_ frames: [[UInt8]]) -> [UInt8]? {
        guard let first = frames.first, frames.allSatisfy({ $0.count == first.count }) else { return nil }
        return first.indices.map { index in
            let values = frames.map { $0[index] }.sorted()
            return values[values.count / 2]
        }
    }

    static func noiseFloor(_ frames: [[UInt8]], reference: [UInt8], compensatesExposure: Bool = true) -> Double {
        let differences = frames.map { FeedSceneComparison.measure($0, against: reference, compensatesExposure: compensatesExposure).score }.sorted()
        guard !differences.isEmpty else { return 0 }
        return differences[min(differences.count - 1, Int(Double(differences.count - 1) * 0.8))]
    }
}

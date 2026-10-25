import Foundation

/// Erst eine durchgehend ruhige Sekunde erlaubt den sichtbaren Countdown.
/// Die feste Referenz verhindert, dass langsame Bewegung zwischen Frames durchrutscht.
struct FeedCountdownPreparation: Sendable {
    private var reference: [UInt8]?
    private var previous: [UInt8]?
    private var startedAt: Double?
    private var lastSampleAt: Double?

    /// Diagnose und Export zeigen dieselbe Referenz und Grenze wie die Vorprüfung.
    func diagnosticComparison(for sample: [UInt8], tolerance: Double, compensatesExposure: Bool = true) -> FeedDiagnosticComparison? {
        reference.map { FeedDiagnosticComparison.measuring(sample, against: $0, threshold: tolerance, compensatesExposure: compensatesExposure) }
    }

    mutating func compare(_ sample: [UInt8], at now: Double, tolerance: Double,
                          maximumGap: Double, compensatesExposure: Bool = true) -> Bool {
        guard let reference, let previous, let startedAt, let lastSampleAt,
              now - lastSampleAt <= maximumGap,
              FeedSceneComparison.measure(sample, against: reference, compensatesExposure: compensatesExposure).score <= tolerance,
              FeedSceneComparison.measure(sample, against: previous, compensatesExposure: compensatesExposure).score <= tolerance else {
            self.reference = sample
            self.previous = sample
            self.startedAt = now
            self.lastSampleAt = now
            return false
        }
        self.previous = sample
        self.lastSampleAt = now
        return now - startedAt + 0.000001 >= 1
    }
}

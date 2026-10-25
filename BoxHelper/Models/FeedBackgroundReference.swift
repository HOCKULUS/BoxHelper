import Foundation

/// Die erste Hintergrundreferenz benötigt weniger Ruhezeit als ein Motiv-Countdown.
/// Erleichterungen gelten ausschließlich hier und verändern keine gespeicherte Empfindlichkeitsstufe.
struct FeedBackgroundReference: Sendable {
    static let stableDuration = 1.5

    enum Update {
        case collecting, restarted, unstable, ready([UInt8])
    }

    private var samples: [[UInt8]] = []
    private var startedAt: Double?
    private var failures = 0
    private(set) var noiseFloor = 0.0

    private func toleranceFactor(allowsAdjustment: Bool) -> Double {
        allowsAdjustment ? min(2, 1 + Double(failures / 3) * 0.25) : 1
    }

    /// Vor dem Vergleich auslesen, damit auch ein verworfener Referenzversuch
    /// seine tatsächliche Differenz und die zu diesem Zeitpunkt gültige Grenze zeigt.
    func diagnosticComparison(for sample: [UInt8], tolerance: Double,
                              allowsAdjustment: Bool, compensatesExposure: Bool = true) -> FeedDiagnosticComparison? {
        guard let first = FeedStableReference.median(Array(samples.prefix(3))), first.count == sample.count else { return nil }
        return .measuring(sample, against: first,
                          threshold: tolerance * toleranceFactor(allowsAdjustment: allowsAdjustment), compensatesExposure: compensatesExposure)
    }

    mutating func compare(_ sample: [UInt8], at now: Double, tolerance: Double,
                          allowsAdjustment: Bool, compensatesExposure: Bool = true) -> Update {
        // Alle drei Fehlversuche vorübergehend mehr Spielraum, begrenzt auf das
        // Doppelte. Nach der Referenzaufnahme wird dieser Zustand verworfen.
        let factor = toleranceFactor(allowsAdjustment: allowsAdjustment)
        if let first = FeedStableReference.median(Array(samples.prefix(3))),
           first.count != sample.count || FeedSceneComparison.measure(sample, against: first, compensatesExposure: compensatesExposure).score > tolerance * factor {
            failures += 1
            samples = [sample]
            startedAt = now
            return failures.isMultiple(of: 3) ? .unstable : .restarted
        }
        if startedAt == nil { startedAt = now }
        samples.append(sample)
        if samples.count > 16 { samples.removeFirst() }
        guard let startedAt, now - startedAt + 0.000001 >= Self.stableDuration else { return .collecting }
        guard samples.count >= 3, let reference = FeedStableReference.median(samples) else { return .collecting }
        noiseFloor = FeedStableReference.noiseFloor(samples, reference: reference, compensatesExposure: compensatesExposure)
        samples.removeAll()
        self.startedAt = nil
        failures = 0
        return .ready(reference)
    }
}

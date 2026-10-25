import Foundation

/// Begrenzter Regler mit geglätteten Aufnahmeabständen und einer Totzone.
/// Ein Zeit-Ziel ist keine Foto-Erlaubnis: Referenzdifferenz und Ruhe bleiben Pflicht.
struct FeedAutomaticThresholds: Sendable {
    private(set) var changeFactor = 1.0
    private(set) var stabilityFactor = 1.0
    private(set) var revision = 0
    private var consecutiveAborts = 0
    private var evaluatedAt: Double?
    private var lastSuccess: Double?
    private var averageInterval: Double?
    private var peakSignal = 0.0
    private var speed = 1
    private var dictation = false

    mutating func configure(speed: Int, dictation: Bool) {
        self.speed = min(2, max(0, speed))
        // Wechsel des Zeit-Ziels darf keinen alten Aufnahmeabstand weiterverwenden.
        if self.dictation != dictation { averageInterval = nil }
        self.dictation = dictation
    }

    mutating func recordAbort() { consecutiveAborts += 1 }

    mutating func recordSuccess(at now: Double) {
        if let lastSuccess, now > lastSuccess {
            let interval = now - lastSuccess
            averageInterval = averageInterval.map { $0 * 0.75 + interval * 0.25 } ?? interval
        }
        lastSuccess = now
        consecutiveAborts = 0
        peakSignal = 0
    }

    mutating func observe(signal: Double, noiseFloor: Double, baseThreshold: Double,
                          at now: Double, countdownRunning: Bool) {
        guard !countdownRunning else { return }
        peakSignal = max(peakSignal, signal)
        guard let evaluatedAt else { self.evaluatedAt = now; return }
        let window = [4.0, 8.0, 12.0][speed]
        guard now - evaluatedAt >= window else { return }
        let step = [0.08, 0.05, 0.025][speed]
        let target = dictation ? 25.0 : 15.0
        let tooFast = dictation ? 18.0 : 8.0
        let oldChange = changeFactor
        let oldStability = stabilityFactor
        let minimum = min(2.5, max(0.12, (noiseFloor * 2.5 + 0.006) / max(baseThreshold, 0.002)))
        if consecutiveAborts >= 3 {
            // Abbrüche beruhigen: etwas höhere Änderungsschwelle und weichere Ruhe.
            changeFactor *= 1 + step
            stabilityFactor = min(3, stabilityFactor * (1 + step))
            consecutiveAborts = 0
        } else if let averageInterval, averageInterval < target * 0.8,
                  lastSuccess.map({ now - $0 < target }) ?? false {
            changeFactor *= 1 + step * (averageInterval < tooFast ? 1.5 : 1)
            stabilityFactor += (1 - stabilityFactor) * step
        } else if (lastSuccess.map({ now - $0 > target * 1.2 }) ?? true),
                  peakSignal > 0.001,
                  peakSignal < baseThreshold * changeFactor || (averageInterval ?? target) > target * 1.2 {
            changeFactor *= 1 - step
        }
        changeFactor = min(2.5, max(minimum, changeFactor))
        self.evaluatedAt = now
        peakSignal = 0
        if abs(changeFactor - oldChange) > 0.000001 || abs(stabilityFactor - oldStability) > 0.000001 { revision += 1 }
    }
}

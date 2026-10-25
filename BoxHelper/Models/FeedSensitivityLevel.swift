import Foundation

/// 0 wählt die sitzungsgebundene Anpassung; 1…4 bleiben feste manuelle Stufen.
enum FeedSensitivityLevel: Int, CaseIterable {
    case automatic, relaxed, balanced, precise, veryPrecise
    static let storageKey = "feedMonitoringSensitivityLevel"
    static let modeKey = "itemAutomaticModeSelected"
    static let hintsKey = "feedMonitoringFailureHints"
    static let defaultLevel: Self = .automatic
    static let preferencesVersionKey = "feedSensitivitySchemeVersion"

    var next: Self { Self(rawValue: (rawValue + 1) % Self.allCases.count) ?? .automatic }
    var titleKey: String { "FeedSensitivity.Level\(rawValue)" }

    /// Neue Vorgaben einmalig auch auf vorhandene Installationen übernehmen.
    /// Spätere bewusste Änderungen der Stufe und des Zeitlimits bleiben erhalten.
    static func prepareDefaults(in defaults: UserDefaults = .standard) {
        guard defaults.integer(forKey: preferencesVersionKey) < 3 else { return }
        defaults.set(defaultLevel.rawValue, forKey: storageKey)
        defaults.set(FeedMonitoringConfiguration.regularInterval, forKey: FeedMonitoringConfiguration.intervalKey)
        defaults.set(300.0, forKey: FeedMonitoringConfiguration.inactivityKey)
        defaults.set(3, forKey: preferencesVersionKey)
    }

    func configuration(basedOn base: FeedMonitoringConfiguration) -> FeedMonitoringConfiguration {
        let changeFactors = [1.4, 3.5, 2.25, 1.4, 0.7]
        // Stufe 3 entspricht der bisher niedrigsten manuellen Sensitivität.
        // Nur die zwei weicheren Stufen erleichtern zusätzlich das Stillhalten.
        let stabilityFactors = [1.0, 2.5, 1.6, 1.0, 1.0]
        var result = FeedMonitoringConfiguration(interval: base.interval,
                                           threshold: base.threshold * changeFactors[rawValue],
                                           inactivity: base.inactivity, cooldown: base.cooldown,
                                           stabilityThreshold: base.stabilityThreshold * stabilityFactors[rawValue],
                                           stabilityInterval: base.stabilityInterval,
                                           usesImageReference: base.usesImageReference, usesObjectness: base.usesObjectness)
        result.adaptationSpeed = base.adaptationSpeed
        result.usesDictation = base.usesDictation
        return result

    }
}

/// Zehn schnelle Interaktionen öffnen die ansonsten verborgenen Expertenoptionen.
struct FeedAdvancedSettingsUnlock {
    private var count = 0
    private var started: Double?
    private var last: Double?

    mutating func record(at now: Double) -> Bool {
        if (last.map({ now - $0 > 1.5 || now < $0 }) ?? true) || (started.map({ now - $0 > 8 }) ?? false) {
            count = 0
            started = now
        }
        last = now
        count += 1
        guard count == 10 else { return false }
        count = 0
        started = nil
        return true
    }
}

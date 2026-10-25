import Foundation

/// Der Hinweis wird pro Ausgabe einmal bestätigt, unabhängig von der Lesedauer.
enum LaunchPresentationPolicy {
    static let showKey = "showLauchscreen5"
    private static let legacyRepeatsKey = "showLauchscreen5RemainingStarts"

    enum Presentation: Equatable {
        case initial, replay
        var closeDelay: Double { 2 }
    }

    static func shouldShow(in defaults: UserDefaults = .standard) -> Bool {
        // Bereits gespeicherte Wiederholungen aus älteren Versionen zählen nicht mehr.
        defaults.object(forKey: showKey) as? Bool ?? true
    }

    static func beginAppStart(in defaults: UserDefaults = .standard) -> Presentation? {
        shouldShow(in: defaults) ? .initial : nil
    }

    static func complete(_ presentation: Presentation, in defaults: UserDefaults = .standard) {
        // Manuelles Öffnen in den Einstellungen verändert die automatische Anzeige nicht.
        guard presentation == .initial else { return }
        defaults.set(false, forKey: showKey)
        defaults.removeObject(forKey: legacyRepeatsKey)
    }
}

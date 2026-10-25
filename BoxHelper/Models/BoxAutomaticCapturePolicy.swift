import Foundation

/// Kleine, hardwareunabhängige Regeln für Bildserien und den Diktat-Fallback.
enum BoxAutomaticCapturePolicy {
    static let photoCountKey = "boxAutomaticPhotoCount"
    static let voiceNamingKey = "boxVoiceNamingEnabled"
    static let locationNamingKey = "boxLocationDictationEnabled"
    static let defaultPhotoCount = 1
    static let photoCountRange = 1...50

    static func photoCount(in defaults: UserDefaults = .standard) -> Int {
        let value = defaults.object(forKey: photoCountKey) as? Int ?? defaultPhotoCount
        return min(photoCountRange.upperBound, max(photoCountRange.lowerBound, value))
    }

    static func shouldFinish(photoCount: Int, target: Int) -> Bool {
        photoCount >= max(1, target)
    }
}

enum CreateAutomaticName {
    /// Stille, Überspringen und leere Ergebnisse verwenden immer das aktuelle Namensschema.
    static func resolve(spoken: String?, fallback: String) -> String {
        let name = spoken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? fallback : name
    }
}

/// Liest das Kistenschema zum Zeitpunkt der Aufnahme, auch nach Einstellungsänderungen.
enum CreateBoxNameGenerator {
    static func nextName(id: UUID, defaults: UserDefaults = .standard) -> String {
        if defaults.bool(forKey: "useBoxUUIDasBoxName") { return "#" + id.uuidString.prefix(6) }
        let naming = defaults.object(forKey: "showBoxNameSheme") as? Bool ?? true
        let numbering = defaults.object(forKey: "showBoxNumberSheme") as? Bool ?? true
        let scheme = defaults.string(forKey: "boxNameScheme") ?? ""
        let prefix = naming ? NSLocalizedString(scheme.isEmpty ? "CreateView.Box" : scheme, comment: "") : ""
        let separator = scheme.isEmpty && naming && numbering ? " " : ""
        let number = numbering ? String(defaults.integer(forKey: "lastBoxID") + 1) : ""
        let name = prefix + separator + number
        return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? NSLocalizedString("CreateView.Box", comment: "Automatic box fallback") : name
    }
}

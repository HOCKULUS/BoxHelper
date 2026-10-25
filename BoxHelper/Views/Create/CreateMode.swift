import Foundation

/// Stable identifiers are shared by the form settings, draft storage and navigation.
enum CreateMode: String, CaseIterable, Codable, Sendable {
    case box, item, location

    /// Asset names for the custom add-form symbols used by the side buttons.
    var icon: String {
        switch self {
        case .box: return "custom.shippingbox.fill.badge.plus"
        case .item: return "custom.app.grid.2x2.fill.badge.plus"
        case .location: return "custom.location.fill.badge.plus"
        }
    }

    var title: String {
        switch self {
        case .box: return "Kiste erstellen"
        case .item: return "Item erstellen"
        case .location: return "Standort erstellen"
        }
    }

    var alternateModes: (left: CreateMode, right: CreateMode) {
        switch self {
        case .box: return (.item, .location)
        case .item: return (.box, .location)
        case .location: return (.item, .box)
        }
    }
}

enum CreateFormDefault: String, CaseIterable {
    case last, box, item, location

    var title: String {
        switch self {
        case .last: return "Letztes Formular merken"
        case .box: return CreateMode.box.title
        case .item: return CreateMode.item.title
        case .location: return CreateMode.location.title
        }
    }
}

struct CreateFormPreferences {
    static let defaultKey = "defaultCreateForm"
    static let lastModeKey = "lastCreateForm"
    static let locationNameAutofocusKey = "createLocationNameAutofocus"

    static func initialMode(defaults: UserDefaults = .standard) -> CreateMode {
        let preference = defaults.string(forKey: defaultKey).flatMap(CreateFormDefault.init(rawValue:)) ?? .last
        if preference == .last {
            // First launch and unknown remembered values both fall back to box creation.
            return defaults.string(forKey: lastModeKey).flatMap(CreateMode.init(rawValue:)) ?? .box
        }
        return CreateMode(rawValue: preference.rawValue) ?? .box
    }
}

/// Builds localized item names and keeps the optional sequence shared by both item creation forms.
enum CreateItemNameGenerator {
    private static let prefixKey = "itemNameScheme"
    private static let prefixEnabledKey = "showItemNameScheme"
    private static let numberingEnabledKey = "showItemNumberScheme"
    private static let lastNumberKey = "lastItemID"

    static var prefixEnabled: Bool { UserDefaults.standard.object(forKey: prefixEnabledKey) == nil
        ? true : UserDefaults.standard.bool(forKey: prefixEnabledKey) }
    static var numberingEnabled: Bool { UserDefaults.standard.object(forKey: numberingEnabledKey) == nil
        ? true : UserDefaults.standard.bool(forKey: numberingEnabledKey) }

    static func prefix(defaults: UserDefaults = .standard) -> String {
        let custom = defaults.string(forKey: prefixKey) ?? ""
        return custom.isEmpty ? NSLocalizedString("CreateView.Item", comment: "Default item name prefix") : custom
    }

    static func nextName(defaults: UserDefaults = .standard) -> String {
        let naming = defaults.object(forKey: prefixEnabledKey) as? Bool ?? true
        let numbering = defaults.object(forKey: numberingEnabledKey) as? Bool ?? true
        let components = [naming ? prefix(defaults: defaults) : "",
                          numbering ? String(defaults.integer(forKey: lastNumberKey) + 1) : ""]
            .filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }

    static func advanceNumberIfEnabled() {
        guard numberingEnabled else { return }
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: lastNumberKey) + 1, forKey: lastNumberKey)
    }
}

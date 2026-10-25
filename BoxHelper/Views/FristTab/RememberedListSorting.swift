import SwiftUI

/// Eine Sortierung bleibt während der Nutzung erhalten. Nur bei aktivierter Einstellung wird sie gespeichert.
// Binding-Zugriffe und das Speichern der UI-Auswahl teilen dieselbe Isolation.
@propertyWrapper
@MainActor
struct RememberedListSorting<Value>: DynamicProperty {
    static var enabledKey: String { "rememberListSorting" }

    @AppStorage("rememberListSorting") private var rememberSorting = true
    @State private var selection: Value
    private let persist: (Value) -> Void

    init(wrappedValue defaultValue: Value, _ key: String) where Value: RawRepresentable, Value.RawValue == String {
        let defaults = UserDefaults.standard
        let remembers = defaults.object(forKey: Self.enabledKey) == nil || defaults.bool(forKey: Self.enabledKey)
        // Den generischen Initializer direkt im Actor-Kontext aufrufen, statt
        // ihn als Funktionswert an eine nicht isolierte Closure zu übergeben.
        let saved: Value?
        if let rawValue = defaults.string(forKey: key) {
            saved = Value(rawValue: rawValue)
        } else {
            saved = nil
        }
        _selection = State(initialValue: remembers ? saved ?? defaultValue : defaultValue)
        persist = { defaults.set($0.rawValue, forKey: key) }
    }

    init(wrappedValue defaultValue: Value, _ key: String) where Value == Bool {
        let defaults = UserDefaults.standard
        let remembers = defaults.object(forKey: Self.enabledKey) == nil || defaults.bool(forKey: Self.enabledKey)
        let saved = defaults.object(forKey: key) as? Bool
        _selection = State(initialValue: remembers ? saved ?? defaultValue : defaultValue)
        persist = { defaults.set($0, forKey: key) }
    }

    var wrappedValue: Value {
        get { selection }
        nonmutating set {
            selection = newValue
            // Bei deaktiviertem Merken beeinflussen Änderungen ausschließlich den aktuellen View-Zustand.
            if rememberSorting { persist(newValue) }
        }
    }

    var projectedValue: Binding<Value> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}

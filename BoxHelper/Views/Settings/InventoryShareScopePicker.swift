import SwiftUI

/// Ein natives Dropdown bewahrt die Mehrfachauswahl, ohne das Formular zu verlängern.
struct InventoryShareScopePicker: View {
    struct Option: Identifiable {
        let id: UUID
        let name: String
        var displayName: String { name.isEmpty ? "Unbenannt" : name }
    }

    let title: LocalizedStringKey
    let options: [Option]
    @Binding var selection: Set<UUID>

    var body: some View {
        Menu {
            ForEach(options) { option in
                // Menu-Toggles zeigen native Häkchen und erlauben mehrere Wurzeln.
                Toggle(option.displayName, isOn: Binding(
                    get: { selection.contains(option.id) },
                    set: { selected in
                        if selected { selection.insert(option.id) }
                        else { selection.remove(option.id) }
                    }))
            }
        } label: {
            HStack {
                Text(title).foregroundStyle(.primary)
                Spacer()
                Text(selectionDescription).foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .menuActionDismissBehavior(.disabled)
        .disabled(options.isEmpty)
        .accessibilityValue(selectionDescription)
        .accessibilityHint("Mehrere Einträge können ausgewählt werden")
    }

    private var selectionDescription: String {
        if options.isEmpty { return "Keine verfügbar" }
        if selection.isEmpty { return "Auswählen" }
        if selection.count == 1, let option = options.first(where: { selection.contains($0.id) }) {
            return option.displayName
        }
        return "\(selection.count) ausgewählt"
    }
}

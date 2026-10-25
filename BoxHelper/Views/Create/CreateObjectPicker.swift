import SwiftUI

/// Leere Bestände bleiben verborgen. Neue Objekte werden in der separaten
/// Eingabe angelegt, nicht als künstlicher Eintrag zwischen bestehenden Namen.
struct CreateObjectPicker: View {
    let label: LocalizedStringKey
    let choices: [CreateChoice]
    @Binding var selection: UUID?

    var body: some View {
        if !choices.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                if choices.count <= 3 {
                    Text(label)
                    CreateObjectSegments(choices: choices, selection: $selection)
                        .frame(minWidth: 50, minHeight: 32).accessibilityLabel(label)
                } else {
                    HStack {
                        Text(label)
                        Spacer()
                        // Der native Menü-Picker zeichnet seinen Auswahlindikator rechts selbst.
                        Picker(label, selection: $selection) {
                            ForEach(choices) { choice in
                                Text(choice.name).tag(Optional(choice.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(minWidth: 50)
                        .accessibilityLabel(label)
                    }
                }
            }.padding(.vertical, 6)
        }
    }
}

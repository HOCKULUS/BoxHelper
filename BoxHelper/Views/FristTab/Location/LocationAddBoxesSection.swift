import SwiftUI

/// Zeigt die beiden Wege zum Hinzufügen; Speicherung und Zuordnung übernimmt die Detailansicht.
struct LocationAddBoxesSection: View {
    @Binding var newBoxName: String
    let hasAvailableBoxes: Bool
    let selectBoxes: () -> Void
    let createBox: () -> Void

    var body: some View {
        Section {
            Button(action: selectBoxes) {
                HStack {
                    Label("Kisten auswählen", systemImage: "shippingbox.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(!hasAvailableBoxes)

            HStack {
                TextField("Neue Kiste", text: $newBoxName)
                    .onSubmit(createBox)
                Button(action: createBox) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Neue Kiste")
                .disabled(newBoxName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

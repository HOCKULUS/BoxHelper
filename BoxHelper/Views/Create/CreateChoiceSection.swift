import SwiftUI

struct CreateChoice: Identifiable {
    let id: UUID
    let name: String
}

/// A labeled object picker and the new-entry row shared by box, item and location creation.
struct CreateChoiceSection: View {
    let label: LocalizedStringKey
    let choices: [CreateChoice]
    let newEntryLabel: LocalizedStringKey
    @FocusState private var isNewNameFocused: Bool
    @Binding var selection: UUID?
    @Binding var newName: String
    let add: () -> Void
    var qrCodeEventID: UUID? = nil

    var body: some View {
        Section {
            VStack {
                CreateObjectPicker(label: label, choices: choices,
                                   selection: $selection)
                    .modifier(CreateQRCodeInfo(eventID: qrCodeEventID))
                HStack {
                    TextField(newEntryLabel, text: $newName)
                        .focused($isNewNameFocused)
                        .onSubmit(add).frame(maxWidth: .infinity)
                    Button(action: add) { Image(systemName: "plus") }
                        .buttonStyle(.borderless)
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }

    }

}

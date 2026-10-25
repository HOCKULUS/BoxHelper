import SwiftUI

/// Alle vier Bestandslisten verwenden denselben Zustand für ihre eigene Auswahl
/// und SwiftUIs Bearbeitungsmodus. Es gibt keinen zweiten, separat zurückzusetzenden Wert.
struct FirstTabSelectionMode: ViewModifier {
    @Binding var isEditing: Bool

    func body(content: Content) -> some View {
        content.environment(\.editMode, nativeEditMode)
    }

    private var nativeEditMode: Binding<EditMode> {
        Binding(
            // Auch Löschaktionen und lange Berührungen ändern diese Auswahlbindung.
            // Der native Modus folgt deshalb jeder Änderung, nicht nur den Toolbar-Buttons.
            get: { isEditing ? .active : .inactive },
            // Native Bearbeitungsaktionen müssen ebenfalls die eigene Auswahl-UI mitnehmen.
            set: { isEditing = $0.isEditing }
        )
    }
}

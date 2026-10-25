import SwiftUI

/// Eigene Fokuswahl für Standorte; die Gegenstandseinstellungen bleiben unabhängig.
struct CreateLocationFocusSettingsSection: View {
    @AppStorage(CreateFormPreferences.locationNameAutofocusKey) private var autofocusName = false

    var body: some View {
        Section {
            Toggle("CreatePreferences.LocationFocus.Name", isOn: $autofocusName)
        } header: {
            Text("CreatePreferences.LocationFocus.Header")
        } footer: {
            Text("CreatePreferences.LocationFocus.Footer")
        }
    }
}

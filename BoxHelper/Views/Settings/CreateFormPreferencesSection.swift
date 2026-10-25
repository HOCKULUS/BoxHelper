import SwiftUI

/// Beide Einstellungsseiten bearbeiten dieselbe Wahl des Startformulars.
struct CreateFormPreferencesSection: View {
    @AppStorage(CreateFormPreferences.defaultKey) private var preference = CreateFormDefault.last.rawValue
    @AppStorage("fixedCreateForm") private var fixedForm = CreateMode.box.rawValue

    private var launchMode: Binding<String> {
        Binding(get: { preference == CreateFormDefault.last.rawValue ? "remember" : "fixed" }, set: { value in
            if value == "remember" {
                if CreateMode(rawValue: preference) != nil { fixedForm = preference }
                preference = CreateFormDefault.last.rawValue
            } else { preference = CreateMode(rawValue: fixedForm)?.rawValue ?? CreateMode.box.rawValue }
        })
    }

    private var formSelection: Binding<String> {
        Binding(get: { CreateMode(rawValue: preference)?.rawValue ?? CreateMode.box.rawValue }, set: { value in
            fixedForm = value
            preference = value
        })
    }

    var body: some View {
        Section {
            Picker("CreatePreferences.StartForm", selection: launchMode) {
                Label("Last visited", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90").tag("remember")
                Label("Eigenen", systemImage: "slider.horizontal.3").tag("fixed")
            }.pickerStyle(.segmented)
            if preference != CreateFormDefault.last.rawValue {
                Picker("Standardformular", selection: formSelection) {
                    // Formularnamen im Einstellungspicker ohne Icons anzeigen.
                    ForEach(CreateMode.allCases, id: \.rawValue) { form in
                        Text(LocalizedStringKey(form.title)).tag(form.rawValue)
                    }
                }.pickerStyle(.menu)
            }
        } header: { Text("CreatePreferences.Header") }
        footer: { Text("CreatePreferences.Footer") }
    }
}

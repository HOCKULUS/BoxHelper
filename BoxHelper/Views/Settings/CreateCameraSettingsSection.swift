import SwiftUI

/// Gemeinsame Kameraoptionen und die Zugänge zu beiden Automationsseiten.
struct CreateCameraSettingsSection: View {
    @AppStorage(FeedSensitivityLevel.hintsKey) private var hints = true
    @State private var advancedSettingsVisible = false
    @State private var unlock = FeedAdvancedSettingsUnlock()

    var body: some View {
        Section {
            Toggle("CreateCamera.Hints", isOn: $hints)
            // Die gespeicherte dynamische Geschwindigkeit wird hier nicht mehr angeboten.
            // Kisten stehen vor Gegenständen; die Optionen liegen auf eigenen Seiten.
            NavigationLink {
                CreateCameraAutomationSettingsView(form: .box)
            } label: {
                Text("CreateCamera.SmartBoxes").foregroundStyle(.primary)
            }
            NavigationLink {
                CreateCameraAutomationSettingsView(form: .item)
            } label: {
                Text("CreateCamera.SmartItems").foregroundStyle(.primary)
            }
        } header: {
            Text("CreateCamera.SettingsTitle")
                // Der bestehende versteckte Expertenzugang zieht mit der Überschrift um.
                .onTapGesture {
                    if unlock.record(at: ProcessInfo.processInfo.systemUptime) { advancedSettingsVisible = true }
                }
        }
        .onAppear { FeedSensitivityLevel.prepareDefaults() }
        if advancedSettingsVisible { FeedMonitoringAdvancedSettingsSection() }
    }

}

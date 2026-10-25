import SwiftUI

/// Eigene Navigation für beide Formulare; Speicherwerte und QR-Erkennung bleiben geteilt.
struct CreateCameraAutomationSettingsView: View {
    enum Form {
        case box, item
        var title: LocalizedStringKey { self == .box ? "CreateCamera.SmartBoxes" : "CreateCamera.SmartItems" }
        var dictationTitle: LocalizedStringKey { self == .box ? "CreateCamera.BoxDictation" : "CreateCamera.ItemDictation" }
    }

    let form: Form
    @EnvironmentObject private var accentColorManager: AccentColorManager
    @AppStorage private var enabled: Bool
    @AppStorage private var photoCount: Int
    @AppStorage private var voiceNaming: Bool
    @AppStorage(CreateCameraPreferences.qrCodeKey) private var qrCodes = true
    @AppStorage(BoxAutomaticCapturePolicy.locationNamingKey) private var locationDictation = true

    init(form: Form) {
        self.form = form
        // Beide Formulare starten mit Automatik; gespeicherte Entscheidungen haben Vorrang.
        _enabled = AppStorage(wrappedValue: true,
                              form == .box ? CreateCameraPreferences.boxSmartCameraKey : CreateCameraPreferences.itemSmartCameraKey)
        _photoCount = AppStorage(wrappedValue: 1,
                                 form == .box ? BoxAutomaticCapturePolicy.photoCountKey : AutomaticCaptureBatch.itemPhotoCountKey)
        _voiceNaming = AppStorage(wrappedValue: true,
                                  form == .box ? BoxAutomaticCapturePolicy.voiceNamingKey : CreateCameraPreferences.itemVoiceNamingKey)
    }

    var body: some View {
        SwiftUI.Form {
            Section {
                Toggle(form.title, isOn: $enabled)
                // Ausschalten bewahrt die sichtbaren Optionen und ihre gespeicherten Werte.
                Group {
                    Toggle("CreateCamera.QRRecognition", isOn: $qrCodes)
                    Stepper(value: $photoCount, in: AutomaticCaptureBatch.photoCountRange) {
                        HStack {
                            Text("CreateCamera.PhotosPerRun")
                            Spacer()
                            Text("\(photoCount)").monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    Toggle(form.dictationTitle, isOn: $voiceNaming)
                    if form == .box {
                        Toggle("CreateCamera.LocationDictation", isOn: $locationDictation)
                    }
                }
                .disabled(!enabled)
            }
        }
        .navigationTitle(form.title)
        .navigationBarTitleDisplayMode(.inline)
        .tint(accentColorManager.accentColor)
    }
}

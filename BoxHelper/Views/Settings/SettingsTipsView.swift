import SwiftUI
import TipKit

struct SettingsTipsView: View {
    var iconBackgroundColor: Color

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(iconBackgroundColor)
                                .frame(width: 70, height: 70)

                            Image(systemName: "lightbulb.max.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 10)
                        Spacer()
                    }

                    Text("Tips")
                        .font(.system(size: 25, weight: .bold))

                    Text("Verwalte hier alle App-Hinweise. Du kannst sie komplett beenden oder den Fortschritt aller Tips zurücksetzen.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 10)
                }
            }

            Section("Anzeige") {
                Button(role: .destructive) {
                    stopAllKnownTips()
                    alertTitle = String(localized: "Beendet")
                    alertMessage = String(localized: "Alle bekannten Tips wurden beendet.")
                    showAlert = true
                } label: {
                    Text("Tips beenden")
                }
            }

            Section("Verlauf") {
                Button {
                    try? Tips.resetDatastore()
                    alertTitle = String(localized: "Zurückgesetzt")
                    alertMessage = String(localized: "Alle Tip-Fortschritte wurden zurückgesetzt.")
                    showAlert = true
                } label: {
                    Text("Alle Tips zurücksetzen")
                }
            }
        }
        .navigationTitle("Tips")
        .navigationBarTitleDisplayMode(.inline)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func stopAllKnownTips() {
        helpNeeded().invalidate(reason: .tipClosed)
        changeImageOrder().invalidate(reason: .tipClosed)
        introduceBoxNaming().invalidate(reason: .tipClosed)
        oldIOSVersion().invalidate(reason: .tipClosed)
        Backup().invalidate(reason: .tipClosed)
        changeLocationColors().invalidate(reason: .tipClosed)
        customizableQRCodeTip().invalidate(reason: .tipClosed)
    }
}

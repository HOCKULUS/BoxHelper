import SwiftUI
import UIKit

/// Die Speicheroption bleibt von Import- und Backup-Formularen getrennt.
@MainActor
struct InventoryCloudSyncSection: View {
    var title: LocalizedStringKey? = nil
    @ObservedObject private var cloudSync = InventoryCloudSyncState.shared
    @State private var isApplyingChange = false
    @State private var changeError: String?
    @AppStorage(InventoryCloudPreferencesStore.enabledKey) private var syncAppPreferences = false
    @AppStorage(InventoryCloudFormSync.enabledKey) private var syncForms = false

    var body: some View {
        Section {
            Toggle("Inventar synchronisieren", isOn: syncPreference)
            .disabled(isApplyingChange || cloudSync.isChanging)
            .accessibilityIdentifier("settings.inventoryCloudSync.toggle")

            Toggle("Einstellungen synchronisieren", isOn: Binding(
                get: { syncAppPreferences },
                set: { InventoryCloudPreferencesStore.shared.setEnabled($0) }))
                .disabled(!cloudSync.isActive || cloudSync.isChanging)
                .accessibilityIdentifier("settings.iCloud.preferences.toggle")

            Toggle("Formulare synchronisieren", isOn: Binding(
                get: { syncForms },
                set: { enabled in
                    InventoryCloudFormSync.shared.setEnabled(enabled)
                    if enabled {
                        do { try InventoryHandoffStore.shared.saveCurrentFormsToCloud() }
                        catch { changeError = error.localizedDescription }
                    }
                }))
                .disabled(!cloudSync.isActive || cloudSync.isChanging)
                .accessibilityIdentifier("settings.iCloud.forms.toggle")

            statusRow("iCloud-Account", value: cloudSync.accountStatusDescription)
            // Erfolgreiche Abgleiche erhalten einen knappen Status ohne Zeitstempel.
            statusRow("Status", value: cloudSync.indicator == .synced ? "Aktuell" : cloudSync.syncStatusDescription)

            if cloudSync.isChangingConfiguration {
                HStack {
                    ProgressView()
                    Text("iCloud-Einstellung wird übernommen …")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage = cloudSync.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            if let title { Text(title) }
        } footer: {
            Text("Synchronisiert Kisten, Items, Standorte und Fotos auf deinen Geräten. Änderungen werden sofort übernommen; der erste Abgleich kann etwas dauern. Formulare werden optional mit ihren Fotos in iCloud gesichert und beim Öffnen auf deinen Geräten automatisch fortgesetzt. Beim Ausschalten bleiben lokale und bereits in iCloud gespeicherte Daten erhalten.")
        }
        .task {
            await cloudSync.refreshAccountStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Ein geänderter iCloud-Login erscheint nach der Rückkehr aus den Systemeinstellungen.
            Task { await cloudSync.refreshAccountStatus() }
        }
        .alert("iCloud-Synchronisierung nicht möglich", isPresented: Binding(
            get: { changeError != nil },
            set: { if !$0 { changeError = nil } }
        )) {
            Button("OK", role: .cancel) { changeError = nil }
        } message: {
            Text(changeError ?? "")
        }
    }

    private var syncPreference: Binding<Bool> {
        Binding(
            get: { cloudSync.isEnabled },
            set: { enabled in
                guard !isApplyingChange, !cloudSync.isChanging else { return }
                // Auch die kurze Zeit bis zum Start des Tasks sperrt weitere Toggle-Eingaben.
                isApplyingChange = true
                Task {
                    defer { isApplyingChange = false }
                    do {
                        try await cloudSync.setEnabled(enabled)
                    } catch {
                        changeError = error.localizedDescription
                    }
                }
            }
        )
    }

    private func statusRow(_ title: LocalizedStringKey, value: String) -> some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        } label: {
            Text(title)
        }
        .font(.subheadline)
    }
}

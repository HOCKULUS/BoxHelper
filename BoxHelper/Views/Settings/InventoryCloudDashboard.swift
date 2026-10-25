import CloudKit
import SwiftUI

struct PresentedInventoryShare: Identifiable {
    let share: CKShare
    var access: InventoryShareScope.Access = .readWrite
    var id: String { share.recordID.recordName + share.recordID.zoneID.zoneName }
}

/// Derselbe Einstieg ist aus Listen, Detailansichten, Formularen und Einstellungen erreichbar.
struct InventoryCloudDashboard: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accentColorManager: AccentColorManager
    @ObservedObject private var cloud = InventoryCloudSyncState.shared
    @ObservedObject private var sharing = InventorySharingService.shared

    var body: some View {
        NavigationStack {
            Form {
                InventoryCloudSyncSection()
                Section {
                    NavigationLink {
                        InventorySharingView()
                    } label: { Text("Inventar freigeben") }
                } footer: {
                    Text("Teile dein Inventar oder ausgewählte Standorte und Kisten. Unter „Inventar freigeben“ erstellst und verwaltest du deine Freigabe.")
                }
                Section {
                    Button("Jetzt aktualisieren") {
                        sharing.requestSync()
                        InventoryCloudSyncCoordinator.shared.scheduleReconciliation(refreshInventory: true)
                        Task { await cloud.refreshAccountStatus() }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(!cloud.isActive || cloud.isChanging || sharing.isSyncing || cloud.isSynchronizing)
                } footer: {
                    Text("Der Abgleich läuft automatisch. Bei vielen Daten oder Fotos kann die erste Synchronisierung etwas dauern.")
                }
                InventoryCloudDeletionSection()
            }
            // Schalter und Auswahlkontrollen übernehmen die gewählte App-Farbe.
            .tint(accentColorManager.accentColor)
            .navigationTitle("iCloud")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Gleicher Abschlussbutton wie im Auswahlmodus der Bestandslisten.
                    Button("Fertig", systemImage: "checkmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderedProminent)
                        .tint(accentColorManager.accentColor)
                }
            }
            .task { sharing.start(); sharing.requestSync() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                sharing.requestSync()
            }
        }
    }

}

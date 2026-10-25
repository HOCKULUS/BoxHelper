import SwiftUI

/// Cloud-Daten werden direkt im Menü bestätigt; der lokale Bestand bleibt erhalten.
struct InventoryCloudDeletionSection: View {
    var title: LocalizedStringKey = "Löschen"
    var showsStorageSize = false
    @ObservedObject private var cloud = InventoryCloudSyncState.shared
    @ObservedObject private var storage = InventoryStorageState.shared
    @State private var estimatedSize: String = "—"

    var body: some View {
        Section {
            if showsStorageSize {
                LabeledContent("iCloud.EstimatedSize") {
                    Text(estimatedSize).foregroundStyle(.secondary)
                }
                .foregroundStyle(.secondary)
            }
            InlineDeletionButton(
                title: title,
                confirmationMessage: "Alle BoxHelper-Daten in deinem iCloud-Account werden endgültig gelöscht. Eigene Freigaben werden beendet, Freigaben anderer Personen verlassen. Lokale Daten bleiben erhalten.",
                progressTitle: "iCloud-Daten werden gelöscht …",
                successMessage: "iCloud-Daten wurden gelöscht.",
                failureMessage: "Die Löschung konnte nicht vollständig abgeschlossen werden. Ein Teil der Daten kann bereits gelöscht sein. Bitte versuche es erneut.",
                isDisabled: cloud.isChanging,
                accessibilityIdentifier: "icloud.delete") {
                    try await InventoryCloudDeletion.deleteAll()
                }
        } header: {
            if !showsStorageSize { Text("iCloud") }
        } footer: {
            // isActive beschreibt den tatsächlich geöffneten Store.
            if cloud.isActive {
                Text("iCloud ist aktiv. Die Daten werden erneut hoch geladen.")
            }
        }
        .task(id: cloud.isActive && !cloud.isChanging ? storage.revision : nil) {
            guard showsStorageSize, cloud.isActive, !cloud.isChanging else { estimatedSize = "—"; return }
            do {
                let container = try InventoryPersistence.prepare().container
                let bytes = try await InventoryCloudStorageWorker.load(container: container)
                try Task.checkCancellation()
                estimatedSize = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            } catch is CancellationError {
                // Ein neuer Syncstand oder Storewechsel startet die Anzeige erneut.
            } catch { estimatedSize = "—" }
        }
    }
}

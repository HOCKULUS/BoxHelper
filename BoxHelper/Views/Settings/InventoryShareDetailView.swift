import CloudKit
import SwiftUI

/// Aktive Freigaben zeigen Informationen und Aktionen auf der gemeinsamen Freigabeseite.
struct InventoryShareDetailView: View {
    let descriptor: InventoryShareDescriptor
    var selectableShares: [InventoryShareDescriptor] = []
    @Binding var selectedShareID: String
    @ObservedObject private var cloud = InventoryCloudSyncState.shared
    @ObservedObject private var sharing = InventorySharingService.shared
    @State private var presentedShare: PresentedInventoryShare?
    @State private var showsEndConfirmation = false
    @State private var isPerformingAction = false
    @State private var error: String?

    // Nach einem iCloud-Abgleich bleibt auch eine bereits geöffnete Seite aktuell.
    private var currentShare: InventoryShareDescriptor {
        sharing.shares.first { $0.id == descriptor.id } ?? descriptor
    }

    private var canManage: Bool {
        cloud.isActive && currentShare.isAvailable
            && sharing.shares.contains { $0.id == descriptor.id }
            && !sharing.isSyncing && !isPerformingAction
    }

    var body: some View {
        Form {
            if selectableShares.count > 1 {
                Section {
                    Picker("Freigabe", selection: Binding(
                        get: { currentShare.id },
                        set: { selectedShareID = $0 })) {
                        ForEach(selectableShares) { share in
                            Text(share.title).tag(share.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            Section {
                LabeledContent("Name", value: currentShare.title)
                LabeledContent("Status", value: currentShare.statusDescription)
                LabeledContent("Daten", value: scopeDescription)
                LabeledContent("Zugriffsrechte", value: permissions)
                LabeledContent("Bilder", value: currentShare.scope.sharesImages ? "Mit Bildern" : "Ohne Bilder")
            }
            if let participants = currentShare.participants, !participants.isEmpty {
                Section("Teilnehmende") {
                    ForEach(Array(participants.enumerated()), id: \.offset) { _, participant in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(participant.name)
                            Text("\(participant.accepted ? "Angenommen" : "Ausstehend") · \(participant.canEdit ? "Bearbeiten" : "Nur lesen")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if currentShare.isAvailable {
                Section {
                    Button(action: manageShare) {
                        Text("Freigabe verwalten")
                            .frame(maxWidth: .infinity, alignment: .center)
                            // Die Ladeanzeige verschiebt die zentrierte Beschriftung nicht.
                            .overlay(alignment: .trailing) {
                                if isPerformingAction { ProgressView() }
                            }
                    }
                    .disabled(!canManage)
                } footer: {
                    Text("Einladungen und Teilnehmende verwaltest du im iCloud-Dialog.")
                }
                Section {
                    Button(currentShare.isOwner ? "Freigabe beenden" : "Teilung verlassen", role: .destructive) {
                        showsEndConfirmation = true
                    }
                    .tint(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(!canManage)
                }
            }
            if sharing.shares.contains(where: { $0.isAvailable && !$0.isOwner && $0.canEdit && $0.scope.kind == .inventory }) {
                creationDestinationSection
            }
            if let message = sharing.errorMessage {
                Section { Text(message).font(.footnote).foregroundStyle(.red) }
            }
            if let message = sharing.notice {
                Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .confirmationDialog(currentShare.isOwner ? "Freigabe beenden?" : "Teilung verlassen?",
                            isPresented: $showsEndConfirmation, titleVisibility: .visible) {
            Button(currentShare.isOwner ? "Für alle beenden" : "Teilung verlassen", role: .destructive,
                   action: endShare)
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Der gemeinsame Zugriff endet. Bereits geladene lokale Daten bleiben erhalten.")
        }
        .sheet(item: $presentedShare) {
            InventoryCloudSharingController(share: $0.share, access: $0.access)
        }
        .alert("iCloud", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    private var scopeDescription: String {
        switch currentShare.scope.kind {
        case .inventory: "Gesamtes Inventar"
        case .locations: "Standorte mit Kisten und Items"
        case .boxes: "Kisten mit Items"
        }
    }

    private var permissions: String {
        let editable = currentShare.isOwner ? currentShare.scope.allowsEditing : currentShare.canEdit
        return editable ? "Bearbeiten" : "Nur lesen"
    }

    private var creationDestinationSection: some View {
        Section {
            Picker("Neue unabhängige Daten", selection: Binding(
                get: { sharing.creationShareID ?? "" },
                set: { value in
                    do { try sharing.selectCreationShare(value.isEmpty ? nil : value) }
                    catch { self.error = error.localizedDescription }
                })) {
                Text("Privat anlegen").tag("")
                ForEach(sharing.shares.filter { $0.isAvailable && !$0.isOwner && $0.canEdit && $0.scope.kind == .inventory }) {
                    Text($0.title).tag($0.id)
                }
            }
            .pickerStyle(.menu)
        } footer: {
            Text("Neue Items in geteilten Kisten und neue Kisten an geteilten Standorten folgen ihrer Freigabe automatisch. Für neue unabhängige Daten entscheidest du hier, ob sie privat oder gemeinsam angelegt werden.")
        }
    }

    private func manageShare() {
        guard canManage else { return }
        let share = currentShare
        isPerformingAction = true
        Task {
            defer { isPerformingAction = false }
            do {
                presentedShare = PresentedInventoryShare(
                    share: try await sharing.shareForManagement(share),
                    access: share.scope.access ?? .readWrite)
            } catch { self.error = error.localizedDescription }
        }
    }

    private func endShare() {
        guard canManage else { return }
        let share = currentShare
        isPerformingAction = true
        Task {
            defer { isPerformingAction = false }
            do {
                try await sharing.end(share)
                // Die übergeordnete Seite zeigt nach dem Widerruf das Erstellformular.
            } catch { self.error = error.localizedDescription }
        }
    }
}

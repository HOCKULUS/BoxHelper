import CloudKit
import SwiftUI

struct NewInventoryShareView: View {
    @ObservedObject private var cloud = InventoryCloudSyncState.shared
    @ObservedObject private var sharing = InventorySharingService.shared
    @ObservedObject private var storage = InventoryStorageState.shared
    @State private var kind = InventoryShareScope.Kind.inventory
    @State private var selected: Set<UUID> = []
    // Der vorbelegte Freigabename folgt der App-Sprache und bleibt frei editierbar.
    @State private var title = String(localized: "Gemeinsames Inventar", comment: "Default editable name for a new shared inventory.")
    @State private var access = InventoryShareScope.Access.readWrite
    @State private var includeImages = true
    @Binding var isCreating: Bool
    @State private var error: String?
    @Binding var presentedShare: PresentedInventoryShare?

    var body: some View {
        Form {
            if !cloud.isActive {
                Section {
                    Text(cloud.isEnabled
                         ? "Prüfe den iCloud-Status und aktiviere die Synchronisierung erneut."
                         : "Aktiviere iCloud, um Inventar freizugeben.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "a.square")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("Name der Freigabe", text: $title)
                }
                Picker("Daten", selection: $kind) {
                    Text("Gesamtes Inventar").tag(InventoryShareScope.Kind.inventory)
                    Text("Standorte mit Kisten und Items").tag(InventoryShareScope.Kind.locations)
                    Text("Kisten mit Items").tag(InventoryShareScope.Kind.boxes)
                }
                .pickerStyle(.menu)
                .onChange(of: kind) { _, _ in selected = [] }
                if kind != .inventory {
                    InventoryShareScopePicker(
                        title: kind == .locations ? "Standorte" : "Kisten",
                        options: scopeOptions,
                        selection: $selected)
                }
            } footer: {
                Text(kind == .inventory
                     ? "Dein gesamtes Inventar und zukünftig angelegte Daten werden geteilt."
                     : "Zugehörige Items sind enthalten. Bilder werden nach deiner Auswahl geteilt. Neue Items und Kisten innerhalb der Auswahl folgen automatisch. Daten außerhalb dieser Auswahl bleiben privat.")
            }
            Section {
                Picker("Recht", selection: $access) {
                    Text("Nur lesen").tag(InventoryShareScope.Access.readOnly)
                    Text("Bearbeiten").tag(InventoryShareScope.Access.readWrite)
                }
                .pickerStyle(.menu)
                if access == .readOnly { Toggle("Mit Bildern", isOn: $includeImages) }
            } header: {
                Text("Zugriffsrechte")
            } footer: {
                Text("Bearbeiten enthält Bilder. Ohne Bilder werden weder Fotos noch Bildverweise geteilt.")
            }
            Section {
                Button {
                    isCreating = true
                    Task {
                        defer { isCreating = false }
                        do {
                            let (_, share) = try await sharing.create(
                                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                scope: InventoryShareScope(kind: kind, roots: selected, access: access,
                                                           includeImages: access == .readWrite || includeImages))
                            presentedShare = PresentedInventoryShare(share: share, access: access)
                        } catch { self.error = error.localizedDescription }
                    }
                } label: {
                    HStack { Text("Freigabe vorbereiten"); if isCreating { Spacer(); ProgressView() } }
                }
                .disabled(isCreating || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || (kind != .inventory && selected.isEmpty))
            } footer: {
                Text("Anschließend wählst du im iCloud-Dialog die Teilnehmenden aus. Die Einladung verwendet die gewählten Zugriffsrechte.")
            }
            if let message = sharing.errorMessage {
                Section { Text(message).font(.footnote).foregroundStyle(.red) }
            }
            if let message = sharing.notice {
                Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .disabled(isCreating || !cloud.isActive || cloud.isChanging || sharing.isSyncing)
        .alert("Freigabe nicht möglich", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
        .onChange(of: storage.revision) { _, _ in
            let valid = kind == .locations ? Set(loadLocations().map(\.id)) : Set(loadBoxes().map(\.id))
            selected.formIntersection(valid)
        }
    }

    private var scopeOptions: [InventoryShareScopePicker.Option] {
        if kind == .locations {
            return loadLocations().map { .init(id: $0.id, name: $0.name) }
        }
        return loadBoxes().map { .init(id: $0.id, name: $0.name) }
    }
}

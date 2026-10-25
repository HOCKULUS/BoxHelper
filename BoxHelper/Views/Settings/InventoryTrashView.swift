import SwiftUI

/// Identische 4:3-Karten für alle Datenarten, mit zwei bis sechs Spalten.
struct InventoryTrashView: View {
    @StateObject private var controller = InventoryTrashController()
    @State private var pendingDeletion: Set<UUID>?
    @State private var pendingRetention: Int?

    var body: some View {
        GeometryReader { geometry in
            let count = min(6, max(2, Int((geometry.size.width - 32) / 180)))
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    settings
                    if controller.entries.isEmpty {
                        ContentUnavailableView("Trash.Empty", systemImage: "trash", description: Text("Trash.EmptyDescription"))
                            .frame(maxWidth: .infinity)
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: count), spacing: 12) {
                            ForEach(controller.entries) { entry in
                                InventoryTrashCard(entry: entry, photo: entry.images.compactMap { controller.photos[$0] }.first,
                                    retentionDays: controller.retentionDays,
                                    restore: { controller.restore([entry.id]) },
                                    delete: { pendingDeletion = [entry.id] })
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Trash.Title")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Trash.RestoreAll", systemImage: "arrow.uturn.backward") {
                        controller.restore(Set(controller.entries.map(\.id)))
                    }
                    Button("Trash.DeleteAll", systemImage: "trash", role: .destructive) {
                        pendingDeletion = Set(controller.entries.map(\.id))
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.bold())
                }
                .disabled(controller.entries.isEmpty || controller.isBusy)
                .accessibilityLabel(Text("Trash.AllActions"))
            }
        }
        .disabled(controller.isBusy)
        .overlay { if controller.isBusy { ProgressView().padding().background(.regularMaterial, in: Capsule()) } }
        .onAppear { controller.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryTrashDidChange)) { _ in controller.reload() }
        .alert("Trash.DeleteTitle", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })) {
            Button("Trash.Delete", role: .destructive) {
                if let ids = pendingDeletion { controller.delete(ids) }
                pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: { Text("Trash.DeleteMessage") }
        .alert("Trash.RetentionTitle", isPresented: Binding(get: { pendingRetention != nil }, set: { if !$0 { pendingRetention = nil } })) {
            Button("Trash.ApplyRetention", role: .destructive) {
                if let days = pendingRetention { controller.setRetention(days) }
                pendingRetention = nil
            }
            Button("Cancel", role: .cancel) { pendingRetention = nil }
        } message: { Text("Trash.RetentionMessage") }
        .alert("Trash.Error", isPresented: Binding(get: { controller.errorMessage != nil }, set: { if !$0 { controller.errorMessage = nil } })) {
            Button("OK", role: .cancel) { controller.errorMessage = nil }
        } message: { Text(controller.errorMessage ?? "") }
    }

    private var settings: some View {
        HStack(spacing: 12) {
            Label("Trash.Retention", systemImage: "clock")
                .font(.headline)
            Spacer(minLength: 0)
            Picker("Trash.Retention", selection: Binding(get: { controller.retentionDays }, set: { days in
                if days < controller.retentionDays { pendingRetention = days }
                else { controller.setRetention(days) }
            })) {
                ForEach(InventoryTrashStore.retentionOptions, id: \.self) { days in
                    if days == 0 { Text("Trash.Disabled").tag(days) }
                    else { Text("Trash.Days \(days)").tag(days) }
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

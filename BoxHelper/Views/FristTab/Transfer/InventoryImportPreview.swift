import SwiftUI

struct InventoryImportPreview: View {
    @State var payload: InventoryTransfer
    let directory: URL
    let onImport: (InventoryTransfer.Kind) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showDuplicates = false
    @State private var errorMessage: String?
    @State private var isImporting = false

    private struct Row: Identifiable {
        let id: String
        let title: String
        let detail: String
        let image: String?
        let duplicate: Bool
    }

    private func rows(for kind: InventoryTransfer.Kind) -> [Row] {
        switch kind {
        case .boxes:
            let ids = Set(loadBoxes().map(\.id))
            return payload.boxes.map { box in
                Row(id: "box-\(box.id)", title: box.name,
                    detail: String(localized: "Items") + ": \(payload.items.filter { $0.box_uuid == box.id }.count) · " + String(localized: "Images") + ": \(box.images.count)",
                    image: box.images.first, duplicate: ids.contains(box.id))
            }
        case .items:
            let ids = Set(loadItems().map(\.id))
            return payload.items.map { item in
                Row(id: "item-\(item.id)", title: item.name,
                    detail: item.box_uuid.flatMap { id in payload.boxes.first { $0.id == id }?.name } ?? item.description ?? "",
                    image: item.images.first, duplicate: ids.contains(item.id))
            }
        case .locations:
            let ids = Set(loadLocations().map(\.id))
            return payload.locations.map { location in
                Row(id: "location-\(location.id)", title: location.name,
                    detail: String(localized: "Boxes") + ": \(payload.boxes.filter { $0.location_uuid == location.id }.count)",
                    image: location.image.isEmpty ? nil : location.image, duplicate: ids.contains(location.id))
            }
        case .images:
            return payload.images.map { image in
                Row(id: "image-\(image.filename)", title: image.title, detail: image.filename, image: image.filename,
                    duplicate: FileManager.default.fileExists(atPath: InventoryTransferArchive.documents.appendingPathComponent(image.filename).path))
            }
        }
    }

    private let kinds: [InventoryTransfer.Kind] = [.boxes, .items, .locations, .images]
    private var duplicateCount: Int { kinds.flatMap { rows(for: $0) }.filter(\.duplicate).count }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Objekte", value: "\(payload.count)")
                    LabeledContent("Duplikate", value: "\(duplicateCount)")
                }
                ForEach(kinds, id: \.rawValue) { kind in
                    let entries = rows(for: kind)
                    if !entries.isEmpty {
                        Section(LocalizedStringKey(returnNavigationLabel(kind.rawValue))) {
                            ForEach(entries) { row in
                                HStack(spacing: 12) {
                                    Menu {
                                        Button("Entfernen", systemImage: "trash", role: .destructive) { payload.remove(row.id) }
                                    } label: {
                                        Image(systemName: "ellipsis").frame(width: 32, height: 44)
                                    }
                                    .accessibilityLabel("Aktionen")
                                    thumbnail(row, kind: kind)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(row.title.isEmpty ? "—" : row.title).font(.headline)
                                        if !row.detail.isEmpty { Text(row.detail).font(.caption).foregroundStyle(.secondary) }
                                        if row.duplicate { Label("Duplikat", systemImage: "square.on.square").font(.caption).foregroundStyle(.orange) }
                                    }
                                }
                                .swipeActions {
                                    Button("Entfernen", role: .destructive) { payload.remove(row.id) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Importieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Abbrechen", systemImage: "xmark", role: .cancel) { dismiss() }.tint(.red)
                }
                ToolbarItem(placement: .bottomBar) { Spacer() }
                ToolbarItem(placement: .bottomBar) {
                    Button("Importieren", systemImage: "square.and.arrow.down") {
                        if duplicateCount > 0 { showDuplicates = true } else { commit(overwrite: false) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(payload.count == 0 || isImporting)
                }
            }
            .alert("Duplikate", isPresented: $showDuplicates) {
                Button("Überschreiben", role: .destructive) { commit(overwrite: true) }
                Button("Überspringen") { commit(overwrite: false) }.keyboardShortcut(.defaultAction)
                Button("Abbrechen", role: .cancel) { }
            } message: { Text("Wie soll mit den Duplikaten umgegangen werden?") }
            .alert("Import fehlgeschlagen", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { }
            } message: { Text(errorMessage ?? "") }
            .interactiveDismissDisabled(isImporting)
            .disabled(isImporting)
        }
    }

    @ViewBuilder private func thumbnail(_ row: Row, kind: InventoryTransfer.Kind) -> some View {
        if let name = row.image,
           let image = UIImage(contentsOfFile: directory.appendingPathComponent("contents").appendingPathComponent(name).path) {
            Image(uiImage: image).resizable().scaledToFill().frame(width: 48, height: 48).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: returnNavigationSymbol(kind.rawValue)).frame(width: 48, height: 48).foregroundStyle(.secondary)
        }
    }

    private func commit(overwrite: Bool) {
        isImporting = true
        do {
            try InventoryTransferArchive.commit(payload, from: directory, overwrite: overwrite)
            onImport(payload.kind)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
        isImporting = false
    }
}

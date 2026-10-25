import SwiftUI

/// Gemeinsames Verschieben-Popup mit umschaltbarer Zielauswahl für Kisten und Gegenstände.
struct MoveImagesSheetView: View {
    let selection: [ImageMoveSelection]
    let selectedNamesText: String
    let onMoveConfirmed: (ImageMoveTarget) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var boxes = loadBoxes()
    @State private var items = loadItems()
    @State private var locations = loadLocations()
    @State private var destinationList = DestinationList.boxes
    @State private var searchText = ""
    @State private var pendingTarget: Destination?
    @State private var showConfirmation = false
    @State private var errorMessage: String?

    private enum DestinationList { case boxes, items }
    private struct Destination: Identifiable {
        let id: ImageMoveTarget
        let name: String
        let detail: String
        let imageCount: Int
    }

    private var destinations: [Destination] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates: [Destination]
        switch destinationList {
        case .boxes:
            candidates = boxes.map { box in
                Destination(id: .box(box.id), name: box.name,
                            detail: locations.first { $0.id == box.location_uuid }?.name ?? "",
                            imageCount: box.images.count)
            }
        case .items:
            candidates = items.map { item in
                Destination(id: .item(item.id), name: item.name,
                            detail: boxes.first { $0.id == item.box_uuid }?.name ?? "",
                            imageCount: item.images.count)
            }
        }
        return candidates.filter { candidate in
            // Gemischte Auswahlen dürfen auch zu einer ihrer Quellen verschoben werden.
            selection.contains { $0.source != candidate.id }
                && (query.isEmpty || candidate.name.localizedCaseInsensitiveContains(query)
                    || candidate.detail.localizedCaseInsensitiveContains(query))
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Liste", selection: $destinationList) {
                    Label("Boxes", systemImage: "shippingbox.fill").tag(DestinationList.boxes)
                    Label("Items", systemImage: "square.grid.2x2.fill").tag(DestinationList.items)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                headerCard
                if destinations.isEmpty {
                    ContentUnavailableView("ImageMove.NoDestination", systemImage: "arrow.left.arrow.right")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section(destinationList == .boxes ? String(localized: "Zielkiste") : String(localized: "ImageMove.TargetItem")) {
                            ForEach(destinations) { destination in
                                Button {
                                    pendingTarget = destination
                                    showConfirmation = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "arrow.right")
                                            .foregroundStyle(.secondary)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(destination.name.isEmpty ? "👻" : destination.name)
                                                .font(.body.weight(.semibold))
                                            if !destination.detail.isEmpty {
                                                Text(destination.detail)
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .lineLimit(1)
                                        Spacer(minLength: 6)
                                        Image(systemName: "photo")
                                            .foregroundStyle(.secondary)
                                        Text("\(destination.imageCount)")
                                            .font(.callout.weight(.semibold))
                                    }
                                    .padding(.vertical, 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .onAppear {
                // Zielobjekte bei jedem Öffnen frisch laden, auch wenn SwiftUI den View-Zustand wiederverwendet.
                boxes = loadBoxes()
                items = loadItems()
                locations = loadLocations()
            }
            .navigationTitle("ImageMove.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Abbrechen")
                }
            }
            .alert("ImageMove.ConfirmTitle", isPresented: $showConfirmation, presenting: pendingTarget) { target in
                Button("Verschieben", role: .destructive) {
                    do { try onMoveConfirmed(target.id) }
                    catch { errorMessage = error.localizedDescription }
                }
                Button("Abbrechen", role: .cancel) { }
            } message: { target in
                Text(String.localizedStringWithFormat(String(localized: "ImageMove.ConfirmMessage"), selection.count, target.name))
            }
            .alert("ImageMove.ErrorTitle", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(UserDefaultsManager.loadAccentColor())
                Text(String.localizedStringWithFormat(String(localized: "%lld ausgewählt"), selection.count))
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            Text(selectedNamesText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("ImageMove.Search", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(UIColor.secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(12)
        .frame(maxWidth: 560, alignment: .leading)
        .background(.ultraThinMaterial)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }
}

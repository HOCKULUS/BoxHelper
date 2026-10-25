import SwiftUI

/// Die Mehrfachauswahl bleibt bis zur Bestätigung lokal; die aufrufende Ansicht speichert sie.
struct CreateLocationBoxesSheet: View {
    let boxes: [MovingBox]
    let locations: [Locations]
    let targetName: String
    let confirmationMessage: LocalizedStringKey
    let onConfirm: (Set<UUID>) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<UUID>
    @State private var searchText = ""

    init(boxes: [MovingBox], locations: [Locations], targetName: String,
         selection: Set<UUID>,
         confirmationMessage: LocalizedStringKey = "Die ausgewählten Kisten werden beim Speichern dem neuen Standort zugeordnet.",
         onConfirm: @escaping (Set<UUID>) -> Void) {
        self.boxes = boxes
        self.locations = locations
        self.targetName = targetName
        self.confirmationMessage = confirmationMessage
        self.onConfirm = onConfirm
        _selectedIDs = State(initialValue: selection.intersection(Set(boxes.map(\.id))))
    }

    private var filteredBoxes: [MovingBox] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return boxes.filter { box in
            query.isEmpty || box.name.localizedCaseInsensitiveContains(query)
                || location(for: box)?.name.localizedCaseInsensitiveContains(query) == true
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(UserDefaultsManager.loadAccentColor())
                        Text(String.localizedStringWithFormat(String(localized: "%lld ausgewählt"), selectedIDs.count))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    Text(targetName.isEmpty ? String(localized: "Neuer Standort") : targetName)
                        .font(.footnote).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Kisten suchen", text: $searchText)
                            .textInputAutocapitalization(.never).disableAutocorrection(true)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Color(UIColor.secondarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(12).frame(maxWidth: 560, alignment: .leading)
                .background(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16).padding(.top, 8)

                if filteredBoxes.isEmpty {
                    ContentUnavailableView("Keine Kisten gefunden", systemImage: "shippingbox")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(filteredBoxes) { box in
                                let color = stringToColor(location(for: box)?.color ?? box.color) ?? .gray
                                let textColor: Color = isColorTooDark(color: color) ? .white : .black
                                Button { toggle(box.id) } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: selectedIDs.contains(box.id) ? "checkmark.circle.fill" : "circle")
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(box.name.isEmpty ? "👻" : box.name).font(.body.weight(.semibold))
                                            Text(location(for: box)?.name ?? String(localized: "Ohne Standort"))
                                                .font(.footnote).foregroundStyle(textColor.opacity(0.68))
                                        }
                                        Spacer(minLength: 6)
                                        Image(systemName: "shippingbox.fill")
                                    }
                                    .foregroundStyle(textColor).padding(.vertical, 2)
                                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(selectedIDs.contains(box.id) ? [.isSelected] : [])
                                .listRowBackground(RoundedRectangle(cornerRadius: 12).fill(color))
                            }
                        } header: {
                            Button(allVisibleSelected ? "Auswahl aufheben" : "Alle auswählen") {
                                let visible = Set(filteredBoxes.map(\.id))
                                if allVisibleSelected { selectedIDs.subtract(visible) }
                                else { selectedIDs.formUnion(visible) }
                            }.buttonStyle(.plain)
                        } footer: {
                            Text(confirmationMessage)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Kisten auswählen").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Abbrechen")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Übernehmen") { onConfirm(selectedIDs) }
                }
            }
            .interactiveDismissDisabled(true)
        }
    }

    private var allVisibleSelected: Bool {
        !filteredBoxes.isEmpty && filteredBoxes.allSatisfy { selectedIDs.contains($0.id) }
    }

    private func location(for box: MovingBox) -> Locations? {
        locations.first { $0.id == box.location_uuid }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) }
        else { selectedIDs.insert(id) }
    }
}

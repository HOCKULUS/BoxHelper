//
//  MoveItemView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 06.01.25.
//

import SwiftUI

struct MoveItemView: View {
    @Binding var itemsToMove: Set<UUID>
    var onComplete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var boxes: [MovingBox] = loadBoxes()
    @State private var items: [Items] = loadItems()
    @State private var locations: [Locations] = loadLocations()
    @State private var searchText: String = ""
    @State private var selectedTargetBox: MovingBox?
    @State private var showMoveConfirmation = false

    private var selectedItemsList: [Items] {
        items.filter { itemsToMove.contains($0.id) }
    }

    private var selectedItemsTitle: String {
        let names = selectedItemsList
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if names.isEmpty {
            return String(localized: "Ausgewählte Gegenstände")
        }

        return names.joined(separator: ", ")
    }

    // Bündelt formatierte Lokalisierungen, damit die Schlüssel in der String-Katalogdatei landen.
    private var selectedItemsCountText: String {
        String.localizedStringWithFormat(
            String(localized: "%lld ausgewählt"),
            itemsToMove.count
        )
    }

    private var filteredBoxes: [MovingBox] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Aktuelle Quell-Kisten als Ziel ausblenden, um "Verschieben in dieselbe Kiste" zu vermeiden.
        let sourceBoxIDs = Set(selectedItemsList.map(\.box_uuid))
        return boxes
            .filter { !sourceBoxIDs.contains($0.id) }
            .filter { box in
                guard query.isEmpty == false else { return true }
                let boxName = box.name.lowercased()
                let locationName = locationName(for: box).lowercased()
                return boxName.contains(query) || locationName.contains(query)
            }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    var body: some View {
        VStack(spacing: 12) {
            if itemsToMove.isEmpty {
                ContentUnavailableView(
                    "Keine Gegenstände ausgewählt",
                    systemImage: "square.grid.2x2",
                    description: Text("Wähle zuerst mindestens einen Gegenstand aus.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                headerCard

                if filteredBoxes.isEmpty {
                    ContentUnavailableView(
                        "Keine Kiste gefunden",
                        systemImage: "shippingbox",
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section("Zielkiste") {
                            ForEach(filteredBoxes) { box in
                                Button {
                                    selectedTargetBox = box
                                    showMoveConfirmation = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "arrow.right")
                                            //.foregroundStyle(rowSecondaryTextColor(for: box))

                                        Text(box.name.isEmpty ? "👻" : box.name)
                                            .font(.body.weight(.semibold))
                                            .lineLimit(1)
                                            //.foregroundStyle(rowTextColor(for: box))

                                        Spacer(minLength: 6)

                                        if let location = locations.first(where: { $0.id == box.location_uuid }) {
                                            // Standortfarbe liegt als String vor und wird für Kontrast + Hintergrund in Color gewandelt.
                                            let locationColor = stringToColor(location.color) ?? .gray
                                            HStack {
                                                Text(location.name.isEmpty ? "👻" : location.name)
                                                    .font(.footnote)
                                                    .foregroundStyle(
                                                        isColorTooDark(color: locationColor)
                                                        ? Color.white.opacity(colorScheme == .dark ? 0.86 : 0.76)
                                                        : Color.black.opacity(colorScheme == .dark ? 0.80 : 0.68)
                                                    )
                                                    .lineLimit(1)
                                            }
                                            .background(locationColor)
                                            
                                        }

                                        Image(systemName: "square.grid.2x2.fill")
                                            //.foregroundStyle(rowSecondaryTextColor(for: box))

                                        Text("\(itemCount(for: box))")
                                            .font(.callout.weight(.semibold))
                                           // .foregroundStyle(rowSecondaryTextColor(for: box))
                                    }
                                    .padding(.vertical, 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    // Macht die komplette Zeile statt nur den Inhalt klickbar.
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                //.listRowBackground(
                                //    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                //        .fill(stringToColor(box.color) ?? Color.secondary)
                                //)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
        }
        .navigationTitle("Items verschieben")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName:"xmark")
                }
            }
        }
        .alert(
            "Items verschieben?",
            isPresented: $showMoveConfirmation,
            presenting: selectedTargetBox
        ) { targetBox in
            Button("Verschieben", role: .destructive) {
                moveSelectedItems(to: targetBox.id)
            }
            Button("Abbrechen", role: .cancel) { }
            } message: { targetBox in
            Text(
                String.localizedStringWithFormat(
                    String(localized: "%lld Gegenstände in „%@“ verschieben?"),
                    itemsToMove.count,
                    targetBox.name.isEmpty ? "👻" : targetBox.name
                )
            )
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(UserDefaultsManager.loadAccentColor())
                Text(selectedItemsCountText)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            Text(selectedItemsTitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Kiste suchen", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
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
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func locationName(for box: MovingBox) -> String {
        guard let locationID = box.location_uuid,
              let location = locations.first(where: { $0.id == locationID }) else {
            return ""
        }
        return location.name
    }

    private func itemCount(for box: MovingBox) -> Int {
        items.filter { $0.box_uuid == box.id }.count
    }

    private func rowTextColor(for box: MovingBox) -> Color {
        let baseColor = stringToColor(box.color) ?? .gray
        return isColorTooDark(color: baseColor) ? .white : .black
    }

    private func rowSecondaryTextColor(for box: MovingBox) -> Color {
        rowTextColor(for: box).opacity(colorScheme == .dark ? 0.78 : 0.68)
    }

    private func moveSelectedItems(to targetBoxID: UUID) {
        guard itemsToMove.isEmpty == false else { return }

        for index in items.indices where itemsToMove.contains(items[index].id) {
            items[index].box_uuid = targetBoxID
        }

        saveItems(items)
        itemsToMove.removeAll()
        onComplete?()
        dismiss()
    }
}

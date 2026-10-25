//
//  MoveBoxesSheetView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 22.02.26.
//

import SwiftUI

struct MoveBoxesSheetView: View {
    let selectedCount: Int
    let selectedNamesText: String
    let targetLocations: [Locations]
    let boxCount: (Locations) -> Int
    let onCancel: () -> Void
    let onMoveConfirmed: (UUID) -> Void

    @State private var searchText: String = ""
    @State private var pendingTargetLocation: Locations?
    @State private var showMoveConfirmation = false

    private var filteredTargetLocations: [Locations] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return targetLocations
            .filter { query.isEmpty ? true : $0.name.lowercased().contains(query) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // Verwaltet formatierte Lokalisierungen für die Auswahl- und Bestätigungsanzeige.
    private var selectedCountText: String {
        String.localizedStringWithFormat(
            String(localized: "%lld ausgewählt"),
            selectedCount
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(UserDefaultsManager.loadAccentColor())
                        Text(selectedCountText)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }

                    Text(selectedNamesText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Standort suchen", text: $searchText)
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

                if filteredTargetLocations.isEmpty {
                    ContentUnavailableView(
                        "Kein Standort gefunden",
                        systemImage: "location.slash",
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section("Zielstandort") {
                            ForEach(filteredTargetLocations, id: \.id) { targetLocation in
                                Button {
                                    pendingTargetLocation = targetLocation
                                    showMoveConfirmation = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "arrow.right")
                                            .foregroundStyle(targetRowSecondaryTextColor(for: targetLocation))

                                        Text(targetLocation.name.isEmpty ? "👻" : targetLocation.name)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(targetRowTextColor(for: targetLocation))

                                        Spacer(minLength: 6)

                                        Image(systemName: "shippingbox.fill")
                                            .foregroundStyle(targetRowSecondaryTextColor(for: targetLocation))

                                        Text("\(boxCount(targetLocation))")
                                            .font(.callout.weight(.semibold))
                                            .foregroundStyle(targetRowSecondaryTextColor(for: targetLocation))
                                    }
                                    .padding(.vertical, 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    // Wichtig: vollständige Zeile bleibt tappbar.
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(stringToColor(targetLocation.color) ?? Color.gray)
                                )
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Kisten verschieben")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName:"xmark")
                    }
                }
            }
            .alert(
                "Kisten verschieben?",
                isPresented: $showMoveConfirmation,
                presenting: pendingTargetLocation
            ) { targetLocation in
                Button("Verschieben", role: .destructive) {
                    onMoveConfirmed(targetLocation.id)
                }
                Button("Abbrechen", role: .cancel) { }
            } message: { targetLocation in
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "%lld Kisten nach „%@“ verschieben?"),
                        selectedCount,
                        targetLocation.name.isEmpty ? "👻" : targetLocation.name
                    )
                )
            }
            // Sheet nur über Abbrechen oder bestätigtes Verschieben schließen.
            .interactiveDismissDisabled(true)
        }
    }

    private func targetRowTextColor(for targetLocation: Locations) -> Color {
        let baseColor = stringToColor(targetLocation.color) ?? .gray
        return isColorTooDark(color: baseColor) ? .white : .black
    }

    private func targetRowSecondaryTextColor(for targetLocation: Locations) -> Color {
        targetRowTextColor(for: targetLocation).opacity(0.68)
    }
}

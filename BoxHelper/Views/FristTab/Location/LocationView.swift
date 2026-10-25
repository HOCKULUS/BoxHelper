//
//  LocationView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 09.01.25.
//

import SwiftUI
import UIKit
import StoreKit
import TipKit

/// Listeninhalt; Navigation und Tabpicker stellt der gemeinsame Listentab bereit.
struct LocationsView: View {
    @State private var boxes : [MovingBox] = loadBoxes()
    @State private var items : [Items] = loadItems()
    @State private var locations: [Locations] = []
    @State private var selectedLocations: [UUID] = []
    @Binding var searchText: String
    @Binding var isScrolling: Bool
    @StateObject private var transfer = InventoryTransferController()
    @State private var isEditing = false
    @State private var showAlert = false
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isSearchFieldFocused: Bool
    @State private var allSelected = false
    @State private var pressAndHold: Bool = UserDefaultsManager.shared.loadPressAndHold()
    @State private var selectedColorMode: LocationColorMode = .spectrum
    let addChangeLocationColors = changeLocationColors()

    enum LocationColorMode: String, CaseIterable, Identifiable {
        case spectrum
        case dynamic
        case golden
        case grayscale
        case vivid
        case random

        var id: String { rawValue }

        var title: String {
            switch self {
            case .spectrum: return "Spektrum"
            case .dynamic: return "Dynamisch"
            case .golden: return "Goldener Schnitt"
            case .grayscale: return "Graustufen"
            case .vivid: return "Lebendig"
            case .random: return "Zufall"
            }
        }

        var icon: String {
            switch self {
            case .spectrum: return "rainbow"
            case .dynamic: return "sparkles"
            case .golden: return "circle.hexagongrid.fill"
            case .grayscale: return "circle.lefthalf.filled"
            case .vivid: return "paintpalette.fill"
            case .random: return "shuffle"
            }
        }
    }
    enum SortCriterion: String, FirstTabSortCriterion {
        case name = "Name"
        case createdAt = "Created At"
        case updatedAt = "Updated At"

        var localized: String {
            return NSLocalizedString(self.rawValue, comment: "")
        }

        var iconName: String {
            switch self {
            case .name:
                return "textformat"
            case .createdAt:
                return "calendar"
            case .updatedAt:
                return "clock"
            }
        }
    }

    @Binding var selectedOption : String

    // Sortierkriterium und Richtung pro Liste optional auch über App-Neustarts hinweg merken.
    @RememberedListSorting("locationsListSortCriterion") private var sortCriterion: SortCriterion = .createdAt
    @RememberedListSorting("locationsListSortAscending") private var isAscending: Bool = true
    @State private var searchSuggestionsLocations: [String] = UserDefaults.standard.stringArray(forKey: "searchSuggestionsLocations") ?? []
    @State private var suggestions: Bool = UserDefaults.standard.object(forKey: "suggestions") == nil ? true : UserDefaults.standard.bool(forKey: "suggestions")
    @State private var pinnedSearchSuggestionsLocations: [String] = UserDefaults.standard.stringArray(forKey: "pinnedSearchSuggestionsLocations") ?? []
    @State private var spotlightLocationID: UUID?
    @State private var showSpotlightLocationDetail = false
    @AppStorage(FirstTabListLimit.alwaysLoadAllKey) private var alwaysLoadAllFirstTabLists: Bool = false
    @AppStorage(FirstTabListLimit.customLimitKey) private var customFirstTabListLimit: Int = 0
    @AppStorage(FirstTabListLimit.showLoadAllButtonKey) private var showLoadAllButton = true
    @State private var hasLoadedAllLocations = false

    @State private var numberofsearchSuggestions: Int = UserDefaults.standard.integer(forKey: "numberofsearchSuggestions") == 0 ? 5 : UserDefaults.standard.integer(forKey: "numberofsearchSuggestions")

    var filteredLocations: [Locations] {
        guard !searchText.isEmpty else { return locations }

        let lowercasedSearchText = searchText.lowercased()

        return locations.filter { location in
            // 1. Location-Name prüfen
            let nameMatch = location.name.lowercased().contains(lowercasedSearchText)

            // 2. Boxes prüfen, die zu dieser Location gehören
            let boxesMatch = boxes.contains { box in
                guard box.location_uuid == location.id else { return false }

                let boxNameMatch = box.name.lowercased().contains(lowercasedSearchText)
                let boxTagsMatch = box.tags?.contains { $0.lowercased().contains(lowercasedSearchText) } ?? false

                // 3. Items in der Box prüfen
                let itemsMatch = items.contains { item in
                    guard item.box_uuid == box.id else { return false }

                    let itemNameMatch = item.name.lowercased().contains(lowercasedSearchText)
                    let itemDescriptionMatch = item.description?.lowercased().contains(lowercasedSearchText) ?? false

                    let itemTagsMatch = item.tags?.contains { $0.lowercased().contains(lowercasedSearchText) } ?? false
                    return itemNameMatch || itemDescriptionMatch || itemTagsMatch
                }

                return boxNameMatch || boxTagsMatch || itemsMatch
            }

            return nameMatch || boxesMatch
        }
    }

    // Distinguish between "no data yet" and "search has no matches".
    private var hasActiveSearch: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sortedLocations: [Locations] {
        filteredLocations.sorted(by: { location1, location2 in
            switch sortCriterion {
            case .name:
                return isAscending ? location1.name < location2.name : location1.name > location2.name
            case .createdAt:
                return isAscending ? location1.createdAt < location2.createdAt : location1.createdAt > location2.createdAt
            case .updatedAt:
                return isAscending ? location1.updatedAt < location2.updatedAt : location1.updatedAt > location2.updatedAt
            }
        })
    }

    private var visibleLocations: [Locations] {
        guard showLoadAllButton, !alwaysLoadAllFirstTabLists, !hasLoadedAllLocations else { return sortedLocations }
        return Array(sortedLocations.prefix(FirstTabListLimit.limit(customLimit: customFirstTabListLimit)))
    }

    private var shouldShowLoadAllButton: Bool {
        showLoadAllButton && !alwaysLoadAllFirstTabLists && !hasLoadedAllLocations && visibleLocations.count < sortedLocations.count
    }

    private func shareSelection() {
        let selected = locations.filter { selectedLocations.contains($0.id) }
        transfer.export(InventoryTransferBuilder.locations(selected, allBoxes: boxes, allItems: items))
    }

    var body: some View {
        Group {
            ZStack {
                List {

                    ForEach(visibleLocations) { location in
                        Section {
                            ZStack {
                                if !isEditing {
                                    if pressAndHold {
                                        NavigationLink(
                                            destination: LocationDetailView(
                                                searchText: $searchText,
                                                selectedOption: $selectedOption,
                                                location: Binding(
                                                    get: { locations.first(where: { $0.id == location.id }) ?? location },
                                                    set: { newLocation in
                                                        if let updated = InventoryMutation.location(location.id, change: { $0 = newLocation }) {
                                                            locations = updated
                                                        }
                                                    }
                                                )
                                            )
                                        ) {
                                            HStack {
                                                ZStack {
                                                    HStack {
                                                        Text(location.name.isEmpty ? "👻" : location.name)
                                                            .font(.headline)
                                                            //.frame(maxHeight: 15)
                                                            .lineLimit(1)
                                                            .frame(maxWidth: .infinity, alignment: .leading)
                                                            .foregroundStyle(isColorTooDark(color: stringToColor(location.color) ?? Color.gray ) ? (boxes.filter({ $0.location_uuid == location.id }).count > 0) ? Color.white.opacity(1) : Color.white  : (boxes.filter({ $0.location_uuid == location.id }).count > 0) ? Color.black.opacity(1) : Color.black   )
                                                        Spacer()
                                                        // Boxenzähler mit Icon
                                                        HStack {
                                                            Image(systemName: "shippingbox.fill")
                                                                .foregroundStyle(
                                                                    isColorTooDark(color: stringToColor(location.color) ?? Color.gray )
                                                                    ? Color.white.opacity(0.4)
                                                                    : Color.black.opacity(0.4)
                                                                )
                                                                .scaleEffect(0.7)
                                                                .frame(height: 10)
                                                                .padding(.trailing, -6)

                                                            Text("\(boxes.filter { $0.location_uuid == location.id }.count)")
                                                                .font(.footnote)
                                                                .foregroundStyle(
                                                                    isColorTooDark(color: stringToColor(location.color) ?? Color.gray )
                                                                    ? Color.white.opacity(0.4)
                                                                    : Color.black.opacity(0.4)
                                                                )
                                                            Spacer()
                                                        }
                                                        .padding(.horizontal, 5)
                                                        .frame(width: 70,height: 10)
                                                    }
                                                    .padding(.leading, 10)
                                                }

                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .foregroundStyle(.white, isColorTooDark(color: stringToColor(location.color) ?? Color.gray ) ? Color.white.opacity(1) : Color.black.opacity(1))
                                        .opacity(1)
                                        .padding(.horizontal, -15)
                                        .contentShape(Rectangle())
                                        .simultaneousGesture(
                                            LongPressGesture().onEnded { _ in
                                                withAnimation { isEditing = true }
                                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                                generator.impactOccurred()
                                            }
                                        )
                                    }
                                    else { //iOS 17
                                        NavigationLink(
                                            destination: LocationDetailView(
                                                searchText: $searchText,
                                                selectedOption: $selectedOption,
                                                location: Binding(
                                                    get: { locations.first(where: { $0.id == location.id }) ?? location },
                                                    set: { newLocation in
                                                        if let updated = InventoryMutation.location(location.id, change: { $0 = newLocation }) {
                                                            locations = updated
                                                        }
                                                    }
                                                )
                                            )
                                        ) {
                                            HStack {
                                                ZStack {
                                                    HStack {
                                                        Text(location.name.isEmpty ? "👻" : location.name)
                                                            .font(.headline)
                                                            //.frame(maxHeight: 15)
                                                            .lineLimit(1)
                                                            .frame(maxWidth: .infinity, alignment: .leading)
                                                            .foregroundStyle(isColorTooDark(color: stringToColor(location.color) ?? Color.gray ) ? (boxes.filter({ $0.location_uuid == location.id }).count > 0) ? Color.white.opacity(1) : Color.white  : (boxes.filter({ $0.location_uuid == location.id }).count > 0) ? Color.black.opacity(1) : Color.black   )
                                                        Spacer()
                                                        // Boxenzähler mit Icon
                                                        HStack {
                                                            Image(systemName: "shippingbox.fill")
                                                                .foregroundStyle(
                                                                    isColorTooDark(color: stringToColor(location.color) ?? Color.gray )
                                                                    ? Color.white.opacity(0.4)
                                                                    : Color.black.opacity(0.4)
                                                                )
                                                                .scaleEffect(0.7)
                                                                .frame(height: 10)
                                                                .padding(.trailing, -6)

                                                            Text("\(boxes.filter { $0.location_uuid == location.id }.count)")
                                                                .font(.footnote)
                                                                .foregroundStyle(
                                                                    isColorTooDark(color: stringToColor(location.color) ?? Color.gray )
                                                                    ? Color.white.opacity(0.4)
                                                                    : Color.black.opacity(0.4)
                                                                )
                                                            Spacer()
                                                        }
                                                        .padding(.horizontal, 5)
                                                        .frame(width: 70,height: 10)
                                                    }
                                                    .padding(.leading, 10)
                                                }

                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .foregroundStyle(.white, isColorTooDark(color: stringToColor(location.color) ?? Color.gray ) ? Color.white.opacity(1) : Color.black.opacity(1))
                                        .opacity(1)
                                        .padding(.horizontal, -15)
                                        .contentShape(Rectangle())
                                    }
                                }
                                else{
                                    HStack {
                                        if boxes.filter({ $0.location_uuid == location.id }).count > 0 {
                                            Image(systemName: "xmark.circle.fill")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 20, height: 20)
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(Color.white, Color.gray)
                                        }
                                        else{
                                            Image(systemName: selectedLocations.contains(location.id) ? "checkmark.circle.fill" : "circle")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 20, height: 20)
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(!selectedLocations.contains(location.id) ? Color(UIColor.darkGray) : Color.white, selectedLocations.contains(location.id) ? selectedColor : Color(UIColor.darkGray))
                                                .onTapGesture {
                                                    if selectedLocations.contains(location.id) {
                                                        // Entferne box.id aus dem Array
                                                        selectedLocations.removeAll { $0 == location.id }
                                                    } else {
                                                        // Füge box.id zum Array hinzu
                                                        selectedLocations.append(location.id)
                                                    }
                                                    hideKeyboard()
                                                }
                                        }
                                        ZStack {
                                            HStack {
                                                Text(location.name.isEmpty ? "👻" : location.name)
                                                    .font(.headline)
                                                    //.frame(maxHeight: 15)
                                                    .lineLimit(1)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .foregroundStyle(isColorTooDark(color: stringToColor(location.color) ?? Color.gray ) ? (boxes.filter({ $0.location_uuid == location.id }).count > 0) ? Color.white.opacity(0.3) : Color.white  : (boxes.filter({ $0.location_uuid == location.id }).count > 0) ? Color.black.opacity(0.3) : Color.black   )
                                                Spacer()
                                                // Boxenzähler mit Icon
                                                HStack {
                                                    Image(systemName: "shippingbox.fill")
                                                        .foregroundStyle(
                                                            isColorTooDark(color: stringToColor(location.color) ?? Color.gray )
                                                            ? Color.white.opacity(0.4)
                                                            : Color.black.opacity(0.4)
                                                        )
                                                        .scaleEffect(0.7)
                                                        .frame(height: 10)
                                                        .padding(.trailing, -6)

                                                    Text("\(boxes.filter { $0.location_uuid == location.id }.count)")
                                                        .font(.footnote)
                                                        .foregroundStyle(
                                                            isColorTooDark(color: stringToColor(location.color) ?? Color.gray )
                                                            ? Color.white.opacity(0.4)
                                                            : Color.black.opacity(0.4)
                                                        )
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 5)
                                                .frame(width: 70,height: 10)
                                            }
                                            .padding(.leading, 10)
                                        }

                                        .padding(-10)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if (boxes.filter({ $0.location_uuid == location.id }).count == 0) && isEditing {
                                            if selectedLocations.contains(location.id) {
                                                // Entferne box.id aus dem Array
                                                selectedLocations.removeAll { $0 == location.id }
                                            } else {
                                                // Füge box.id zum Array hinzu
                                                selectedLocations.append(location.id)
                                            }
                                        }
                                        hideKeyboard()
                                    }
                                    .padding(-10)
                                }
                            }
                        }


                        .listRowBackground(stringToColor(location.color))
                    }
                    if shouldShowLoadAllButton {
                        Button {
                            hasLoadedAllLocations = true
                        } label: {
                            Label("FirstTab.LoadAll", systemImage: "tray.and.arrow.down")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    HStack {
                        Spacer()
                        Text(filteredLocations.isEmpty ? "" : "Locations: \(locations.count)")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .background(Color.clear)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.bottom, 25)
                    .padding(.horizontal, 0)
                    .multilineTextAlignment(.center)
                    .listRowBackground(Color.clear)
                }
                .overlay {
                    if filteredLocations.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
                    }
                }
                .contentMargins(.top, 0, for: .scrollContent)
                /*
                .if(UIDevice.current.userInterfaceIdiom == .pad) { view in
                    view.searchable(text: $searchText, placement: .navigationBarDrawer)
                }
                 */
                //.padding(.top, -33)
                .listSectionSpacing(8)
                .scrollDismissesKeyboard(.immediately)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(isEditing ? .hidden : .visible, for: .tabBar)
                .preference(key: FirstTabSelectionActiveKey.self, value: isEditing)
                .modifier(FirstTabSelectionMode(isEditing: $isEditing))
                .modifier(FirstTabSelectionBarBackground(isEditing: isEditing))
                .modifier(InventoryTransferPresentation(controller: transfer, selectedOption: $selectedOption))
                .onReceive(NotificationCenter.default.publisher(for: .inventoryDidChange)) { _ in
                    // Änderungen aus Formularen und Kurzbefehlen sofort übernehmen.
                    let inventory = InventoryStorageState.shared.readSnapshot()
                    if boxes != inventory.boxes { boxes = inventory.boxes }
                    if items != inventory.items { items = inventory.items }
                    if locations != inventory.locations { locations = inventory.locations }
                    selectedLocations.removeAll { id in !locations.contains(where: { $0.id == id }) }
                    allSelected = !filteredLocations.isEmpty && filteredLocations.allSatisfy { selectedLocations.contains($0.id) }
                }
                .onReceive(NotificationCenter.default.publisher(for: .inventoryTransferCompleted)) { _ in
                    let inventory = InventoryStorageState.shared.readSnapshot()
                    if boxes != inventory.boxes { boxes = inventory.boxes }
                    if items != inventory.items { items = inventory.items }
                    if locations != inventory.locations { locations = inventory.locations }
                    selectedLocations.removeAll()
                    isEditing = false
                }
                .toolbar {
                    //if UIDevice.current.userInterfaceIdiom != .pad {
                        ToolbarItem(placement: .principal) {
                            SearchBar(text: $searchText)
                                .frame(width: 200)
                                //.frame(maxWidth: .infinity)
                        }
                    //}
                    FirstTabToolbar(isEditing: $isEditing, transfer: transfer,
                        count: selectedLocations.count, total: filteredLocations.count,
                        selectedColor: selectedColor,
                        canMove: false,
                        share: shareSelection,
                        delete: { showAlert = true },
                        selectAll: { selectAll() },
                        finish: { selectedLocations.removeAll(); allSelected = false }) {

                            FirstTabSortOptions(criterion: $sortCriterion, ascending: $isAscending, list: $selectedOption)
                            Section("Color") {
                                ForEach(LocationColorMode.allCases) { mode in
                                    Button {
                                        selectedColorMode = mode
                                        applyLocationColors(mode)
                                    } label: {
                                        Label(mode.title, systemImage: selectedColorMode == mode ? "checkmark.circle.fill" : mode.icon)
                                    }
                                }
                            }
                    }
                }
                .onAppear {
                    pinnedSearchSuggestionsLocations = UserDefaults.standard.stringArray(forKey: "pinnedSearchSuggestionsLocations") ?? []
                    numberofsearchSuggestions = UserDefaults.standard.integer(forKey: "numberofsearchSuggestions") == 0 ? 5 : UserDefaults.standard.integer(forKey: "numberofsearchSuggestions")
                   suggestions = UserDefaults.standard.object(forKey: "suggestions") == nil ? true : UserDefaults.standard.bool(forKey: "suggestions")
                    searchSuggestionsLocations = UserDefaults.standard.stringArray(forKey: "searchSuggestionsLocations") ?? []
                    UserDefaultsManager.shared.saveLastState("boxes")
                    pressAndHold = UserDefaultsManager.shared.loadPressAndHold()


                    selectedColor = UserDefaultsManager.loadAccentColor()
                    locations = loadLocations()
                    boxes = loadBoxes()
                    items = loadItems()
                }
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text(String(format: NSLocalizedString("Delete %d locations?", comment: ""), selectedLocations.count)),
                        message: Text(NSLocalizedString("Are you sure you want to delete the selected locations?", comment: "")),
                        primaryButton: .destructive(Text(NSLocalizedString("Delete", comment: ""))) {
                            removeSelectedLocations()
                            isEditing = false
                        },
                        secondaryButton: .cancel()
                    )
                }
                if locations.count >= 3 {
                    //TipView(addChangeLocationColors)
                }
            }
            // Spotlight verwendet dieselbe Navigation wie die sichtbaren Standort-Links.
            .navigationDestination(isPresented: $showSpotlightLocationDetail) {
                spotlightLocationDestination()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSpotlightLocation)) { notification in
                guard let locationID = notification.object as? UUID else { return }
                locations = loadLocations()
                boxes = loadBoxes()
                items = loadItems()
                guard locations.contains(where: { $0.id == locationID }) else { return }
                spotlightLocationID = locationID
                showSpotlightLocationDetail = true
            }

        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !isEditing  && suggestions{
                        if #available(iOS 26.0, *) {
                            //GeometryReader { geo in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {


                                        // Gruppieren und nach Häufigkeit sortieren
                                        let groupedPinnedSuggestions = Dictionary(grouping: pinnedSearchSuggestionsLocations, by: { $0.lowercased() })
                                            .map { (key, values) in (suggestion: key, count: values.count) }
                                            .sorted {
                                                if $0.count == $1.count {
                                                    return $0.suggestion.localizedCompare($1.suggestion) == .orderedAscending
                                                } else {
                                                    return $0.count > $1.count
                                                }
                                            }
                                        let filteredPinnedSuggestions = groupedPinnedSuggestions
                                            .filter { item in
                                                item.suggestion.lowercased() != searchText.lowercased()
                                                && (item.suggestion.lowercased().contains(searchText.lowercased()) || searchText.isEmpty)
                                            }

                                        // Gruppieren und nach Häufigkeit sortieren
                                        let groupedSuggestions = Dictionary(grouping: searchSuggestionsLocations, by: { $0.lowercased() })
                                            .map { (key, values) in (suggestion: key, count: values.count) }
                                            .sorted {
                                                if $0.count == $1.count {
                                                    return $0.suggestion.localizedCompare($1.suggestion) == .orderedAscending
                                                } else {
                                                    return $0.count > $1.count
                                                }
                                            }
                                        let filteredSuggestions = groupedSuggestions
                                            .filter { item in
                                                item.suggestion.lowercased() != searchText.lowercased()
                                                && (item.suggestion.lowercased().contains(searchText.lowercased()) || searchText.isEmpty)
                                            }
                                            .prefix(max(0, numberofsearchSuggestions - filteredPinnedSuggestions.count))

                                        if !searchText.isEmpty{
                                            Button(action: {
                                                searchText = ""
                                            }) {
                                                HStack {
                                                    Image(systemName: "xmark")
                                                        .foregroundStyle(.white)
                                                    Text("Close")
                                                        .foregroundStyle(.white)
                                                        .padding(.trailing, 4)
                                                }
                                                .padding(5)
                                            }
                                            .glassEffect(.clear.tint(.red))
                                            .background(.ultraThinMaterial.opacity(0.9))
                                            .cornerRadius(20)
                                        }

                                        ForEach(filteredPinnedSuggestions, id: \.suggestion) { item in
                                            Button(action: {
                                                searchText = item.suggestion
                                            }) {
                                                HStack {
                                                    HStack {
                                                        Image(systemName: "star")
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                        Text(item.suggestion)
                                                            .padding(.trailing, 5)
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                    }
                                                    .padding(5)
                                                    /*
                                                    Text("(\(item.count))")
                                                        .foregroundColor(.secondary)
                                                     */
                                                }
                                                .glassEffect(.clear)
                                                .background(.ultraThinMaterial.opacity(0.8))
                                                .cornerRadius(20)

                                            }
                                            .padding(.vertical, 2)
                                            .contextMenu {
                                                Button(action: {
                                                    searchSuggestionsLocations.append(item.suggestion)
                                                    pinnedSearchSuggestionsLocations.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                                    UserDefaults.standard.set(searchSuggestionsLocations, forKey: "searchSuggestionsLocations")
                                                    UserDefaults.standard.set(pinnedSearchSuggestionsLocations, forKey: "pinnedSearchSuggestionsLocations")
                                                    print("UNPIN \(item.suggestion)")
                                                }) {
                                                    Label("unfavorite", systemImage: "star.slash")
                                                }
                                                Button(role: .destructive, action: {
                                                    pinnedSearchSuggestionsLocations.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                                    UserDefaults.standard.set(pinnedSearchSuggestionsLocations, forKey: "pinnedSearchSuggestionsLocations")
                                                    print("DELETE \(item.suggestion)")
                                                }) {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                                .tint(.red)
                                            }
                                        }

                                        ForEach(filteredSuggestions, id: \.suggestion) { item in
                                            Button(action: {
                                                searchText = item.suggestion
                                            }) {
                                                HStack {
                                                    HStack {
                                                        Image(systemName: "clock")
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                        Text(item.suggestion)
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                            .padding(.trailing, 4)
                                                        /*
                                                         Text("(\(item.count))")
                                                         .foregroundColor(.secondary)
                                                         */
                                                    }
                                                    .padding(5)
                                                }
                                                .glassEffect(.clear)
                                                .background(.ultraThinMaterial.opacity(0.8))
                                                .cornerRadius(20)
                                            }
                                            .padding(.vertical, 2)
                                            .contextMenu {
                                                Button(action: {
                                                    pinnedSearchSuggestionsLocations.append(item.suggestion)
                                                    searchSuggestionsLocations.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                                    UserDefaults.standard.set(searchSuggestionsLocations, forKey: "searchSuggestionsLocations")
                                                    UserDefaults.standard.set(pinnedSearchSuggestionsLocations, forKey: "pinnedSearchSuggestionsLocations")
                                                    print("PIN \(item.suggestion)")
                                                }) {
                                                    Label("favorite", systemImage: "star")
                                                }

                                                Button(role: .destructive, action: {
                                                    searchSuggestionsLocations.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                                    UserDefaults.standard.set(searchSuggestionsLocations, forKey: "searchSuggestionsLocations")
                                                    print("DELETE \(item.suggestion)")
                                                }) {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                                .tint(.red)
                                            }
                                        }

                                        if(!searchText.isEmpty){
                                            let allData = locations.map { $0.name }
                                                + boxes.map { $0.name }
                                                + boxes.flatMap { $0.tags ?? [] }
                                                + items.map { $0.name }

                                            // Nur Werte, die nicht bereits in pinnedSearchSuggestions oder searchSuggestions sind
                                            let filteredAllData = allData.filter { value in
                                                !pinnedSearchSuggestionsLocations.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) &&
                                                !searchSuggestionsLocations.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame })
                                            }

                                            // Gruppieren
                                            let groupedResults = Dictionary(grouping: filteredAllData, by: { $0.lowercased() })
                                                .map { (key, values) in (suggestion: key, count: values.count) }
                                                .sorted {
                                                    if $0.count == $1.count {
                                                        return $0.suggestion.localizedCompare($1.suggestion) == .orderedAscending
                                                    } else {
                                                        return $0.count > $1.count
                                                    }
                                                }

                                            // Filtern nach Suchtext (max. 5 Ergebnisse)
                                            let filteredResults = groupedResults
                                                .filter { item in
                                                    item.suggestion.lowercased() != searchText.lowercased()
                                                    && (item.suggestion.lowercased().contains(searchText.lowercased()) || searchText.isEmpty)
                                                }
                                                .prefix(max(0, numberofsearchSuggestions - (filteredPinnedSuggestions.count + filteredSuggestions.count)))
                                            ForEach(filteredResults, id: \.suggestion) { item in
                                                Button(action: {
                                                    searchText = item.suggestion
                                                }) {
                                                    HStack {
                                                        HStack {
                                                            Image(systemName: "magnifyingglass")
                                                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                                            Text(item.suggestion)
                                                                .padding(.trailing, 5)
                                                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                                        }
                                                        .padding(5)
                                                        /*
                                                         Text("(\(item.count))")
                                                         .foregroundColor(.secondary)
                                                         */
                                                    }
                                                    .glassEffect(.clear)
                                                    .background(.ultraThinMaterial.opacity(0.8))
                                                    .cornerRadius(20)

                                                }
                                                .padding(.vertical, 2)
                                                .contextMenu {
                                                    Button(action: {
                                                        pinnedSearchSuggestionsLocations.append(item.suggestion)
                                                        searchSuggestionsLocations.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                                        UserDefaults.standard.set(searchSuggestionsLocations, forKey: "searchSuggestionsLocations")
                                                        UserDefaults.standard.set(pinnedSearchSuggestionsLocations, forKey: "pinnedSearchSuggestionsLocations")
                                                        print("PIN \(item.suggestion)")
                                                    }) {
                                                        Label("favorite", systemImage: "star")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    //.frame(width: max(geo.size.width, CGFloat(searchSuggestions.count) * 100), alignment: .center)
                                }
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { _ in
                                            if !isScrolling {
                                                print("Scroll started")
                                                isScrolling = true
                                            }
                                        }
                                        .onEnded { _ in
                                            print("Scroll ended")
                                            isScrolling = false
                                        }
                                )
                                .defaultScrollAnchor(.center, for: .alignment)
                                .scrollBounceBehavior(.basedOnSize)
                                .frame(height: 60)
                            //}
                            //.frame(height: 60) // Höhe anpassen
                        }
                        else {
                            //GeometryReader { geo in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {


                                        // Gruppieren und nach Häufigkeit sortieren
                                        let groupedPinnedSuggestions = Dictionary(grouping: pinnedSearchSuggestionsLocations, by: { $0.lowercased() })
                                            .map { (key, values) in (suggestion: key, count: values.count) }
                                            .sorted {
                                                if $0.count == $1.count {
                                                    return $0.suggestion.localizedCompare($1.suggestion) == .orderedAscending
                                                } else {
                                                    return $0.count > $1.count
                                                }
                                            }
                                        let filteredPinnedSuggestions = groupedPinnedSuggestions
                                            .filter { item in
                                                item.suggestion.lowercased() != searchText.lowercased()
                                                && (item.suggestion.lowercased().contains(searchText.lowercased()) || searchText.isEmpty)
                                            }

                                        // Gruppieren und nach Häufigkeit sortieren
                                        let groupedSuggestions = Dictionary(grouping: searchSuggestionsLocations, by: { $0.lowercased() })
                                            .map { (key, values) in (suggestion: key, count: values.count) }
                                            .sorted {
                                                if $0.count == $1.count {
                                                    return $0.suggestion.localizedCompare($1.suggestion) == .orderedAscending
                                                } else {
                                                    return $0.count > $1.count
                                                }
                                            }
                                        let filteredSuggestions = groupedSuggestions
                                            .filter { item in
                                                item.suggestion.lowercased() != searchText.lowercased()
                                                && (item.suggestion.lowercased().contains(searchText.lowercased()) || searchText.isEmpty)
                                            }
                                            .prefix(max(0, numberofsearchSuggestions - filteredPinnedSuggestions.count))

                                        if !searchText.isEmpty{
                                            Button(action: {
                                                searchText = ""
                                            }) {
                                                HStack {
                                                    Image(systemName: "xmark")
                                                        .foregroundStyle(.white)
                                                    Text("Close")
                                                        .foregroundStyle(.white)
                                                        .padding(.trailing, 4)
                                                }
                                                .padding(5)
                                            }
                                            //.glassEffect(.clear.tint(.red))
                                            .background(.red)
                                            .background(.thinMaterial)
                                            .cornerRadius(20)
                                        }

                                        ForEach(filteredPinnedSuggestions, id: \.suggestion) { item in
                                            Button(action: {
                                                searchText = item.suggestion
                                            }) {
                                                HStack {
                                                    HStack {
                                                        Image(systemName: "star")
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                        Text(item.suggestion)
                                                            .padding(.trailing, 5)
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                    }
                                                    .padding(5)
                                                    /*
                                                    Text("(\(item.count))")
                                                        .foregroundColor(.secondary)
                                                     */
                                                }
                                                //.glassEffect(.clear)
                                                .background(.thinMaterial)
                                                .cornerRadius(20)

                                            }
                                            .padding(.vertical, 2)
                                            .contextMenu {
                                                Button(action: {
                                                    searchSuggestionsLocations.append(item.suggestion)
                                                    pinnedSearchSuggestionsLocations.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                                    UserDefaults.standard.set(searchSuggestionsLocations, forKey: "searchSuggestionsLocations")
                                                    UserDefaults.standard.set(pinnedSearchSuggestionsLocations, forKey: "pinnedSearchSuggestionsLocations")
                                                    print("UNPIN \(item.suggestion)")
                                                }) {
                                                    Label("unfavorite", systemImage: "star.slash")
                                                }
                                                Button(role: .destructive, action: {
                                                    pinnedSearchSuggestionsLocations.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                                    UserDefaults.standard.set(pinnedSearchSuggestionsLocations, forKey: "pinnedSearchSuggestionsLocations")
                                                    print("DELETE \(item.suggestion)")
                                                }) {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                                .tint(.red)
                                            }
                                        }

                                        ForEach(filteredSuggestions, id: \.suggestion) { item in
                                            Button(action: {
                                                searchText = item.suggestion
                                            }) {
                                                HStack {
                                                    HStack {
                                                        Image(systemName: "clock")
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                        Text(item.suggestion)
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                            .padding(.trailing, 4)
                                                        /*
                                                         Text("(\(item.count))")
                                                         .foregroundColor(.secondary)
                                                         */
                                                    }
                                                    .padding(5)
                                                }
                                                //.glassEffect(.clear)
                                                .background(.thinMaterial)
                                                .cornerRadius(20)
                                            }
                                            .padding(.vertical, 2)
                                            .contextMenu {
                                                Button(action: {
                                                    pinnedSearchSuggestionsLocations.append(item.suggestion)
                                                    searchSuggestionsLocations.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                                    UserDefaults.standard.set(searchSuggestionsLocations, forKey: "searchSuggestionsLocations")
                                                    UserDefaults.standard.set(pinnedSearchSuggestionsLocations, forKey: "pinnedSearchSuggestionsLocations")
                                                    print("PIN \(item.suggestion)")
                                                }) {
                                                    Label("favorite", systemImage: "star")
                                                }

                                                Button(role: .destructive, action: {
                                                    searchSuggestionsLocations.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                                    UserDefaults.standard.set(searchSuggestionsLocations, forKey: "searchSuggestionsLocations")
                                                    print("DELETE \(item.suggestion)")
                                                }) {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                                .tint(.red)
                                            }
                                        }

                                        if(!searchText.isEmpty){
                                            let allData = locations.map { $0.name }
                                                + boxes.map { $0.name }
                                                + boxes.flatMap { $0.tags ?? [] }
                                                + items.map { $0.name }

                                            // Nur Werte, die nicht bereits in pinnedSearchSuggestions oder searchSuggestions sind
                                            let filteredAllData = allData.filter { value in
                                                !pinnedSearchSuggestionsLocations.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) &&
                                                !searchSuggestionsLocations.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame })
                                            }

                                            // Gruppieren
                                            let groupedResults = Dictionary(grouping: filteredAllData, by: { $0.lowercased() })
                                                .map { (key, values) in (suggestion: key, count: values.count) }
                                                .sorted {
                                                    if $0.count == $1.count {
                                                        return $0.suggestion.localizedCompare($1.suggestion) == .orderedAscending
                                                    } else {
                                                        return $0.count > $1.count
                                                    }
                                                }

                                            // Filtern nach Suchtext (max. 5 Ergebnisse)
                                            let filteredResults = groupedResults
                                                .filter { item in
                                                    item.suggestion.lowercased() != searchText.lowercased()
                                                    && (item.suggestion.lowercased().contains(searchText.lowercased()) || searchText.isEmpty)
                                                }
                                                .prefix(max(0, numberofsearchSuggestions - (filteredPinnedSuggestions.count + filteredSuggestions.count)))
                                            ForEach(filteredResults, id: \.suggestion) { item in
                                                Button(action: {
                                                    searchText = item.suggestion
                                                }) {
                                                    HStack {
                                                        HStack {
                                                            Image(systemName: "magnifyingglass")
                                                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                                            Text(item.suggestion)
                                                                .padding(.trailing, 5)
                                                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                                        }
                                                        .padding(5)
                                                        /*
                                                         Text("(\(item.count))")
                                                         .foregroundColor(.secondary)
                                                         */
                                                    }
                                                    //.glassEffect(.clear)
                                                    .background(.thinMaterial)
                                                    .cornerRadius(20)

                                                }
                                                .padding(.vertical, 2)
                                                .contextMenu {
                                                    Button(action: {
                                                        pinnedSearchSuggestionsLocations.append(item.suggestion)
                                                        searchSuggestionsLocations.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                                        UserDefaults.standard.set(searchSuggestionsLocations, forKey: "searchSuggestionsLocations")
                                                        UserDefaults.standard.set(pinnedSearchSuggestionsLocations, forKey: "pinnedSearchSuggestionsLocations")
                                                        print("PIN \(item.suggestion)")
                                                    }) {
                                                        Label("favorite", systemImage: "star")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    //.frame(width: max(geo.size.width, CGFloat(searchSuggestions.count) * 100), alignment: .center)
                                }
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { _ in
                                            if !isScrolling {
                                                print("Scroll started")
                                                isScrolling = true
                                            }
                                        }
                                        .onEnded { _ in
                                            print("Scroll ended")
                                            isScrolling = false
                                        }
                                )
                                .defaultScrollAnchor(.center, for: .alignment)
                                .scrollBounceBehavior(.basedOnSize)
                                .frame(height: 60)
                            //}
                            //.frame(height: 60) // Höhe anpassen
                        }
                    }
                }

    }
    private func applyLocationColors(_ mode: LocationColorMode) {
        do {
            let baseline = try InventoryPersistence.loadLocations()
            var updatedLocations = baseline
            switch mode {
            case .spectrum: updatedLocations = assignColorsToLocations(updatedLocations)
            case .dynamic: updatedLocations = assignColorsToLocations2(updatedLocations)
            case .golden: updatedLocations = assignColorsToLocations3(updatedLocations)
            case .grayscale: updatedLocations = assignColorsToLocations4(updatedLocations)
            case .vivid: updatedLocations = assignColorsToLocations5(updatedLocations)
            case .random: updatedLocations = assignColorsToLocationsRandom(updatedLocations)
            }
            try InventoryPersistence.applyLocationChanges(from: baseline, to: updatedLocations)
            locations = updatedLocations
            addChangeLocationColors.invalidate(reason: .actionPerformed)
        } catch { InventoryStorageState.shared.report(error) }
    }

    private func removeSelectedLocations() {
        let ids = Set(selectedLocations)
        Task { @MainActor in
            do {
                _ = try await InventoryDeletion.shared.locations(ids)
                locations = loadLocations()
                selectedLocations.removeAll { ids.contains($0) }
                allSelected = false
            } catch { InventoryStorageState.shared.report(error) }
        }
    }

    private func selectAll() {
        // Ermittle alle löschbaren Locations (also ohne zugewiesene Boxen)
        let deletable = filteredLocations.filter { location in
            !boxes.contains(where: { $0.location_uuid == location.id })
        }

        // Prüfe, ob alle löschbaren Locations bereits ausgewählt sind
        if deletable.allSatisfy({ selectedLocations.contains($0.id) }) {
            // Entferne sie, wenn alle schon ausgewählt waren
            selectedLocations.removeAll { id in
                deletable.contains(where: { $0.id == id })
            }
        } else {
            // Füge sie sonst hinzu, wenn sie noch fehlen
            for location in deletable {
                if !selectedLocations.contains(location.id) {
                    selectedLocations.append(location.id)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer(minLength: 0)
            HStack {
                Spacer(minLength: 0)
                VStack(spacing: 10) {
                    Image(systemName: hasActiveSearch ? "magnifyingglass" : "location")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(hasActiveSearch ? "Keine Suchergebnisse" : "Keine Standorte vorhanden")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func spotlightLocationDestination() -> some View {
        if let locationID = spotlightLocationID, let locationBinding = bindingForLocation(with: locationID) {
            LocationDetailView(
                searchText: $searchText,
                selectedOption: $selectedOption,
                location: locationBinding
            )
        } else {
            EmptyView()
        }
    }

    private func bindingForLocation(with locationID: UUID) -> Binding<Locations>? {
        guard let location = locations.first(where: { $0.id == locationID }) else { return nil }
        return Binding(
            get: { locations.first(where: { $0.id == locationID }) ?? location },
            set: { updatedLocation in
                guard let updated = InventoryMutation.location(locationID, change: { $0 = updatedLocation }) else { return }
                locations = updated
            }
        )
    }
}

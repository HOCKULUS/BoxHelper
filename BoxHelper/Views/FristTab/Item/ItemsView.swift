//
//  ItemsView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 09.01.25.
//

import SwiftUI

/// Listeninhalt; Navigation und Tabpicker stellt der gemeinsame Listentab bereit.
struct ItemsView: View {
    @State private var items: [Items] = []
    @State private var boxes: [MovingBox] = []
    @State private var locations: [Locations] = []
    @Binding var searchText: String
    @Binding var isScrolling: Bool
    @StateObject private var transfer = InventoryTransferController()
    @State private var isEditing = false
    @State private var selectedItems: [UUID] = []
    @State private var allSelected = false
    @State private var showAlert = false
    @State private var showMoveItemView = false
    @State private var itemsToMove: Set<UUID> = []
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @FocusState private var isSearchFieldFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var pressAndHold: Bool = UserDefaultsManager.shared.loadPressAndHold()
    @AppStorage("showImages") private var showImages: Bool = true
    @State private var selectedImageOrderOption = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
    @State private var size: Double = 76.0
    @State private var searchSuggestionsItems: [String] = UserDefaults.standard.stringArray(forKey: "searchSuggestionsItems") ?? []
    @State private var suggestions: Bool = UserDefaults.standard.object(forKey: "suggestions") == nil ? true : UserDefaults.standard.bool(forKey: "suggestions")
    @State private var spotlightItemID: UUID?
    @State private var showSpotlightItemDetail = false
    @AppStorage(FirstTabListLimit.alwaysLoadAllKey) private var alwaysLoadAllFirstTabLists: Bool = false
    @AppStorage(FirstTabListLimit.customLimitKey) private var customFirstTabListLimit: Int = 0
    @AppStorage(FirstTabListLimit.showLoadAllButtonKey) private var showLoadAllButton = true
    @State private var hasLoadedAllItems = false

    @State private var pinnedSearchSuggestionsItems: [String] = UserDefaults.standard.stringArray(forKey: "pinnedSearchSuggestionsItems") ?? []
    @State private var numberofsearchSuggestions: Int = UserDefaults.standard.integer(forKey: "numberofsearchSuggestions") == 0 ? 5 : UserDefaults.standard.integer(forKey: "numberofsearchSuggestions")

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
    @RememberedListSorting("itemsListSortCriterion") private var sortCriterion: SortCriterion = .createdAt
    @RememberedListSorting("itemsListSortAscending") private var isAscending: Bool = true

    var filteredItems: [Items] {
        guard !searchText.isEmpty else { return items }

        let lowercasedSearchText = searchText.lowercased()

        return items.filter { item in
            let nameMatch = item.name.lowercased().contains(lowercasedSearchText)

            let box = boxes.first(where: { $0.id == item.box_uuid }) // direkt verwenden

            let boxTagsMatch = box?.tags?.contains(where: { $0.lowercased().contains(lowercasedSearchText) }) ?? false
            let boxNameMatch = box?.name.lowercased().contains(lowercasedSearchText) ?? false
            let boxLocationMatch: Bool = {
                guard let locationUUID = box?.location_uuid,
                      let location = locations.first(where: { $0.id == locationUUID }) else { return false }
                return location.name.lowercased().contains(lowercasedSearchText)
            }()

            let itemTagsMatch = item.tags?.contains { $0.lowercased().contains(lowercasedSearchText) } ?? false
            return nameMatch || itemTagsMatch || boxTagsMatch || boxNameMatch || boxLocationMatch
        }
    }

    // Distinguish between "no data yet" and "search has no matches".
    private var hasActiveSearch: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sortedItems: [Items] {
        filteredItems.sorted(by: { item1, item2 in
            switch sortCriterion {
            case .name:
                return isAscending ? item1.name < item2.name : item1.name > item2.name
            case .createdAt:
                return isAscending ? item1.createdAt < item2.createdAt : item1.createdAt > item2.createdAt
            case .updatedAt:
                return isAscending ? item1.updatedAt < item2.updatedAt : item1.updatedAt > item2.updatedAt
            }
        })
    }

    private var visibleItems: [Items] {
        guard showLoadAllButton, !alwaysLoadAllFirstTabLists, !hasLoadedAllItems else { return sortedItems }
        return Array(sortedItems.prefix(FirstTabListLimit.limit(customLimit: customFirstTabListLimit)))
    }

    private var shouldShowLoadAllButton: Bool {
        showLoadAllButton && !alwaysLoadAllFirstTabLists && !hasLoadedAllItems && visibleItems.count < sortedItems.count
    }

    private func shareSelection() {
        let selected = items.filter { selectedItems.contains($0.id) }
        transfer.export(InventoryTransferBuilder.items(selected, allBoxes: boxes, allLocations: locations))
    }

    var body: some View {
        Group {
            ZStack {
                List {

                    ForEach(visibleItems) { item in
                        Section {
                            ZStack {
                                if isEditing {
                                    ZStack {
                                        HStack {
                                            if showImages {
                                                ItemListThumbnail(
                                                    imagePath: selectedImageOrderOption == "new" ? item.images.last : item.images.first,
                                                    side: size)
                                            }
                                            /*
                                             HStack {
                                             Image(systemName: "photo")
                                             .resizable()
                                             .scaledToFit()
                                             .frame(width: 50, height: 50)
                                             .padding(10)
                                             .foregroundColor(.gray.opacity(0.2))
                                             .background(Color.secondary)
                                             .clipped()
                                             }
                                             .padding(-10)
                                             */
                                            VStack(alignment: .leading) {
                                                Text(item.name.isEmpty ? "👻" : item.name)
                                                    .lineLimit(1)
                                                    .font(.headline)
                                                if let box = boxes.first(where: { $0.id == item.box_uuid}),
                                                   let location = locations.first(where: { $0.id == box.location_uuid }) {
                                                    HStack {
                                                        HStack {
                                                            Text("\(box.name)")
                                                                .lineLimit(1)
                                                                .font(.footnote)
                                                                .foregroundStyle(Color(UIColor.secondarySystemBackground))
                                                        }
                                                        .foregroundColor(.white)
                                                        .padding(.vertical, 2)
                                                        .padding(.horizontal, 4)
                                                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4))
                                                        .cornerRadius(5)
                                                        .frame(height: 10)
                                                        HStack {
                                                            /*Image(systemName: "location")
                                                             .foregroundColor(.white)
                                                             .scaleEffect(0.7)
                                                             .frame(height: 10)
                                                             .padding(.trailing, -6)
                                                             */
                                                            Text(location.name.isEmpty ? "👻" : location.name)
                                                                .font(.footnote)
                                                                .foregroundStyle(isColorTooDark(color: stringToColor(location.color) ?? Color.clear ) ? Color.white.opacity(1) : Color.black.opacity(1))
                                                        }
                                                        .foregroundColor(.white)
                                                        .padding(.vertical, 2)
                                                        .padding(.horizontal, 4)
                                                        .background(stringToColor(location.color))
                                                        .cornerRadius(5)
                                                        .frame(height: 10)
                                                        Spacer()
                                                        if item.isFragile {
                                                            Image(systemName: "wineglass")
                                                                .foregroundStyle(selectedColor)
                                                                //.resizable()
                                                                .scaledToFit()
                                                                .frame(height: 10)
                                                        }
                                                        else {
                                                           /* Image(systemName: "wineglass")
                                                                .foregroundStyle(Color.secondary.opacity(0.3))
                                                                //.resizable()
                                                                .scaledToFit()
                                                                .frame(height: 10)*/
                                                        }

                                                        if item.isHeavy {
                                                            Image(systemName: "figure.strengthtraining.traditional")
                                                                .foregroundStyle(selectedColor)
                                                                //.resizable()
                                                                .scaledToFit()
                                                                .frame(height: 10)
                                                        }
                                                        else {
                                                            /*Image(systemName: "figure.strengthtraining.traditional")
                                                                .foregroundStyle(Color.secondary.opacity(0.3))
                                                                //.resizable()
                                                                .scaledToFit()
                                                                .frame(height: 10)*/
                                                        }
                                                    }
                                                }
                                                else {
                                                    HStack {
                                                        HStack {
                                                            Text("               ")
                                                                .lineLimit(1)
                                                                .font(.footnote)
                                                        }
                                                        .padding(.vertical, 2)
                                                        .padding(.horizontal, 4)
                                                        .background(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                                                        .cornerRadius(5)
                                                        .frame(height: 10)
                                                        HStack {
                                                            /*Image(systemName: "location")
                                                             .foregroundColor(.white)
                                                             .scaleEffect(0.7)
                                                             .frame(height: 10)
                                                             .padding(.trailing, -6)
                                                             */
                                                            Text("                              ")
                                                                .font(.footnote)
                                                        }
                                                        .foregroundColor(.white)
                                                        .padding(.vertical, 2)
                                                        .padding(.horizontal, 4)
                                                        .background(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                                                        .cornerRadius(5)
                                                        .frame(height: 10)
                                                        Spacer()
                                                    }
                                                }
                                            }
                                            .padding(.leading, 5)
                                            .padding(.bottom, 10)
                                        }
                                        .padding(.vertical, -15)
                                        HStack {
                                            Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 20, height: 20)
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(!selectedItems.contains(item.id) ? Color(UIColor.darkGray) : Color.white, selectedItems.contains(item.id) ? selectedColor : Color(UIColor.darkGray))
                                            Spacer()

                                        }
                                        .padding(.leading, 11)
                                    }
                                    .padding(.leading, -21)
                                    .contentShape(Rectangle())
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if selectedItems.contains(item.id) {
                                            selectedItems.removeAll { $0 == item.id }
                                        } else {
                                            selectedItems.append(item.id)
                                        }
                                        hideKeyboard()
                                    }
                                } else if pressAndHold {
                                    NavigationLink(
                                        destination: ItemsDetailView(searchText: $searchText, item: Binding(
                                            get: { items.first(where: { $0.id == item.id }) ?? item },
                                            set: { newItem in
                                                if let updated = InventoryMutation.item(item.id, change: { $0 = newItem }) {
                                                    items = updated
                                                }
                                            }
                                        ))
                                    ) {
                                        HStack {
                                            if showImages {
                                                ItemListThumbnail(
                                                    imagePath: selectedImageOrderOption == "new" ? item.images.last : item.images.first,
                                                    side: size)
                                            }
                                            /*
                                             HStack {
                                             Image(systemName: "photo")
                                             .resizable()
                                             .scaledToFit()
                                             .frame(width: 50, height: 50)
                                             .padding(10)
                                             .foregroundColor(.gray.opacity(0.2))
                                             .background(Color.secondary)
                                             .clipped()
                                             }
                                             .padding(-10)
                                             */
                                            VStack(alignment: .leading) {
                                                Text(item.name.isEmpty ? "👻" : item.name)
                                                    .lineLimit(1)
                                                    .font(.headline)
                                                if let box = boxes.first(where: { $0.id == item.box_uuid}),
                                                   let location = locations.first(where: { $0.id == box.location_uuid }) {
                                                    HStack {
                                                        HStack {
                                                            Text("\(box.name)")
                                                                .lineLimit(1)
                                                                .font(.footnote)
                                                                .foregroundStyle(Color(UIColor.secondarySystemBackground))
                                                        }
                                                        .foregroundColor(.white)
                                                        .padding(.vertical, 2)
                                                        .padding(.horizontal, 4)
                                                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4))
                                                        .cornerRadius(5)
                                                        .frame(height: 10)
                                                        HStack {
                                                            /*Image(systemName: "location")
                                                             .foregroundColor(.white)
                                                             .scaleEffect(0.7)
                                                             .frame(height: 10)
                                                             .padding(.trailing, -6)
                                                             */
                                                            Text(location.name.isEmpty ? "👻" : location.name)
                                                                .font(.footnote)
                                                                .foregroundStyle(isColorTooDark(color: stringToColor(location.color) ?? Color.clear ) ? Color.white.opacity(1) : Color.black.opacity(1))
                                                        }
                                                        .foregroundColor(.white)
                                                        .padding(.vertical, 2)
                                                        .padding(.horizontal, 4)
                                                        .background(stringToColor(location.color))
                                                        .cornerRadius(5)
                                                        .frame(height: 10)
                                                        Spacer()
                                                        if item.isFragile {
                                                            Image(systemName: "wineglass")
                                                                .foregroundStyle(selectedColor)
                                                                //.resizable()
                                                                .scaledToFit()
                                                                .frame(height: 10)
                                                        }
                                                        else {
                                                           /* Image(systemName: "wineglass")
                                                                .foregroundStyle(Color.secondary.opacity(0.3))
                                                                //.resizable()
                                                                .scaledToFit()
                                                                .frame(height: 10)*/
                                                        }

                                                        if item.isHeavy {
                                                            Image(systemName: "figure.strengthtraining.traditional")
                                                                .foregroundStyle(selectedColor)
                                                                //.resizable()
                                                                .scaledToFit()
                                                                .frame(height: 10)
                                                        }
                                                        else {
                                                            /*Image(systemName: "figure.strengthtraining.traditional")
                                                                .foregroundStyle(Color.secondary.opacity(0.3))
                                                                //.resizable()
                                                                .scaledToFit()
                                                                .frame(height: 10)*/
                                                        }
                                                    }
                                                }
                                                else {
                                                    HStack {
                                                        HStack {
                                                            Text("               ")
                                                                .lineLimit(1)
                                                                .font(.footnote)
                                                        }
                                                        .padding(.vertical, 2)
                                                        .padding(.horizontal, 4)
                                                        .background(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                                                        .cornerRadius(5)
                                                        .frame(height: 10)
                                                        HStack {
                                                            /*Image(systemName: "location")
                                                             .foregroundColor(.white)
                                                             .scaleEffect(0.7)
                                                             .frame(height: 10)
                                                             .padding(.trailing, -6)
                                                             */
                                                            Text("                              ")
                                                                .font(.footnote)
                                                        }
                                                        .foregroundColor(.white)
                                                        .padding(.vertical, 2)
                                                        .padding(.horizontal, 4)
                                                        .background(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                                                        .cornerRadius(5)
                                                        .frame(height: 10)
                                                        Spacer()
                                                    }
                                                }
                                            }
                                            .padding(.leading, 5)
                                            .padding(.bottom, 10)
                                        }
                                        .padding(.vertical, -15)
                                    }
                                    .padding(.leading, -21)
                                    .contentShape(Rectangle())
                                    .simultaneousGesture(
                                        LongPressGesture()
                                            .onEnded { _ in
                                                withAnimation {
                                                    isEditing = true
                                                }
                                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                                generator.impactOccurred()
                                            }
                                    )
                                }
                                else { //iOS 17
                                    NavigationLink(
                                        destination: ItemsDetailView(searchText: $searchText, item: Binding(
                                            get: { items.first(where: { $0.id == item.id }) ?? item },
                                            set: { newItem in
                                                if let updated = InventoryMutation.item(item.id, change: { $0 = newItem }) {
                                                    items = updated
                                                }
                                            }
                                        ))
                                    ) {
                                        HStack {
                                            /*
                                             HStack {
                                             Image(systemName: "photo")
                                             .resizable()
                                             .scaledToFit()
                                             .frame(width: 50, height: 50)
                                             .padding(10)
                                             .foregroundColor(.gray.opacity(0.2))
                                             .background(Color.secondary)
                                             .clipped()
                                             }
                                             .padding(-10)
                                             */
                                            VStack(alignment: .leading) {
                                                Text(item.name.isEmpty ? "👻" : item.name)
                                                    .lineLimit(1)
                                                    .font(.headline)
                                                if let box = boxes.first(where: { $0.id == item.box_uuid}),
                                                   let location = locations.first(where: { $0.id == box.location_uuid }) {
                                                    HStack {
                                                        HStack {
                                                            Text("\(box.name)")
                                                                .lineLimit(1)
                                                                .font(.footnote)
                                                                .foregroundStyle(Color(UIColor.secondarySystemBackground))
                                                        }
                                                        .foregroundColor(.white)
                                                        .padding(.vertical, 2)
                                                        .padding(.horizontal, 4)
                                                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4))
                                                        .cornerRadius(5)
                                                        .frame(height: 10)
                                                        HStack {
                                                            /*Image(systemName: "location")
                                                             .foregroundColor(.white)
                                                             .scaleEffect(0.7)
                                                             .frame(height: 10)
                                                             .padding(.trailing, -6)
                                                             */
                                                            Text(location.name.isEmpty ? "👻" : location.name)
                                                                .font(.footnote)
                                                                .foregroundStyle(isColorTooDark(color: stringToColor(location.color) ?? Color.clear ) ? Color.white.opacity(1) : Color.black.opacity(1))
                                                        }
                                                        .foregroundColor(.white)
                                                        .padding(.vertical, 2)
                                                        .padding(.horizontal, 4)
                                                        .background(stringToColor(location.color))
                                                        .cornerRadius(5)
                                                        .frame(height: 10)
                                                        Spacer()
                                                    }
                                                }
                                                else {
                                                    HStack {
                                                        HStack {
                                                            Text("               ")
                                                                .lineLimit(1)
                                                                .font(.footnote)
                                                        }
                                                        .padding(.vertical, 2)
                                                        .padding(.horizontal, 4)
                                                        .background(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                                                        .cornerRadius(5)
                                                        .frame(height: 10)
                                                        HStack {
                                                            /*Image(systemName: "location")
                                                             .foregroundColor(.white)
                                                             .scaleEffect(0.7)
                                                             .frame(height: 10)
                                                             .padding(.trailing, -6)
                                                             */
                                                            Text("                              ")
                                                                .font(.footnote)
                                                        }
                                                        .foregroundColor(.white)
                                                        .padding(.vertical, 2)
                                                        .padding(.horizontal, 4)
                                                        .background(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                                                        .cornerRadius(5)
                                                        .frame(height: 10)
                                                        Spacer()
                                                    }
                                                }
                                            }
                                            .padding(.leading, 10)
                                            .padding(.bottom, 10)
                                        }
                                        //.padding(15)
                                    }
                                    .padding(.horizontal, -15)
                                    .contentShape(Rectangle())
                                }
                            }
                        }
                    }
                    if shouldShowLoadAllButton {
                        Button {
                            hasLoadedAllItems = true
                        } label: {
                            Label("FirstTab.LoadAll", systemImage: "tray.and.arrow.down")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    HStack {
                        Spacer()
                        Text(filteredItems.isEmpty ? "" : "Items: \(items.count)")
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
                    if filteredItems.isEmpty {
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
                .zIndex(0)
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
                    selectedItems.removeAll { id in !items.contains(where: { $0.id == id }) }
                    allSelected = !filteredItems.isEmpty && filteredItems.allSatisfy { selectedItems.contains($0.id) }
                }
                .onReceive(NotificationCenter.default.publisher(for: .inventoryTransferCompleted)) { _ in
                    let inventory = InventoryStorageState.shared.readSnapshot()
                    if boxes != inventory.boxes { boxes = inventory.boxes }
                    if items != inventory.items { items = inventory.items }
                    if locations != inventory.locations { locations = inventory.locations }
                    selectedItems.removeAll(); allSelected = false
                    isEditing = false
                }
                .toolbar {
                    //if UIDevice.current.userInterfaceIdiom != .pad {
                        ToolbarItem(placement: .principal) {
                            SearchBar(text: $searchText)
                                .frame(width: 200)
                                //.frame(maxWidth: .infinity)
                        }
                   // }
                    FirstTabToolbar(isEditing: $isEditing, transfer: transfer,
                        count: selectedItems.count, total: filteredItems.count,
                        selectedColor: selectedColor,
                        canMove: true,
                        move: { itemsToMove = Set(selectedItems); showMoveItemView = true },
                        share: shareSelection,
                        delete: { showAlert = true },
                        selectAll: { selectAllItems() },
                        finish: { selectedItems.removeAll(); allSelected = false }) {

                            FirstTabSortOptions(criterion: $sortCriterion, ascending: $isAscending, list: $selectedOption)

                    }
                }
                .onAppear {
                    pinnedSearchSuggestionsItems = UserDefaults.standard.stringArray(forKey: "pinnedSearchSuggestionsItems") ?? []
                    numberofsearchSuggestions = UserDefaults.standard.integer(forKey: "numberofsearchSuggestions") == 0 ? 5 : UserDefaults.standard.integer(forKey: "numberofsearchSuggestions")
                    suggestions = UserDefaults.standard.object(forKey: "suggestions") == nil ? true : UserDefaults.standard.bool(forKey: "suggestions")
                    searchSuggestionsItems = UserDefaults.standard.stringArray(forKey: "searchSuggestionsItems") ?? []
                    UserDefaultsManager.shared.saveLastState("boxes")
                    pressAndHold = UserDefaultsManager.shared.loadPressAndHold()


                    selectedColor = UserDefaultsManager.loadAccentColor()
                    items = loadItems()
                    boxes = loadBoxes()
                    locations = loadLocations()
                }
                .onChange(of: selectedItems, initial: false) { _, _ in
                    allSelected = !filteredItems.isEmpty && filteredItems.allSatisfy { selectedItems.contains($0.id) }
                }
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text(String(format: NSLocalizedString("Delete %d items?", comment: ""), selectedItems.count)),
                        message: Text(NSLocalizedString("Are you sure you want to delete the selected items?", comment: "")),
                        primaryButton: .destructive(Text(String(localized: "Löschen"))) {
                            removeSelectedItems()
                            isEditing = false
                        },
                        secondaryButton: .cancel()
                    )
                }
                .sheet(isPresented: $showMoveItemView) {
                    NavigationStack {
                        MoveItemView(itemsToMove: $itemsToMove) {
                            // Nach dem Verschieben Listen und Auswahlzustand konsistent aktualisieren.
                            items = loadItems()
                            boxes = loadBoxes()
                            locations = loadLocations()
                            selectedItems.removeAll()
                            allSelected = false
                            isEditing = false
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showSpotlightItemDetail) {
                spotlightItemDestination()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSpotlightItem)) { notification in
                guard let itemID = notification.object as? UUID else { return }
                items = loadItems()
                boxes = loadBoxes()
                locations = loadLocations()
                guard items.contains(where: { $0.id == itemID }) else { return }
                spotlightItemID = itemID
                showSpotlightItemDetail = true
            }

        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isEditing && suggestions {
                if #available(iOS 26.0, *) {
                    //GeometryReader { geo in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {


                                // Gruppieren und nach Häufigkeit sortieren
                                let groupedPinnedSuggestions = Dictionary(grouping: pinnedSearchSuggestionsItems, by: { $0.lowercased() })
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

                                // Gruppieren und nach Häufigkeit sortieren
                                let groupedSuggestions = Dictionary(grouping: searchSuggestionsItems, by: { $0.lowercased() })
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
                                    .prefix(max(0, numberofsearchSuggestions - filteredPinnedSuggestions.count)) // hier Begrenzung auf 5

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
                                            searchSuggestionsItems.append(item.suggestion)
                                            pinnedSearchSuggestionsItems.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                            UserDefaults.standard.set(searchSuggestionsItems, forKey: "searchSuggestionsItems")
                                            UserDefaults.standard.set(pinnedSearchSuggestionsItems, forKey: "pinnedSearchSuggestionsItems")
                                            print("UNPIN \(item.suggestion)")
                                        }) {
                                            Label("unfavorite", systemImage: "star.slash")
                                        }
                                        Button(role: .destructive, action: {
                                            pinnedSearchSuggestionsItems.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                            UserDefaults.standard.set(pinnedSearchSuggestionsItems, forKey: "pinnedSearchSuggestionsItems")
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
                                        HStack{
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
                                            pinnedSearchSuggestionsItems.append(item.suggestion)
                                            searchSuggestionsItems.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                            UserDefaults.standard.set(searchSuggestionsItems, forKey: "searchSuggestionsItems")
                                            UserDefaults.standard.set(pinnedSearchSuggestionsItems, forKey: "pinnedSearchSuggestionsItems")
                                            print("PIN \(item.suggestion)")
                                        }) {
                                            Label("favorite", systemImage: "star")
                                        }

                                        Button(role: .destructive, action: {
                                            searchSuggestionsItems.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                            UserDefaults.standard.set(searchSuggestionsItems, forKey: "searchSuggestionsItems")
                                            print("DELETE \(item.suggestion)")
                                        }) {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                                }

                                if(!searchText.isEmpty){
                                    let allData = boxes.map { $0.name }
                                        + boxes.flatMap { $0.tags ?? [] }
                                        + items.flatMap { $0.tags ?? [] }
                                        + items.map { $0.name }
                                        + locations.map { $0.name }

                                    // Nur Werte, die nicht bereits in pinnedSearchSuggestions oder searchSuggestions sind
                                    let filteredAllData = allData.filter { value in
                                        !pinnedSearchSuggestionsItems.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) &&
                                        !searchSuggestionsItems.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame })
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
                                                pinnedSearchSuggestionsItems.append(item.suggestion)
                                                searchSuggestionsItems.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                                UserDefaults.standard.set(searchSuggestionsItems, forKey: "searchSuggestionsItems")
                                                UserDefaults.standard.set(pinnedSearchSuggestionsItems, forKey: "pinnedSearchSuggestionsItems")
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
                    //.frame(height: 60) // Höhe anpassen
                }
                else {
                    //GeometryReader { geo in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {


                                // Gruppieren und nach Häufigkeit sortieren
                                let groupedPinnedSuggestions = Dictionary(grouping: pinnedSearchSuggestionsItems, by: { $0.lowercased() })
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

                                // Gruppieren und nach Häufigkeit sortieren
                                let groupedSuggestions = Dictionary(grouping: searchSuggestionsItems, by: { $0.lowercased() })
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
                                    .prefix(max(0, numberofsearchSuggestions - filteredPinnedSuggestions.count)) // hier Begrenzung auf 5

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
                                            searchSuggestionsItems.append(item.suggestion)
                                            pinnedSearchSuggestionsItems.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                            UserDefaults.standard.set(searchSuggestionsItems, forKey: "searchSuggestionsItems")
                                            UserDefaults.standard.set(pinnedSearchSuggestionsItems, forKey: "pinnedSearchSuggestionsItems")
                                            print("UNPIN \(item.suggestion)")
                                        }) {
                                            Label("unfavorite", systemImage: "star.slash")
                                        }
                                        Button(role: .destructive, action: {
                                            pinnedSearchSuggestionsItems.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                            UserDefaults.standard.set(pinnedSearchSuggestionsItems, forKey: "pinnedSearchSuggestionsItems")
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
                                        HStack{
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
                                            pinnedSearchSuggestionsItems.append(item.suggestion)
                                            searchSuggestionsItems.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                            UserDefaults.standard.set(searchSuggestionsItems, forKey: "searchSuggestionsItems")
                                            UserDefaults.standard.set(pinnedSearchSuggestionsItems, forKey: "pinnedSearchSuggestionsItems")
                                            print("PIN \(item.suggestion)")
                                        }) {
                                            Label("favorite", systemImage: "star")
                                        }

                                        Button(role: .destructive, action: {
                                            searchSuggestionsItems.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                            UserDefaults.standard.set(searchSuggestionsItems, forKey: "searchSuggestionsItems")
                                            print("DELETE \(item.suggestion)")
                                        }) {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                                }

                                if(!searchText.isEmpty){
                                    let allData = boxes.map { $0.name }
                                        + boxes.flatMap { $0.tags ?? [] }
                                        + items.flatMap { $0.tags ?? [] }
                                        + items.map { $0.name }
                                        + locations.map { $0.name }

                                    // Nur Werte, die nicht bereits in pinnedSearchSuggestions oder searchSuggestions sind
                                    let filteredAllData = allData.filter { value in
                                        !pinnedSearchSuggestionsItems.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) &&
                                        !searchSuggestionsItems.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame })
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
                                                pinnedSearchSuggestionsItems.append(item.suggestion)
                                                searchSuggestionsItems.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                                UserDefaults.standard.set(searchSuggestionsItems, forKey: "searchSuggestionsItems")
                                                UserDefaults.standard.set(pinnedSearchSuggestionsItems, forKey: "pinnedSearchSuggestionsItems")
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
                    //.frame(height: 60) // Höhe anpassen
                }
            }
        }
    }

    private func removeSelectedItems() {
        let ids = Set(selectedItems)
        Task { @MainActor in
            do {
                _ = try await InventoryDeletion.shared.items(ids)
                items = loadItems()
                selectedItems.removeAll { ids.contains($0) }
                allSelected = false
            } catch { InventoryStorageState.shared.report(error) }
        }
    }

    private func selectAllItems() {
        if filteredItems.allSatisfy({ selectedItems.contains($0.id) }) {
            selectedItems.removeAll { selectedID in
                filteredItems.contains(where: { $0.id == selectedID })
            }
        } else {
            for item in filteredItems where !selectedItems.contains(item.id) {
                selectedItems.append(item.id)
            }
        }
        allSelected = !filteredItems.isEmpty && filteredItems.allSatisfy { selectedItems.contains($0.id) }
    }

    private var emptyState: some View {
        VStack {
            Spacer(minLength: 0)
            HStack {
                Spacer(minLength: 0)
                VStack(spacing: 10) {
                    Image(systemName: hasActiveSearch ? "magnifyingglass" : "square.grid.2x2")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(hasActiveSearch ? String(localized: "Keine Suchergebnisse") : String(localized: "Keine Gegenstände vorhanden"))
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
    private func spotlightItemDestination() -> some View {
        if let itemID = spotlightItemID, let itemBinding = bindingForItem(with: itemID) {
            ItemsDetailView(searchText: $searchText, item: itemBinding)
        } else {
            EmptyView()
        }
    }

    private func bindingForItem(with itemID: UUID) -> Binding<Items>? {
        guard let item = items.first(where: { $0.id == itemID }) else { return nil }
        return Binding(
            get: { items.first(where: { $0.id == itemID }) ?? item },
            set: { updatedItem in
                guard let updated = InventoryMutation.item(itemID, change: { $0 = updatedItem }) else { return }
                items = updated
            }
        )
    }
}

#Preview {
    NavigationStack {
        MutiTabView(selectedOption: .constant("items"))
    }
}

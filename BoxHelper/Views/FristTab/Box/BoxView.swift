//
//  OverviewView.swift
//  ios-app-test
//

import SwiftUI
import UIKit
import TipKit



/// Listeninhalt; Navigation und Tabpicker stellt der gemeinsame Listentab bereit.
struct BoxView: View {
    //@Binding var BoxUUID : UUID?
    @State private var selectedImageOrderOption = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
    @State private var croppedImages: [UUID: UIImage] = [:]
    @State private var isActiveLink: Bool = true
    @State private var path: [UUID] = []
    @State private var boxes: [MovingBox] = []
    @State private var items: [Items] = []
    @State private var locations: [Locations] = []
    @Binding var searchText: String
    @Binding var isScrolling: Bool
    @State private var selectedBoxes: [UUID] = []
    @StateObject private var transfer = InventoryTransferController()
    @State private var isEditing = false
    @State private var showAlert = false
    @State private var showMoveBoxesSheet = false
    @State private var showPrintBoxesSheet = false
    @State private var backgroundColor: Color = Color.clear  // Neue State-Variable für die Hintergrundfarbe
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("showImages") private var showImages: Bool = true
    @AppStorage("showDetails") private var showDetails: Bool = true
    @AppStorage("showDetailsLocation") private var showDetailsLocation: Bool = true
    @AppStorage("showDetailsItems") private var showDetailsItems: Bool = false
    @AppStorage("showDetailsItemsCounter") private var showDetailsItemsCounter: Bool = true
    @AppStorage("showDetailsTagCounter") private var showDetailsTagCounter: Bool = true
    @AppStorage("showDetailsImagesCounter") private var showDetailsImagesCounter: Bool = true
    @State private var pressAndHold: Bool = UserDefaultsManager.shared.loadPressAndHold()
    ///TAGS DEAKTIVIERT!!!!
    @AppStorage("showTags") private var showTags: Bool = true
    @AppStorage("showDetailsDate1") private var showDetailsDate1: Bool = false
    @AppStorage("showDetailsDate2") private var showDetailsDate2: Bool = false
    @AppStorage("sliderValue") private var sliderValue: Double = 50.0
    @State private var isEditing2: Bool = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var dragOffset: CGSize = .zero
    @State private var initialOffset: CGSize = .zero
    @State var shown = false
    @State var viewtype = "view" //"view"
    @State var isExpanded: Bool = false
    @State var expandedSection : UUID?
    @State private var searchResultList: [String] = []
    @State private var showToolbar = false
    @State private var searchHistory: [String] = (UserDefaults.standard.stringArray(forKey: "SearchHistroy") ?? [""])
    @State private var searchSuggestions: [String] = UserDefaults.standard.stringArray(forKey: "searchSuggestions") ?? []
    @State private var pinnedSearchSuggestions: [String] = UserDefaults.standard.stringArray(forKey: "pinnedSearchSuggestions") ?? []
    @State private var suggestions: Bool = UserDefaults.standard.object(forKey: "suggestions") == nil ? true : UserDefaults.standard.bool(forKey: "suggestions")
    @State private var numberofsearchSuggestions: Int = UserDefaults.standard.integer(forKey: "numberofsearchSuggestions") == 0 ? 5 : UserDefaults.standard.integer(forKey: "numberofsearchSuggestions")
    @State private var selectedImageCropType: String = UserDefaults.standard.string(forKey: "imageCropType") ?? "default"
    @AppStorage(FirstTabListLimit.alwaysLoadAllKey) private var alwaysLoadAllFirstTabLists: Bool = false
    @AppStorage(FirstTabListLimit.customLimitKey) private var customFirstTabListLimit: Int = 0
    @AppStorage(FirstTabListLimit.showLoadAllButtonKey) private var showLoadAllButton = true
    @State private var hasLoadedAllBoxes = false
    enum SortCriterion: String, FirstTabSortCriterion {
        case name = "Name"
        case items = "Items"
        case createdAt = "Created At"
        case updatedAt = "Updated At"

        var localized: String {
            return NSLocalizedString(self.rawValue, comment: "")
        }

        var iconName: String {
            switch self {
            case .name:
                return "textformat"
            case .items:
                return "square.grid.2x2"
            case .createdAt:
                return "calendar"
            case .updatedAt:
                return "clock"
            }
        }
    }

    @Binding var selectedOption : String

    // Sortierkriterium und Richtung pro Liste optional auch über App-Neustarts hinweg merken.
    @RememberedListSorting("boxesListSortCriterion") private var sortCriterion: SortCriterion = .createdAt
    @RememberedListSorting("boxesListSortAscending") private var isAscending: Bool = true

    private func removeBoxes(at offsets: IndexSet) {
        let ids = Set(offsets.compactMap { boxes.indices.contains($0) ? boxes[$0].id : nil })
        deleteBoxes(ids)
    }

    private func removeSelectedBoxes() {
        deleteBoxes(Set(selectedBoxes))
    }

    private func deleteBoxes(_ ids: Set<UUID>) {
        Task { @MainActor in
            do {
                _ = try await InventoryDeletion.shared.boxes(ids)
                boxes = loadBoxes()
                items = loadItems()
                selectedBoxes.removeAll { ids.contains($0) }
            } catch { InventoryStorageState.shared.report(error) }
        }
    }

    var filteredBoxes: [MovingBox] {
        if searchText.isEmpty {
            return boxes
        } else {
            let lowercasedSearchText = searchText.lowercased()

            return boxes.filter { box in
                // Box-Name
                let nameMatch = box.name.lowercased().contains(lowercasedSearchText)

                // Standortname
                let locationNameMatch: Bool = {
                    if let location_uuid = box.location_uuid,
                       let location = locations.first(where: { $0.id == location_uuid }) {
                        return location.name.lowercased().contains(lowercasedSearchText)
                    }
                    return false
                }()

                let boxTagsMatch: Bool
                if showTags {
                    boxTagsMatch = box.tags?.contains(where: {
                        $0.lowercased().contains(lowercasedSearchText)
                    }) ?? false
                } else {
                    boxTagsMatch = false
                }

                let matchesBoxFields = nameMatch || locationNameMatch || boxTagsMatch

                // Items durchsuchen
                let matchesItems = items.contains { item in
                    // Prüfen, ob das Item zu dieser Box gehört
                    guard item.box_uuid == box.id else { return false }

                    return item.name.lowercased().contains(lowercasedSearchText) ||
                           item.description?.lowercased().contains(lowercasedSearchText) ?? false ||
                           (item.tags?.contains(where: { $0.lowercased().contains(lowercasedSearchText) }) ?? false)
                }

                return matchesBoxFields || matchesItems
            }
        }
    }

    // Distinguish between "no data yet" and "search has no matches".
    private var hasActiveSearch: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sortedBoxes: [MovingBox] {
        filteredBoxes.sorted(by: { (box1, box2) -> Bool in
            switch sortCriterion {
            case .name:
                return isAscending ? box1.name < box2.name : box1.name > box2.name
            case .items:
                let itemsByBox = Dictionary(grouping: items, by: { $0.box_uuid })
                let count1 = itemsByBox[box1.id]?.count ?? 0
                let count2 = itemsByBox[box2.id]?.count ?? 0
                return isAscending ? count1 < count2 : count1 > count2
            case .createdAt:
                return isAscending ? box1.createdAt < box2.createdAt : box1.createdAt > box2.createdAt
            case .updatedAt:
                return isAscending ? box1.updatedAt < box2.updatedAt : box1.updatedAt > box2.updatedAt
            }
        })
    }

    private var visibleBoxes: [MovingBox] {
        guard showLoadAllButton, !alwaysLoadAllFirstTabLists, !hasLoadedAllBoxes else { return sortedBoxes }
        return Array(sortedBoxes.prefix(FirstTabListLimit.limit(customLimit: customFirstTabListLimit)))
    }

    private var shouldShowLoadAllButton: Bool {
        showLoadAllButton && !alwaysLoadAllFirstTabLists && !hasLoadedAllBoxes && visibleBoxes.count < sortedBoxes.count
    }

    private func shareSelection() {
        let selected = boxes.filter { selectedBoxes.contains($0.id) }
        transfer.export(InventoryTransferBuilder.boxes(selected, allItems: items, allLocations: locations))
    }

    var body: some View {
        Group {
            ZStack {
                List {

                    ForEach(visibleBoxes) { box in
                        //befülle Suchergebnisse:
                        Section {
                            ZStack {
                                // Hintergrundfarbe für ausgewählte Boxen
                                if selectedBoxes.contains(box.id) {
                                    Color.gray.opacity(0.3)
                                        .padding(-10)
                                } else {
                                    Color.clear
                                }

                                ZStack {
                                    if isEditing {

                                    }

                                    if !isEditing && viewtype == "view" {
                                        if pressAndHold {
                                            NavigationLink(
                                                destination: BoxDetailView(
                                                    searchText: $searchText,
                                                    selectedOption: $selectedOption,
                                                    box: Binding(
                                                        get: { boxes.first(where: { $0.id == box.id }) ?? box },
                                                        set: { newBox in
                                                            if let updated = InventoryMutation.box(box.id, change: { $0 = newBox }) {
                                                                boxes = updated
                                                            }
                                                        }
                                                    )
                                                )

                                            ) {
                                                boxContent(for: box)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
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
                                        else {
                                            NavigationLink(
                                                destination: BoxDetailView(
                                                    searchText: $searchText,
                                                    selectedOption: $selectedOption,
                                                    box: Binding(
                                                        get: { boxes.first(where: { $0.id == box.id }) ?? box },
                                                        set: { newBox in
                                                            if let updated = InventoryMutation.box(box.id, change: { $0 = newBox }) {
                                                                boxes = updated
                                                            }
                                                        }
                                                    )
                                                )

                                            ) {
                                                boxContent(for: box)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .contentShape(Rectangle())
                                        }
                                        /*
                                        .contextMenu {
                                            Button(role: .destructive, action: {
                                                //removeBoxes(at: box)
                                            }) {
                                                Image(systemName: "trash")
                                                /*
                                                Text("Settings.delete")
                                                    .foregroundColor(.red) // Setze den Text auf rot
                                                 */
                                            }
                                            Button(role: .destructive, action: {
                                                //removeBoxes(at: box)
                                            }) {
                                                Image(systemName: "trash")
                                                /*
                                                Text("Settings.delete")
                                                    .foregroundColor(.red) // Setze den Text auf rot
                                                 */
                                            }
                                            Divider()
                                            Button(action: {
                                                print("Markiert")
                                            }) {
                                                Label("Markieren", systemImage: "flag")
                                            }
                                        }
                                        /*
                                        preview: {
                                            HStack {
                                                boxContent1(for: box)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .padding(.horizontal, -8)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(-4)
                                            .padding(.trailing, isEditing ? 0 : 16)


                                        }
                                         */
                                         */
                                    }

                                    if isEditing {
                                        ZStack {
                                            VStack {
                                                Spacer()
                                                HStack {
                                                    Image(systemName: selectedBoxes.contains(box.id) ? "checkmark.circle.fill" : "circle")
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: 20, height: 20)
                                                        .symbolRenderingMode(.palette)
                                                        .foregroundStyle(!selectedBoxes.contains(box.id) ? Color(UIColor.darkGray) : Color.white, selectedBoxes.contains(box.id) ? selectedColor : Color(UIColor.darkGray))
                                                        .onTapGesture {
                                                            if selectedBoxes.contains(box.id) {
                                                                // Entferne box.id aus dem Array
                                                                selectedBoxes.removeAll { $0 == box.id }
                                                            } else {
                                                                // Füge box.id zum Array hinzu
                                                                selectedBoxes.append(box.id)
                                                            }
                                                            hideKeyboard()
                                                        }
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                Spacer()
                                            }
                                            //.padding(.top, 20)
                                            .padding(.leading, 20)
                                            .ignoresSafeArea()
                                            .frame(maxHeight: .infinity)
                                            .zIndex(100)
                                            boxContent(for: box)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            if selectedBoxes.contains(box.id) {
                                                // Entferne box.id aus dem Array
                                                selectedBoxes.removeAll { $0 == box.id }
                                            } else {
                                                // Füge box.id zum Array hinzu
                                                selectedBoxes.append(box.id)
                                            }
                                            hideKeyboard()
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(-5)
                            .padding(.trailing, isEditing ? 0 : 16)
                            .padding(.leading, -16)
                            .padding(-10)
                        }
                        if showToolbar {
                            SettingsView()
                                .frame(width: 300, height: 400) // Größe der Vorschau
                        }
                    }
                    if shouldShowLoadAllButton {
                        Button {
                            hasLoadedAllBoxes = true
                        } label: {
                            Label("FirstTab.LoadAll", systemImage: "tray.and.arrow.down")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    //.onDelete(perform: removeBoxes)

                    HStack {
                        Spacer()
                        Text(filteredBoxes.isEmpty ? "" : itemText())
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
                    if filteredBoxes.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
                    }
                }
                .zIndex(1)
                .contentMargins(.top, 0, for: .scrollContent)
                /*
                .if(UIDevice.current.userInterfaceIdiom == .pad) { view in
                    view.searchable(text: $searchText, placement: .navigationBarDrawer)
                }
                 */
                .listSectionSpacing(8.0)
                //.listStyle(PlainListStyle())
                .frame(maxWidth: .infinity)
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
                    selectedBoxes.removeAll { id in !boxes.contains(where: { $0.id == id }) }
                }
                .onReceive(NotificationCenter.default.publisher(for: .inventoryTransferCompleted)) { _ in
                    let inventory = InventoryStorageState.shared.readSnapshot()
                    if boxes != inventory.boxes { boxes = inventory.boxes }
                    if items != inventory.items { items = inventory.items }
                    if locations != inventory.locations { locations = inventory.locations }
                    selectedBoxes.removeAll()
                    isEditing = false
                }
                /*
                .if(UIDevice.current.userInterfaceIdiom == .pad) { view in
                    view.searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
                }
                */
                .toolbar {
                    //if UIDevice.current.userInterfaceIdiom != .pad {
                        ToolbarItem(placement: .principal) {
                            SearchBar(text: $searchText)
                                .onChange(of: searchText, initial: false){ oldValue, newValue in


                                    if searchHistory.count > 9 {
                                        searchHistory.removeAll(where: {$0 == searchHistory.first})
                                    }
                                    if searchHistory.contains(searchText) {
                                        print("liegt im Content")
                                    }
                                    //ForEach(searchHistory, id: \.self) { serach in
                                        //if !searchText.contains(String(serach)) {
                                            searchHistory.append(newValue)
                                            UserDefaults.standard.set(searchHistory, forKey: "SearchHistroy")
                                            print("searchHistory: \(searchHistory)")
                                        //}
                                    //}
                                }
                                .frame(width: 200)
                                //.frame(maxWidth: .infinity)
                        }
                    //}
                    FirstTabToolbar(isEditing: $isEditing, transfer: transfer,
                        count: selectedBoxes.count, total: filteredBoxes.count,
                        selectedColor: selectedColor,
                        canMove: moveTargetLocations.isEmpty == false,
                        move: { showMoveBoxesSheet = true },
                        printSelection: { showPrintBoxesSheet = true },
                        share: shareSelection,
                        delete: { showAlert = true },
                        selectAll: { selectAll() },
                        finish: { selectedBoxes.removeAll() }) {

                            FirstTabSortOptions(criterion: $sortCriterion, ascending: $isAscending, list: $selectedOption)

                    }

                }
                .onAppear {
                    UserDefaultsManager.shared.saveLastState("boxes")
                    isActiveLink = true
                    selectedColor = UserDefaultsManager.loadAccentColor()
                    pressAndHold = UserDefaultsManager.shared.loadPressAndHold()


                }
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text(String(format: NSLocalizedString("overview.deleteBoxes", comment: ""), selectedBoxes.count)),
                        message: Text(NSLocalizedString("overview.deleteBoxes2", comment: "")),
                        primaryButton: .destructive(Text(NSLocalizedString("Settings.delete", comment: ""))) {
                            deleteImagesAndBoxes() // Aufruf der Funktion zum Löschen
                            isEditing = false
                        },
                        secondaryButton: .cancel()
                    )
                }
                .sheet(isPresented: $showPrintBoxesSheet) {
                    BoxBatchPrintSheet(boxes: selectedPrintBoxes, locations: locations)
                }
                .sheet(isPresented: $showMoveBoxesSheet) {
                    MoveBoxesSheetView(
                        selectedCount: selectedBoxes.count,
                        selectedNamesText: selectedBoxNamesText,
                        targetLocations: moveTargetLocations,
                        boxCount: boxCount(for:),
                        onCancel: {
                            showMoveBoxesSheet = false
                        },
                        onMoveConfirmed: { targetLocationID in
                            moveSelectedBoxes(to: targetLocationID)
                        }
                    )
                }
                .onAppear {
                   pinnedSearchSuggestions = UserDefaults.standard.stringArray(forKey: "pinnedSearchSuggestions") ?? []
                    numberofsearchSuggestions = UserDefaults.standard.integer(forKey: "numberofsearchSuggestions") == 0 ? 5 : UserDefaults.standard.integer(forKey: "numberofsearchSuggestions")
                    suggestions = UserDefaults.standard.object(forKey: "suggestions") == nil ? true : UserDefaults.standard.bool(forKey: "suggestions")
                    selectedImageOrderOption = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
                    boxes = loadBoxes()
                    //print("Boxes: \(boxes)")
                    items = loadItems()
                    locations = loadLocations()
                    selectedImageCropType = UserDefaults.standard.string(forKey: "imageCropType") ?? "default"
                }
            }

        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isEditing && suggestions{
                if #available(iOS 26.0, *) {
                    //GeometryReader { geo in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                // Gruppieren und nach Häufigkeit sortieren
                                let groupedPinnedSuggestions = Dictionary(grouping: pinnedSearchSuggestions, by: { $0.lowercased() })
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
                                let groupedSuggestions = Dictionary(grouping: searchSuggestions, by: { $0.lowercased() })
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
                                            searchSuggestions.append(item.suggestion)
                                            pinnedSearchSuggestions.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                            UserDefaults.standard.set(searchSuggestions, forKey: "searchSuggestions")
                                            UserDefaults.standard.set(pinnedSearchSuggestions, forKey: "pinnedSearchSuggestions")
                                            print("UNPIN \(item.suggestion)")
                                        }) {
                                            Label("unfavorite", systemImage: "star.slash")
                                        }
                                        Button(role: .destructive, action: {
                                            pinnedSearchSuggestions.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                            UserDefaults.standard.set(pinnedSearchSuggestions, forKey: "pinnedSearchSuggestions")
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
                                            pinnedSearchSuggestions.append(item.suggestion)
                                            searchSuggestions.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                            UserDefaults.standard.set(searchSuggestions, forKey: "searchSuggestions")
                                            UserDefaults.standard.set(pinnedSearchSuggestions, forKey: "pinnedSearchSuggestions")
                                            print("PIN \(item.suggestion)")
                                        }) {
                                            Label("favorite", systemImage: "star")
                                        }
                                        Button(role: .destructive, action: {
                                            searchSuggestions.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                            UserDefaults.standard.set(searchSuggestions, forKey: "searchSuggestions")
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
                                        + items.map { $0.name }
                                        + locations.map { $0.name }

                                    // Nur Werte, die nicht bereits in pinnedSearchSuggestions oder searchSuggestions sind
                                    let filteredAllData = allData.filter { value in
                                        !pinnedSearchSuggestions.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) &&
                                        !searchSuggestions.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame })
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
                                                pinnedSearchSuggestions.append(item.suggestion)
                                                searchSuggestions.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                                UserDefaults.standard.set(searchSuggestions, forKey: "searchSuggestions")
                                                UserDefaults.standard.set(pinnedSearchSuggestions, forKey: "pinnedSearchSuggestions")
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
                                let groupedPinnedSuggestions = Dictionary(grouping: pinnedSearchSuggestions, by: { $0.lowercased() })
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
                                let groupedSuggestions = Dictionary(grouping: searchSuggestions, by: { $0.lowercased() })
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
                                            searchSuggestions.append(item.suggestion)
                                            pinnedSearchSuggestions.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                            UserDefaults.standard.set(searchSuggestions, forKey: "searchSuggestions")
                                            UserDefaults.standard.set(pinnedSearchSuggestions, forKey: "pinnedSearchSuggestions")
                                            print("UNPIN \(item.suggestion)")
                                        }) {
                                            Label("unfavorite", systemImage: "star.slash")
                                        }
                                        Button(role: .destructive, action: {
                                            pinnedSearchSuggestions.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                            UserDefaults.standard.set(pinnedSearchSuggestions, forKey: "pinnedSearchSuggestions")
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
                                            pinnedSearchSuggestions.append(item.suggestion)
                                            searchSuggestions.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                            UserDefaults.standard.set(searchSuggestions, forKey: "searchSuggestions")
                                            UserDefaults.standard.set(pinnedSearchSuggestions, forKey: "pinnedSearchSuggestions")
                                            print("PIN \(item.suggestion)")
                                        }) {
                                            Label("favorite", systemImage: "star")
                                        }
                                        Button(role: .destructive, action: {
                                            searchSuggestions.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                            UserDefaults.standard.set(searchSuggestions, forKey: "searchSuggestions")
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
                                        + items.map { $0.name }
                                        + locations.map { $0.name }

                                    // Nur Werte, die nicht bereits in pinnedSearchSuggestions oder searchSuggestions sind
                                    let filteredAllData = allData.filter { value in
                                        !pinnedSearchSuggestions.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) &&
                                        !searchSuggestions.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame })
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
                                                pinnedSearchSuggestions.append(item.suggestion)
                                                searchSuggestions.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                                UserDefaults.standard.set(searchSuggestions, forKey: "searchSuggestions")
                                                UserDefaults.standard.set(pinnedSearchSuggestions, forKey: "pinnedSearchSuggestions")
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
                        .defaultScrollAnchor(.center, for: .alignment)
                        .scrollBounceBehavior(.basedOnSize)
                        .frame(height: 60)
                    //}
                    //.frame(height: 60) // Höhe anpassen
                }
            }
        }
        .onAppear {
            UserDefaultsManager.shared.saveShowImages(true)
            UserDefaultsManager.shared.saveSliderValue(105)
            searchSuggestions = UserDefaults.standard.stringArray(forKey: "searchSuggestions") ?? []
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer(minLength: 0)
            HStack {
                Spacer(minLength: 0)
                VStack(spacing: 10) {
                    Image(systemName: hasActiveSearch ? "magnifyingglass" : "shippingbox")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(hasActiveSearch ? String(localized: "Keine Suchergebnisse") : String(localized: "Keine Kisten vorhanden"))
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
    // Kiste, Kinder und Fotos folgen in allen Ansichten derselben Löschregel.
    private func deleteImagesAndBoxes() {
        removeSelectedBoxes()
    }
    private func itemText() -> String {
        if boxes.isEmpty {
            return String(format: NSLocalizedString("overview.boxes", comment: ""), boxes.count)
        } else if !searchText.isEmpty {
            return String(format: NSLocalizedString("overview.boxesof", comment: ""), filteredBoxes.count, boxes.count)

        } else {
            return String(format: NSLocalizedString("overview.boxes", comment: ""), boxes.count)

        }
    }
    // Sichtbare Reihenfolge beibehalten; auch durch Filter verborgene Auswahl drucken.
    private var selectedPrintBoxes: [MovingBox] {
        let visible = filteredBoxes.filter { selectedBoxes.contains($0.id) }
        let visibleIDs = Set(visible.map(\.id))
        return visible + boxes.filter { selectedBoxes.contains($0.id) && !visibleIDs.contains($0.id) }
    }

    private var printSelectedBoxesButton: some View {
        Button { showPrintBoxesSheet = true } label: {
            Image(systemName: "printer.fill")
                .frame(width: 44, height: 44)
                .foregroundStyle(selectedBoxes.isEmpty ? Color.gray : selectedColor)
                .contentShape(Rectangle())
        }
        .disabled(selectedBoxes.isEmpty)
        .accessibilityLabel("Print QR Code")
    }

    private func selectAll() {
        // Prüft, ob alle `filteredBoxes` in `selectedBoxes` enthalten sind.
        if filteredBoxes.allSatisfy({ selectedBoxes.contains($0.id) }) {
            // Wenn ja, entferne alle IDs der `filteredBoxes` aus `selectedBoxes`
            selectedBoxes.removeAll { boxID in
                filteredBoxes.contains(where: { $0.id == boxID })
            }
        } else {
            // Wenn nein, füge alle IDs der `filteredBoxes` zu `selectedBoxes` hinzu
            for box in filteredBoxes {
                if !selectedBoxes.contains(box.id) {
                    selectedBoxes.append(box.id)
                }
            }
        }
    }

    // Clears current multi-selection without leaving edit mode.
    private func clearBoxSelection() {
        selectedBoxes.removeAll()
    }

    // Liefert alle verfügbaren Zielstandorte für den gemeinsamen Verschieben-Sheet.
    private var moveTargetLocations: [Locations] {
        locations
    }

    private var selectedBoxNamesText: String {
        let names = boxes
            .filter { selectedBoxes.contains($0.id) }
            .map { $0.name.isEmpty ? "👻" : $0.name }
        return names.isEmpty ? String(localized: "Keine Kisten ausgewählt.") : names.joined(separator: ", ")
    }

    private func boxCount(for targetLocation: Locations) -> Int {
        boxes.filter { $0.location_uuid == targetLocation.id }.count
    }

    private func moveSelectedBoxes(to targetLocationID: UUID) {
        guard !selectedBoxes.isEmpty else { return }
        do {
            let snapshot = try InventoryPersistence.snapshot()
            guard snapshot.locations.contains(where: { $0.id == targetLocationID }) else {
                throw IntentInventoryError.notFound
            }
            var updatedBoxes = snapshot.boxes
            for index in updatedBoxes.indices where selectedBoxes.contains(updatedBoxes[index].id) {
                updatedBoxes[index].location_uuid = targetLocationID
            }
            try InventoryPersistence.applyBoxChanges(from: snapshot.boxes, to: updatedBoxes)
            boxes = updatedBoxes
            selectedBoxes.removeAll()
            showMoveBoxesSheet = false
            isEditing = false
        } catch { InventoryStorageState.shared.report(error) }
    }

    private func itemsText() -> String {
        if boxes.isEmpty {
            /*let funnyMessages = [
                "overview.funnymessage1",
                "overview.funnymessage2",
                "overview.funnymessage3",
                "overview.funnymessage4",
                "overview.funnymessage5"
            ]*/
            return ""
        } else if !searchText.isEmpty {
            _ = items.filter { item in
                filteredBoxes.contains(where: { $0.id == item.box_uuid })
            }.count

            _ = items.filter { item in
                boxes.contains(where: { $0.id == item.box_uuid })
            }.count

            return "" // String(format: NSLocalizedString("overview.itemsof", comment: ""), totalItemCount, totalItemCount2)

        } else {
            let totalItemCount = items.filter { item in
                filteredBoxes.contains(where: { $0.id == item.box_uuid })
            }.count

            return String(format: NSLocalizedString("Items: %lld", comment: ""), totalItemCount)
        }
    }

    private func boxContent(for box: MovingBox) -> some View {
        HStack {
            if showImages {
                if let previewImagePath = previewImagePath(for: box) {
                    BoxRowThumbnailView(
                        imagePath: previewImagePath,
                        side: sliderValue,
                        imageCropType: selectedImageCropType
                    )
                } else {
                    HStack(alignment: .center) {
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .padding(.leading, 4)
                            .foregroundColor(colorScheme == .dark
                                ? Color.black.opacity(0.2)
                                : Color.white.opacity(0.3))
                    }
                    .frame(width: sliderValue - 20, height: sliderValue - 20)
                    .padding(10)
                    .background(colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.1))
                    .clipped()
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(box.name)
                    .font(.headline)
                    .lineLimit(1)
                    //.padding(.top, 5)
                    //.background(Color.red.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showDetails && (showDetailsLocation || showDetailsItemsCounter || showDetailsTagCounter || showDetailsImagesCounter){
                    VStack(spacing: 5) {
                        if showDetailsLocation, !box.category.isEmpty  {
                            HStack {
                                HStack {
                                    /*Image(systemName: "location")
                                        .foregroundColor(.white)
                                        .scaleEffect(0.7)
                                        .frame(height: 10)
                                        .padding(.trailing, -6)
                                     */
                                    Text(box.category)
                                        .lineLimit(1)
                                        .font(.footnote)
                                        .foregroundStyle(isColorTooDark(color: stringToColor(box.color) ?? .clear ) ? Color.white.opacity(1) : Color.black.opacity(1)  )
                                }
                                .foregroundColor(.white)
                                .padding(4)
                                .background(stringToColor(box.color))
                                .cornerRadius(5)
                                .frame(height: 10)
                                Spacer()
                            }
                            .frame(height: 10)
                            //.padding(.top, 8)
                            //.padding(.bottom, 5)
                        }
                        if showDetailsLocation {
                            if let location_uuid = box.location_uuid {
                                if let location = locations.first(where: { $0.id == location_uuid })  {
                                    HStack {
                                        HStack {
                                            /*Image(systemName: "location")
                                             .foregroundColor(.white)
                                             .scaleEffect(0.7)
                                             .frame(height: 10)
                                             .padding(.trailing, -6)
                                             */
                                            Text(location.name.isEmpty ? "👻" : location.name)
                                                .lineLimit(1)
                                                .font(.footnote)
                                                .foregroundStyle(isColorTooDark(color: stringToColor(location.color) ?? .clear ) ? Color.white.opacity(1) : Color.black.opacity(1)  )
                                        }
                                        .foregroundColor(.white)
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 4)
                                        .background(stringToColor(location.color))
                                        .cornerRadius(5)
                                        Spacer()
                                    }
                                    //.padding(.top, 8)
                                }
                            }
                        }
                        if showDetailsItems {
                            let relatedItems = items.filter { $0.box_uuid == box.id } // <- Neue Logik

                            if !relatedItems.isEmpty {
                                HStack(spacing: 5) {
                                    ForEach(relatedItems, id: \.id) { item in
                                        HStack {
                                            Text(item.name.isEmpty ? "👻" : item.name)
                                                .lineLimit(1)
                                                .font(.footnote)
                                                .fixedSize()
                                        }
                                        .foregroundStyle(Color(UIColor.secondarySystemBackground))
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 4)
                                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4))
                                        .cornerRadius(5)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        if showDetailsItemsCounter || (showDetailsTagCounter && showTags) || showDetailsImagesCounter {
                            HStack {
                                if showDetailsItemsCounter {
                                    HStack {
                                        //if showDetailsTagCounter && showTags {
                                        Image(systemName: "square.grid.2x2")
                                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4)  )
                                            .scaleEffect(0.7)
                                            .frame(height: 10)
                                            .padding(.trailing, -6)
                                        //}
                                        Text("\(items.filter { $0.box_uuid == box.id }.count)")
                                            .font(.footnote)
                                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4)  )
                                    }
                                    .padding(.trailing,2)
                                    //.background(colorScheme == .dark ? Color.black : Color.white)
                                    .cornerRadius(5)
                                }
                                if showDetailsTagCounter && showTags {
                                    if let tags = box.tags {
                                        HStack {
                                            //if showDetailsItemsCounter {
                                            Image(systemName: "tag")
                                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4)  )
                                                .scaleEffect(0.7)
                                                .frame(height: 10)
                                                .padding(.trailing, -6)
                                            //}
                                            Text("\(tags.count)")
                                                .font(.footnote)
                                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4)  )
                                        }
                                        .padding(.trailing,2)
                                        //.background(colorScheme == .dark ? Color.black : Color.white)
                                        .cornerRadius(5)
                                    }
                                }
                                if showDetailsImagesCounter {
                                    HStack {
                                        //if showDetailsTagCounter && showTags {
                                        Image(systemName: "photo")
                                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4)  )
                                            .scaleEffect(0.7)
                                            .frame(height: 10)
                                            .padding(.trailing, -6)
                                        //}
                                        Text("\(box.images.count)")
                                            .font(.footnote)
                                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4)  )
                                    }
                                    .padding(.trailing,2)
                                    //.background(colorScheme == .dark ? Color.black : Color.white)
                                    .cornerRadius(5)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, -1)
                            .padding(.leading, -3)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            //.background(Color.red.opacity(0.5))
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 20)
            .padding(.leading, 5)
            if showDetails && (showDetailsDate1 || showDetailsDate2) {
                VStack{
                    if showDetailsDate1 {
                        Text("\(formattedDate(box.createdAt))")
                            .lineLimit(2)
                            .font(.footnote)
                            .padding(3)
                            .background(Color(.red).opacity(0.4))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4))
                            .cornerRadius(5)
                    }
                    if showDetailsDate2 {
                        Text("\(formattedDate(box.updatedAt))")
                            .lineLimit(2)
                            .font(.footnote)
                            .padding(3)
                            .background(Color(.green).opacity(0.4))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.4))
                            .cornerRadius(5)
                    }
                }
            }
        }
        .padding(.leading, 10)
    }

    // Keeps the list row focused on the currently displayed image only.
    private func previewImagePath(for box: MovingBox) -> String? {
        selectedImageOrderOption == "new" ? box.images.last : box.images.first
    }
}

private struct BoxRowThumbnailView: View {
    let imagePath: String
    let side: Double
    let imageCropType: String
    private let request: InventoryThumbnailLoader.Request

    @ObservedObject private var storage = InventoryStorageState.shared

    @State private var image: UIImage?

    init(imagePath: String, side: Double, imageCropType: String) {
        self.imagePath = imagePath
        self.side = side
        self.imageCropType = imageCropType
        request = InventoryThumbnailLoader.Request(filename: imagePath,
            maxPixelSize: CGFloat(side) * UIScreen.main.scale, variant: imageCropType)
        _image = State(initialValue: InventoryThumbnailLoader.shared.cachedImage(for: request))
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(UIColor.systemFill))
            }
        }
        .frame(width: side, height: side)
        .clipped()
        .task(id: InventoryThumbnailLoader.TaskIdentity(request: request, mediaRevision: storage.mediaRevision)) {
            // Ein Cloud-Download kann den Inhalt eines vorhandenen Dateinamens ändern.
            // Der Worker prüft nur dessen Version; unveränderte Bilder bleiben im Cache.
            let cropType = imageCropType
            let loaded = await InventoryThumbnailLoader.shared.load(request, mediaRevision: storage.mediaRevision) { thumbnail in
                cropType == "auto" ? detectMotifAndCrop(image: thumbnail, imageCropType: cropType) ?? thumbnail : thumbnail
            }
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }
}

#Preview {
    NavigationStack {
        MutiTabView(selectedOption: .constant("boxes"))
    }
}

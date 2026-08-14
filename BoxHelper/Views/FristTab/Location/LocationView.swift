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

struct LocationsView: View {
    var showLocalListPicker: Bool = true
    @State private var boxes : [MovingBox] = loadBoxes()
    @State private var items : [Items] = loadItems()
    @State private var locations: [Locations] = []
    @State private var selectedLocations: [UUID] = []
    @Binding var searchText: String
    @Binding var isScrolling: Bool
    @State private var isEditing = false
    @State private var showAlert = false
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isSearchFieldFocused: Bool
    @State private var alwaysShowNavBar: Bool = true //UserDefaults.standard.bool(forKey: "alwaysShowNavBar")
    @State private var navBarPosition: String = "Top"//UserDefaults.standard.string(forKey: "navBarPosition") ?? "Top"
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
    enum SortCriterion: String, CaseIterable {
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

    @State private var sortCriterion: SortCriterion = .createdAt
    @State private var isAscending: Bool = true
    @State private var searchSuggestionsLocations: [String] = UserDefaults.standard.stringArray(forKey: "searchSuggestionsLocations") ?? []
    @State private var suggestions: Bool = UserDefaults.standard.object(forKey: "suggestions") == nil ? true : UserDefaults.standard.bool(forKey: "suggestions")
    @State private var pinnedSearchSuggestionsLocations: [String] = UserDefaults.standard.stringArray(forKey: "pinnedSearchSuggestionsLocations") ?? []
    @State private var spotlightLocationID: UUID?
    @State private var showSpotlightLocationDetail = false
    @AppStorage(FirstTabListLimit.alwaysLoadAllKey) private var alwaysLoadAllFirstTabLists: Bool = false
    @AppStorage(FirstTabListLimit.customLimitKey) private var customFirstTabListLimit: Int = 0
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

                    return itemNameMatch || itemDescriptionMatch
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
        guard !alwaysLoadAllFirstTabLists && !hasLoadedAllLocations else { return sortedLocations }
        return Array(sortedLocations.prefix(FirstTabListLimit.limit(customLimit: customFirstTabListLimit)))
    }

    private var shouldShowLoadAllButton: Bool {
        !alwaysLoadAllFirstTabLists && !hasLoadedAllLocations && visibleLocations.count < sortedLocations.count
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                
                if showLocalListPicker && alwaysShowNavBar && navBarPosition == "Left"{
                    VStack{
                        Spacer()
                        HStack{
                                listPicker(selection: $selectedOption)
                                .rotationEffect(.degrees(90))
                                .frame(width: 150, height: 40) // bewusst so gesetzt
                                .offset(x: -70) // nach links schieben
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 5)
                    .zIndex(100)
                }
                if showLocalListPicker && alwaysShowNavBar && navBarPosition == "Right"{
                    VStack{
                        Spacer()
                        HStack{
                            Spacer()
                                listPicker(selection: $selectedOption)
                                .rotationEffect(.degrees(90))
                                .frame(width: 150, height: 40) // bewusst so gesetzt
                                .offset(x: 70) // nach rechts schieben
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 5)
                    .zIndex(100)
                }
                if showLocalListPicker && alwaysShowNavBar && navBarPosition == "Top"{
                    VStack{
                        listPicker(selection: $selectedOption)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 5)
                    .zIndex(100)
                }
                List {
                    Color.clear
                        .frame(height: 10)
                        .listRowBackground(Color.clear)
                    if showLocalListPicker && !alwaysShowNavBar{
                        listPicker(selection: $selectedOption)
                    }
                    /*if alwaysShowNavBar && navBarPosition == "Top"{
                        Color.clear
                            .frame(height: 10)
                            .listRowBackground(Color.clear)
                    }*/
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
                                                    get: { location },
                                                    set: { newLocation in
                                                        if let index = locations.firstIndex(where: { $0.id == location.id }) {
                                                            // Box in der Liste aktualisieren
                                                            locations[index] = newLocation
                                                            saveLocations(locations) // Location speichern
                                                            //print("Box updated " + String(describing: newBox))
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
                                                    get: { location },
                                                    set: { newLocation in
                                                        if let index = locations.firstIndex(where: { $0.id == location.id }) {
                                                            // Box in der Liste aktualisieren
                                                            locations[index] = newLocation
                                                            saveLocations(locations) // Location speichern
                                                            //print("Box updated " + String(describing: newBox))
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
                .padding(.top, -41)
                /*
                .if(UIDevice.current.userInterfaceIdiom == .pad) { view in
                    view.searchable(text: $searchText, placement: .navigationBarDrawer)
                }
                 */
                //.padding(.top, -33)
                .listSectionSpacing(8)
                .scrollDismissesKeyboard(.immediately)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    //if UIDevice.current.userInterfaceIdiom != .pad {
                        ToolbarItem(placement: .principal) {
                            SearchBar(text: $searchText)
                                .frame(width: 200)
                                //.frame(maxWidth: .infinity)
                        }
                    //}
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Section {
                                Picker(selection: $sortCriterion, label: Text("Sortierung")) {
                                    ForEach(SortCriterion.allCases, id: \.self) { criterion in
                                        Label(criterion.localized, systemImage: criterion.iconName)
                                            .tag(criterion)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }

                            Section {
                                Picker(selection: $isAscending, label: Text("Reihenfolge")) {
                                    Label("Aufsteigend",systemImage: "arrowshape.up.circle.fill").tag(true)
                                    Label("Absteigend", systemImage: "arrowshape.down.circle.fill").tag(false)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            
                            Section {
                                Picker("Liste", selection: $selectedOption) {
                                    Label("", systemImage: "shippingbox.fill").tag("boxes")
                                    Label("", systemImage: "square.grid.2x2.fill").tag("items")
                                    Label("", systemImage: "location.fill").tag("locations")
                                    Label("", systemImage: "photo.stack.fill").tag("images")
                                }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(.bar)
                                    )
                            }
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
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                //.rotationEffect(.degrees(isAscending ? 180 : 0))
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            hideKeyboard()
                            if isEditing {
                                selectedLocations.removeAll()
                            }
                            isEditing.toggle()
                        }) {
                            Image(systemName: isEditing ? "xmark" : "pencil")
                                .foregroundColor(selectedColor)
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
                    //alwaysShowNavBar = UserDefaults.standard.bool(forKey: "alwaysShowNavBar")
                    //navBarPosition = UserDefaults.standard.string(forKey: "navBarPosition") ?? "Top"
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
                if showLocalListPicker && alwaysShowNavBar && navBarPosition == "Bottom"{
                    VStack{
                        Spacer()
                        listPicker(selection: $selectedOption)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 5)
                    .zIndex(100)
                }
                if locations.count >= 3 {
                    //TipView(addChangeLocationColors)
                }
            }
            .background(
                NavigationLink(
                    destination: spotlightLocationDestination(),
                    isActive: $showSpotlightLocationDetail
                ) {
                    EmptyView()
                }
                .hidden()
            )
            .onReceive(NotificationCenter.default.publisher(for: .openSpotlightLocation)) { notification in
                guard let locationID = notification.object as? UUID else { return }
                locations = loadLocations()
                boxes = loadBoxes()
                items = loadItems()
                guard locations.contains(where: { $0.id == locationID }) else { return }
                spotlightLocationID = locationID
                showSpotlightLocationDetail = true
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isEditing {
                    if #available(iOS 26.0, *) {
                        HStack {
                            Button(action: {
                                showAlert = true
                            }) {
                                Image(systemName: "trash")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .padding(10)
                                    .foregroundColor(selectedLocations.isEmpty ? .gray : .red)
                            }
                            .disabled(selectedLocations.isEmpty)
                            .glassEffect()
                            
                            Spacer()
                            
                            Text("\(selectedLocations.count) / \(filteredLocations.count)")
                                .font(.footnote)
                                .foregroundStyle(.gray)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 18)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 2)
                            
                            Spacer()
                            
                            Button(action: {
                                selectAll()
                            }) {
                                Image(systemName: allSelected ? "checklist.unchecked" : "checklist.checked")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .padding(10)
                                    .foregroundColor(filteredLocations.isEmpty ? .gray : selectedColor)
                            }
                            .disabled(filteredLocations.isEmpty)
                            .glassEffect()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    } else {
                        HStack {
                            Button(action: {
                                showAlert = true
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(selectedLocations.isEmpty ? .gray : .red)
                            }
                            .disabled(selectedLocations.isEmpty)
                            
                            Spacer()
                            
                            Text("\(selectedLocations.count) / \(filteredLocations.count)")
                                .font(.footnote)
                                .foregroundStyle(.gray)
                            
                            Spacer()
                            
                            Button(action: {
                                selectAll()
                            }) {
                                Image(systemName: allSelected ? "checklist.unchecked" : "checklist.checked")
                                    .foregroundColor(filteredLocations.isEmpty ? .gray : selectedColor)
                            }
                            .disabled(filteredLocations.isEmpty)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.thinMaterial)
                    }
                }
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
        switch mode {
        case .spectrum:
            locations = assignColorsToLocations(locations)
        case .dynamic:
            locations = assignColorsToLocations2(locations)
        case .golden:
            locations = assignColorsToLocations3(locations)
        case .grayscale:
            locations = assignColorsToLocations4(locations)
        case .vivid:
            locations = assignColorsToLocations5(locations)
        case .random:
            locations = assignColorsToLocationsRandom(locations)
        }
        addChangeLocationColors.invalidate(reason: .actionPerformed)
        saveLocations(locations)
    }

    private func removeSelectedLocations() {
        let deletableIDs = Set(
            locations
                .filter { location in !boxes.contains(where: { $0.location_uuid == location.id }) }
                .map(\.id)
        )
        locations.removeAll { selectedLocations.contains($0.id) && deletableIDs.contains($0.id) }
        saveLocations(locations)
        selectedLocations.removeAll()
        allSelected = false
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
        guard let index = locations.firstIndex(where: { $0.id == locationID }) else { return nil }
        return Binding(
            get: { locations[index] },
            set: { updatedLocation in
                locations[index] = updatedLocation
                saveLocations(locations)
            }
        )
    }
}

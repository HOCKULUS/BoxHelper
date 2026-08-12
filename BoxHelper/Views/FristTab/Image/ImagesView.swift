import SwiftUI
import UIKit

struct ImagesView: View {
    var showLocalListPicker: Bool = true
    @Binding var searchText: String
    @Binding var isScrolling: Bool
    @Binding var selectedOption: String

    @State private var boxes: [MovingBox] = []
    @State private var items: [Items] = []
    @State private var locations: [Locations] = []
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @State private var alwaysShowNavBar: Bool = UserDefaults.standard.object(forKey: "alwaysShowNavBar") == nil ? true : UserDefaults.standard.bool(forKey: "alwaysShowNavBar")
    @State private var navBarPosition: String = "Top"
    @State private var pressAndHold: Bool = UserDefaultsManager.shared.loadPressAndHold()
    @State private var selectedImageOrderOption: String = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
    @State private var searchSuggestionsImages: [String] = UserDefaults.standard.stringArray(forKey: "searchSuggestionsImages") ?? []
    @State private var pinnedSearchSuggestionsImages: [String] = UserDefaults.standard.stringArray(forKey: "pinnedSearchSuggestionsImages") ?? []
    @State private var suggestions: Bool = UserDefaults.standard.object(forKey: "suggestions") == nil ? true : UserDefaults.standard.bool(forKey: "suggestions")
    @State private var numberofsearchSuggestions: Int = UserDefaults.standard.integer(forKey: "numberofsearchSuggestions") == 0 ? 5 : UserDefaults.standard.integer(forKey: "numberofsearchSuggestions")

    @State private var isEditing = false
    @State private var selectedImageIDs: Set<String> = []
    @State private var allSelected = false
    @State private var showDeleteAlert = false

    // User preference for visual density; real tile size is computed from available width.
    @AppStorage("imagesTabThumbnailSize") private var thumbnailSize: Double = 120

    enum SortCriterion: String, CaseIterable {
        case name = "Name"
        case source = "Source"
        case createdAt = "Created At"
        case updatedAt = "Updated At"

        var localized: String {
            NSLocalizedString(self.rawValue, comment: "")
        }

        var iconName: String {
            switch self {
            case .name:
                return "textformat"
            case .source:
                return "square.grid.2x2"
            case .createdAt:
                return "calendar"
            case .updatedAt:
                return "clock"
            }
        }
    }

    @State private var sortCriterion: SortCriterion = .updatedAt
    @State private var isAscending: Bool = false

    private var locationByID: [UUID: Locations] {
        Dictionary(uniqueKeysWithValues: locations.map { ($0.id, $0) })
    }

    private var boxByID: [UUID: MovingBox] {
        Dictionary(uniqueKeysWithValues: boxes.map { ($0.id, $0) })
    }

    // Build a stable image list with unique IDs (includes storage index) to avoid duplicate link behavior.
    private var allEntries: [ImageEntry] {
        let boxEntries = boxes.flatMap { box -> [ImageEntry] in
            let locationName = box.location_uuid.flatMap { locationByID[$0]?.name } ?? ""
            let tagText = (box.tags ?? []).joined(separator: " ")

            let orderedPairs: [(storageIndex: Int, path: String)]
            if selectedImageOrderOption == "new" {
                orderedPairs = Array(box.images.enumerated().reversed()).map { ($0.offset, $0.element) }
            } else {
                orderedPairs = box.images.enumerated().map { ($0.offset, $0.element) }
            }

            return orderedPairs.map { pair in
                ImageEntry(
                    id: "box-\(box.id.uuidString)-\(pair.storageIndex)-\(pair.path)",
                    imagePath: pair.path,
                    title: box.name.isEmpty ? "👻" : box.name,
                    sourceType: .box,
                    boxID: box.id,
                    itemID: nil,
                    storageIndex: pair.storageIndex,
                    createdAt: box.createdAt,
                    updatedAt: box.updatedAt,
                    searchBlob: [box.name, locationName, tagText].joined(separator: " ").lowercased()
                )
            }
        }

        let itemEntries = items.flatMap { item -> [ImageEntry] in
            let boxName = boxByID[item.box_uuid]?.name ?? ""
            let locationName = boxByID[item.box_uuid]?.location_uuid.flatMap { locationByID[$0]?.name } ?? ""
            let boxTags = boxByID[item.box_uuid]?.tags?.joined(separator: " ") ?? ""
            let itemTags = (item.tags ?? []).joined(separator: " ")

            let orderedPairs: [(storageIndex: Int, path: String)]
            if selectedImageOrderOption == "new" {
                orderedPairs = Array(item.images.enumerated().reversed()).map { ($0.offset, $0.element) }
            } else {
                orderedPairs = item.images.enumerated().map { ($0.offset, $0.element) }
            }

            return orderedPairs.map { pair in
                ImageEntry(
                    id: "item-\(item.id.uuidString)-\(pair.storageIndex)-\(pair.path)",
                    imagePath: pair.path,
                    title: item.name.isEmpty ? "👻" : item.name,
                    sourceType: .item,
                    boxID: nil,
                    itemID: item.id,
                    storageIndex: pair.storageIndex,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt,
                    searchBlob: [item.name, boxName, locationName, boxTags, itemTags].joined(separator: " ").lowercased()
                )
            }
        }

        return boxEntries + itemEntries
    }

    private var filteredEntries: [ImageEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return allEntries }
        return allEntries.filter { $0.searchBlob.contains(query) }
    }

    private var sortedEntries: [ImageEntry] {
        filteredEntries.sorted { lhs, rhs in
            switch sortCriterion {
            case .name:
                let order = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                return isAscending ? order == .orderedAscending : order == .orderedDescending
            case .source:
                return isAscending ? lhs.sourceType.sortKey < rhs.sourceType.sortKey : lhs.sourceType.sortKey > rhs.sourceType.sortKey
            case .createdAt:
                return isAscending ? lhs.createdAt < rhs.createdAt : lhs.createdAt > rhs.createdAt
            case .updatedAt:
                return isAscending ? lhs.updatedAt < rhs.updatedAt : lhs.updatedAt > rhs.updatedAt
            }
        }
    }

    private var visibleEntryIDs: [String] {
        sortedEntries.map(\.id)
    }

    private var selectedVisibleCount: Int {
        selectedImageIDs.intersection(Set(visibleEntryIDs)).count
    }

    private var hasActiveSearch: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            GeometryReader { proxy in
                let layout = gridLayout(for: proxy.size.width)
                let topPadding: CGFloat = alwaysShowNavBar && navBarPosition == "Top" ? 55 : 10

                ZStack {
                    if showLocalListPicker && alwaysShowNavBar && navBarPosition == "Left" {
                        VStack {
                            Spacer()
                            HStack {
                                listPicker(selection: $selectedOption)
                                    .rotationEffect(.degrees(90))
                                    .frame(width: 150, height: 40)
                                    .offset(x: -70)
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

                    if showLocalListPicker && alwaysShowNavBar && navBarPosition == "Right" {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                listPicker(selection: $selectedOption)
                                    .rotationEffect(.degrees(90))
                                    .frame(width: 150, height: 40)
                                    .offset(x: 70)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 5)
                        .zIndex(100)
                    }

                    if showLocalListPicker && alwaysShowNavBar && navBarPosition == "Top" {
                        VStack {
                            listPicker(selection: $selectedOption)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 5)
                        .zIndex(100)
                    }

                    ScrollView {
                        if !sortedEntries.isEmpty {
                            LazyVGrid(columns: layout.columns, spacing: layout.spacing) {
                                ForEach(sortedEntries) { entry in
                                    tile(for: entry, side: layout.tileSide)
                                }
                            }
                            .padding(.horizontal, layout.horizontalPadding)
                            .padding(.top, topPadding)
                            .padding(.bottom, 20)
                        }
                    }
                    .overlay {
                        if sortedEntries.isEmpty {
                            emptyState
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .allowsHitTesting(false)
                        }
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            SearchBar(text: $searchText)
                                .frame(width: 200)
                        }

                        ToolbarItem(placement: .topBarLeading) {
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
                                        Label("Aufsteigend", systemImage: "arrowshape.up.circle.fill").tag(true)
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
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: {
                                hideKeyboard()
                                if isEditing {
                                    selectedImageIDs.removeAll()
                                    allSelected = false
                                }
                                isEditing.toggle()
                            }) {
                                Image(systemName: isEditing ? "xmark" : "pencil")
                                    .foregroundStyle(selectedColor)
                            }
                        }
                    }
                    .onAppear {
                        UserDefaultsManager.shared.saveLastState("boxes")
                        selectedColor = UserDefaultsManager.loadAccentColor()
                        pressAndHold = UserDefaultsManager.shared.loadPressAndHold()
                        selectedImageOrderOption = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
                        pinnedSearchSuggestionsImages = UserDefaults.standard.stringArray(forKey: "pinnedSearchSuggestionsImages") ?? []
                        searchSuggestionsImages = UserDefaults.standard.stringArray(forKey: "searchSuggestionsImages") ?? []
                        suggestions = UserDefaults.standard.object(forKey: "suggestions") == nil ? true : UserDefaults.standard.bool(forKey: "suggestions")
                        numberofsearchSuggestions = UserDefaults.standard.integer(forKey: "numberofsearchSuggestions") == 0 ? 5 : UserDefaults.standard.integer(forKey: "numberofsearchSuggestions")
                        alwaysShowNavBar = UserDefaults.standard.object(forKey: "alwaysShowNavBar") == nil ? true : UserDefaults.standard.bool(forKey: "alwaysShowNavBar")
                        navBarPosition = UserDefaults.standard.string(forKey: "navBarPosition") ?? "Top"
                        reloadData()
                    }
                    .onChange(of: selectedImageIDs, initial: false) { _, _ in
                        updateAllSelectedState()
                    }
                    .onChange(of: visibleEntryIDs, initial: false) { _, newIDs in
                        selectedImageIDs = selectedImageIDs.intersection(Set(newIDs))
                        updateAllSelectedState()
                    }
                    .alert(isPresented: $showDeleteAlert) {
                        Alert(
                            title: Text(String(format: NSLocalizedString("Delete %d images?", comment: ""), selectedVisibleCount)),
                            message: Text(NSLocalizedString("Are you sure you want to delete the selected images?", comment: "")),
                            primaryButton: .destructive(Text("Löschen")) {
                                removeSelectedImages()
                                isEditing = false
                            },
                            secondaryButton: .cancel()
                        )
                    }

                    if showLocalListPicker && alwaysShowNavBar && navBarPosition == "Bottom" {
                        VStack {
                            Spacer()
                            listPicker(selection: $selectedOption)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 5)
                        .zIndex(100)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if isEditing {
                        editingBar
                    } else if suggestions {
                        imageSearchSuggestionsBar
                    }
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
                    Image(systemName: hasActiveSearch ? "magnifyingglass" : "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(hasActiveSearch ? "Keine Suchergebnisse" : "Keine Bilder vorhanden")
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
    private var editingBar: some View {
        if #available(iOS 26.0, *) {
            HStack {
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .padding(10)
                        .foregroundColor(selectedVisibleCount == 0 ? .gray : .red)
                }
                .disabled(selectedVisibleCount == 0)
                .glassEffect()

                Spacer()

                Text("\(selectedVisibleCount) / \(sortedEntries.count)")
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 18)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 2)

                Spacer()

                Button(action: toggleSelectAll) {
                    Image(systemName: allSelected ? "checklist.unchecked" : "checklist.checked")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .padding(10)
                        .foregroundColor(sortedEntries.isEmpty ? .gray : selectedColor)
                }
                .disabled(sortedEntries.isEmpty)
                .glassEffect()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        } else {
            HStack {
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(selectedVisibleCount == 0 ? .gray : .red)
                }
                .disabled(selectedVisibleCount == 0)

                Spacer()

                Text("\(selectedVisibleCount) / \(sortedEntries.count)")
                    .font(.footnote)
                    .foregroundStyle(.gray)

                Spacer()

                Button(action: toggleSelectAll) {
                    Image(systemName: allSelected ? "checklist.unchecked" : "checklist.checked")
                        .foregroundColor(sortedEntries.isEmpty ? .gray : selectedColor)
                }
                .disabled(sortedEntries.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.thinMaterial)
        }
    }

    private func reloadData() {
        boxes = loadBoxes()
        items = loadItems()
        locations = loadLocations()
    }

    // iPad gets more columns by default, iPhone fewer; tiles always stay square.
    private func gridLayout(for totalWidth: CGFloat) -> ImageGridLayout {
        let horizontalPadding: CGFloat = 12
        let spacing: CGFloat = 8
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let minColumns = isPad ? 4 : 2
        let preferredTile = CGFloat(max(100, min(220, thumbnailSize)))
        let usableWidth = max(1, totalWidth - (horizontalPadding * 2))

        var columns = max(minColumns, Int((usableWidth + spacing) / (preferredTile + spacing)))

        func tileSide(for count: Int) -> CGFloat {
            let totalSpacing = CGFloat(max(0, count - 1)) * spacing
            return (usableWidth - totalSpacing) / CGFloat(count)
        }

        var side = tileSide(for: columns)

        while side > 220 {
            columns += 1
            side = tileSide(for: columns)
        }

        while side < 100 && columns > minColumns {
            columns -= 1
            side = tileSide(for: columns)
        }

        let gridColumns = Array(repeating: GridItem(.fixed(side), spacing: spacing), count: columns)
        return ImageGridLayout(columns: gridColumns, tileSide: side, spacing: spacing, horizontalPadding: horizontalPadding)
    }

    @ViewBuilder
    private func tile(for entry: ImageEntry, side: CGFloat) -> some View {
        if isEditing {
            Button {
                toggleSelection(for: entry.id)
            } label: {
                tileContent(for: entry, side: side)
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .clipped()
            .buttonStyle(.plain)
        } else if pressAndHold {
            NavigationLink {
                destination(for: entry)
            } label: {
                tileContent(for: entry, side: side)
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .clipped()
            .buttonStyle(.plain)
            .highPriorityGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in
                        withAnimation {
                            isEditing = true
                        }
                        toggleSelection(for: entry.id)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
            )
        } else {
            NavigationLink {
                destination(for: entry)
            } label: {
                tileContent(for: entry, side: side)
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .clipped()
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func tileContent(for entry: ImageEntry, side: CGFloat) -> some View {
        let isSelected = selectedImageIDs.contains(entry.id)

        ZStack(alignment: .bottom) {
            ThumbnailTileImageView(imagePath: entry.imagePath, side: side)
            .frame(width: side, height: side)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(width: side, height: side)

            HStack(spacing: 6) {
                Image(systemName: entry.sourceType.iconName)
                Text(entry.title)
                    .lineLimit(1)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.5))
            .clipShape(Capsule())
            .padding(8)

            if isEditing {
                VStack {
                    HStack {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .resizable()
                            .frame(width: 22, height: 22)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(
                                isSelected ? Color.white : Color(UIColor.darkGray),
                                isSelected ? selectedColor : Color(UIColor.darkGray)
                            )
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selectedColor, lineWidth: 3)
            }
        }
    }

    @ViewBuilder
    private func destination(for entry: ImageEntry) -> some View {
        switch entry.sourceType {
        case .box:
            if let boxID = entry.boxID, let binding = bindingForBox(id: boxID) {
                BoxDetailView(searchText: $searchText, selectedOption: $selectedOption, box: binding)
            } else {
                InvalidLinkView()
            }
        case .item:
            if let itemID = entry.itemID, let binding = bindingForItem(id: itemID) {
                ItemsDetailView(searchText: $searchText, item: binding)
            } else {
                InvalidLinkView()
            }
        }
    }

    private func bindingForBox(id: UUID) -> Binding<MovingBox>? {
        guard let index = boxes.firstIndex(where: { $0.id == id }) else { return nil }

        return Binding(
            get: { boxes[index] },
            set: { newValue in
                boxes[index] = newValue
                saveBoxes(boxes)
            }
        )
    }

    private func bindingForItem(id: UUID) -> Binding<Items>? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }

        return Binding(
            get: { items[index] },
            set: { newValue in
                items[index] = newValue
                saveItems(items)
            }
        )
    }

    private func toggleSelection(for id: String) {
        if selectedImageIDs.contains(id) {
            selectedImageIDs.remove(id)
        } else {
            selectedImageIDs.insert(id)
        }
    }

    private func toggleSelectAll() {
        let visible = Set(visibleEntryIDs)
        guard !visible.isEmpty else { return }

        if visible.isSubset(of: selectedImageIDs) {
            selectedImageIDs.subtract(visible)
        } else {
            selectedImageIDs.formUnion(visible)
        }

        updateAllSelectedState()
    }

    private func updateAllSelectedState() {
        let visible = Set(visibleEntryIDs)
        allSelected = !visible.isEmpty && visible.isSubset(of: selectedImageIDs)
    }

    private var allSuggestionSourceData: [String] {
        boxes.map(\.name) + boxes.flatMap { $0.tags ?? [] } + items.map(\.name) + locations.map(\.name)
    }

    private var filteredPinnedSuggestions: [(suggestion: String, count: Int)] {
        groupedSuggestions(from: pinnedSearchSuggestionsImages)
            .filter { suggestion in
                suggestion.suggestion.lowercased() != searchText.lowercased()
                    && (searchText.isEmpty || suggestion.suggestion.lowercased().contains(searchText.lowercased()))
            }
    }

    private var filteredHistorySuggestions: [(suggestion: String, count: Int)] {
        groupedSuggestions(from: searchSuggestionsImages)
            .filter { suggestion in
                suggestion.suggestion.lowercased() != searchText.lowercased()
                    && (searchText.isEmpty || suggestion.suggestion.lowercased().contains(searchText.lowercased()))
            }
            .prefix(max(0, numberofsearchSuggestions - filteredPinnedSuggestions.count))
            .map { $0 }
    }

    private var filteredDataSuggestions: [(suggestion: String, count: Int)] {
        guard !searchText.isEmpty else { return [] }
        let filteredAllData = allSuggestionSourceData.filter { value in
            !pinnedSearchSuggestionsImages.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame })
            && !searchSuggestionsImages.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame })
        }

        return groupedSuggestions(from: filteredAllData)
            .filter { suggestion in
                suggestion.suggestion.lowercased() != searchText.lowercased()
                    && suggestion.suggestion.lowercased().contains(searchText.lowercased())
            }
            .prefix(max(0, numberofsearchSuggestions - (filteredPinnedSuggestions.count + filteredHistorySuggestions.count)))
            .map { $0 }
    }

    @ViewBuilder
    private var imageSearchSuggestionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        HStack {
                            Image(systemName: "xmark")
                                .foregroundStyle(.white)
                            Text("Close")
                                .foregroundStyle(.white)
                                .padding(.trailing, 4)
                        }
                        .padding(5)
                    }
                    .background(.red)
                    .background(.thinMaterial)
                    .cornerRadius(20)
                }

                ForEach(filteredPinnedSuggestions, id: \.suggestion) { item in
                    suggestionChip(item.suggestion, icon: "star")
                        .contextMenu {
                            Button {
                                searchSuggestionsImages.append(item.suggestion)
                                pinnedSearchSuggestionsImages.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                UserDefaults.standard.set(searchSuggestionsImages, forKey: "searchSuggestionsImages")
                                UserDefaults.standard.set(pinnedSearchSuggestionsImages, forKey: "pinnedSearchSuggestionsImages")
                            } label: {
                                Label("unfavorite", systemImage: "star.slash")
                            }
                            Button(role: .destructive) {
                                pinnedSearchSuggestionsImages.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                UserDefaults.standard.set(pinnedSearchSuggestionsImages, forKey: "pinnedSearchSuggestionsImages")
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }

                ForEach(filteredHistorySuggestions, id: \.suggestion) { item in
                    suggestionChip(item.suggestion, icon: "clock")
                        .contextMenu {
                            Button {
                                pinnedSearchSuggestionsImages.append(item.suggestion)
                                searchSuggestionsImages.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                UserDefaults.standard.set(searchSuggestionsImages, forKey: "searchSuggestionsImages")
                                UserDefaults.standard.set(pinnedSearchSuggestionsImages, forKey: "pinnedSearchSuggestionsImages")
                            } label: {
                                Label("favorite", systemImage: "star")
                            }
                            Button(role: .destructive) {
                                searchSuggestionsImages.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                UserDefaults.standard.set(searchSuggestionsImages, forKey: "searchSuggestionsImages")
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }

                ForEach(filteredDataSuggestions, id: \.suggestion) { item in
                    suggestionChip(item.suggestion, icon: "magnifyingglass")
                        .contextMenu {
                            Button {
                                pinnedSearchSuggestionsImages.append(item.suggestion)
                                searchSuggestionsImages.removeAll { $0.lowercased() == item.suggestion.lowercased() }
                                UserDefaults.standard.set(searchSuggestionsImages, forKey: "searchSuggestionsImages")
                                UserDefaults.standard.set(pinnedSearchSuggestionsImages, forKey: "pinnedSearchSuggestionsImages")
                            } label: {
                                Label("favorite", systemImage: "star")
                            }
                        }
                }
            }
            .padding(.horizontal, 20)
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
    }

    private func groupedSuggestions(from values: [String]) -> [(suggestion: String, count: Int)] {
        Dictionary(grouping: values, by: { $0.lowercased() })
            .map { (key, values) in (suggestion: key, count: values.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.suggestion.localizedCompare($1.suggestion) == .orderedAscending
                } else {
                    return $0.count > $1.count
                }
            }
    }

    private func suggestionChip(_ suggestion: String, icon: String) -> some View {
        Button {
            searchText = suggestion
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(self.colorScheme == .dark ? .white : .black)
                Text(suggestion)
                    .foregroundColor(self.colorScheme == .dark ? .white : .black)
                    .padding(.trailing, 4)
            }
            .padding(5)
            .background(.thinMaterial)
            .cornerRadius(20)
        }
        .padding(.vertical, 2)
    }

    // Delete by storage index to avoid removing wrong duplicates.
    private func removeSelectedImages() {
        let selected = allEntries.filter { selectedImageIDs.contains($0.id) }
        guard !selected.isEmpty else { return }

        var updatedBoxes = boxes
        var updatedItems = items
        var removedPaths: [String] = []

        var selectedBoxIndices: [UUID: [Int]] = [:]
        var selectedItemIndices: [UUID: [Int]] = [:]

        for entry in selected {
            switch entry.sourceType {
            case .box:
                if let boxID = entry.boxID {
                    selectedBoxIndices[boxID, default: []].append(entry.storageIndex)
                }
            case .item:
                if let itemID = entry.itemID {
                    selectedItemIndices[itemID, default: []].append(entry.storageIndex)
                }
            }
        }

        for (boxID, indexes) in selectedBoxIndices {
            guard let boxIndex = updatedBoxes.firstIndex(where: { $0.id == boxID }) else { continue }
            for imageIndex in Set(indexes).sorted(by: >) {
                guard updatedBoxes[boxIndex].images.indices.contains(imageIndex) else { continue }
                removedPaths.append(updatedBoxes[boxIndex].images[imageIndex])
                updatedBoxes[boxIndex].images.remove(at: imageIndex)
            }
        }

        for (itemID, indexes) in selectedItemIndices {
            guard let itemIndex = updatedItems.firstIndex(where: { $0.id == itemID }) else { continue }
            for imageIndex in Set(indexes).sorted(by: >) {
                guard updatedItems[itemIndex].images.indices.contains(imageIndex) else { continue }
                removedPaths.append(updatedItems[itemIndex].images[imageIndex])
                updatedItems[itemIndex].images.remove(at: imageIndex)
            }
        }

        boxes = updatedBoxes
        items = updatedItems
        saveBoxes(updatedBoxes)
        saveItems(updatedItems)

        let stillUsedPaths = Set(
            updatedBoxes.flatMap(\.images)
            + updatedItems.flatMap(\.images)
            + locations.compactMap { $0.image.isEmpty ? nil : $0.image }
        )

        for path in Set(removedPaths) where !stillUsedPaths.contains(path) {
            UserDefaultsManager.shared.deleteImage(named: path)
            ImagesThumbnailLoader.shared.removeCachedThumbnails(for: path)
        }

        selectedImageIDs.removeAll()
        allSelected = false
    }
}

private struct ThumbnailTileImageView: View {
    let imagePath: String
    let side: CGFloat
    private let maxPixelSize: CGFloat
    private let cacheKey: String

    @State private var image: UIImage?

    init(imagePath: String, side: CGFloat) {
        self.imagePath = imagePath
        self.side = side
        maxPixelSize = side * UIScreen.main.scale

        let pixelSide = Int(maxPixelSize.rounded(.up))
        cacheKey = "\(imagePath)#\(pixelSide)"
        _image = State(initialValue: ImagesThumbnailMemoryCache.shared.image(for: cacheKey))
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemFill))
            }
        }
        .task(id: cacheKey) {
            if image == nil {
                image = ImagesThumbnailMemoryCache.shared.image(for: cacheKey)
            }
            guard image == nil else { return }
            image = await ImagesThumbnailLoader.shared.loadThumbnail(
                path: imagePath,
                maxPixelSize: maxPixelSize,
                cacheKey: cacheKey
            )
        }
    }
}

@MainActor
private final class ImagesThumbnailLoader {
    static let shared = ImagesThumbnailLoader()

    private var runningTasks: [String: Task<UIImage?, Never>] = [:]

    func loadThumbnail(path: String, maxPixelSize: CGFloat, cacheKey: String) async -> UIImage? {
        if let cachedImage = ImagesThumbnailMemoryCache.shared.image(for: cacheKey) {
            return cachedImage
        }

        if let runningTask = runningTasks[cacheKey] {
            return await runningTask.value
        }

        let task = Task<UIImage?, Never>(priority: .utility) {
            UserDefaultsManager().loadThumbnail(from: path, maxPixelSize: maxPixelSize)
        }

        runningTasks[cacheKey] = task
        let image = await task.value
        runningTasks[cacheKey] = nil

        if let image {
            ImagesThumbnailMemoryCache.shared.insert(image, for: cacheKey)
        }

        return image
    }

    func removeCachedThumbnails(for path: String) {
        for key in runningTasks.keys.filter({ $0.hasPrefix("\(path)#") }) {
            runningTasks[key]?.cancel()
            runningTasks[key] = nil
        }
        ImagesThumbnailMemoryCache.shared.removeCachedThumbnails(for: path)
    }
}

private final class ImagesThumbnailMemoryCache: @unchecked Sendable {
    static let shared = ImagesThumbnailMemoryCache()

    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var cachedKeys: Set<String> = []

    private init() {
        cache.countLimit = 1200
    }

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: UIImage, for key: String) {
        lock.lock()
        cachedKeys.insert(key)
        lock.unlock()
        cache.setObject(image, forKey: key as NSString)
    }

    func removeCachedThumbnails(for path: String) {
        let prefix = "\(path)#"

        lock.lock()
        let matchingKeys = cachedKeys.filter { $0.hasPrefix(prefix) }
        matchingKeys.forEach { cachedKeys.remove($0) }
        lock.unlock()

        for key in matchingKeys {
            cache.removeObject(forKey: key as NSString)
        }
    }
}

private struct ImageGridLayout {
    let columns: [GridItem]
    let tileSide: CGFloat
    let spacing: CGFloat
    let horizontalPadding: CGFloat
}

private struct ImageEntry: Identifiable {
    enum SourceType {
        case box
        case item

        var sortKey: Int {
            switch self {
            case .box:
                return 0
            case .item:
                return 1
            }
        }

        // Keep icon selection centralized so tile labels stay simple.
        var iconName: String {
            switch self {
            case .box:
                return "shippingbox.fill"
            case .item:
                return "square.grid.2x2.fill"
            }
        }
    }

    let id: String
    let imagePath: String
    let title: String
    let sourceType: SourceType
    let boxID: UUID?
    let itemID: UUID?
    let storageIndex: Int
    let createdAt: Date
    let updatedAt: Date
    let searchBlob: String
}

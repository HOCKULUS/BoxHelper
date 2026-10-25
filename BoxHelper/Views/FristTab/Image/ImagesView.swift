import SwiftUI
import UIKit

/// Galerieinhalt; Navigation und Tabpicker stellt der gemeinsame Listentab bereit.
struct ImagesView: View {
    @Binding var searchText: String
    @Binding var isScrolling: Bool
    @Binding var selectedOption: String

    @ObservedObject private var storage = InventoryStorageState.shared
    @State private var unassignedImages: [InventoryLooseGalleryPhoto] = []
    @State private var fileScanTask: Task<Void, Never>?
    @State private var fileScanGeneration = UUID()
    @State private var lastScanReferences: Set<String>?
    @State private var lastScanMediaRevision: Int?
    @State private var isGalleryVisible = false
    @State private var boxes: [MovingBox] = []
    @State private var items: [Items] = []
    @State private var locations: [Locations] = []
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @State private var pressAndHold: Bool = UserDefaultsManager.shared.loadPressAndHold()
    @State private var selectedImageOrderOption: String = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
    @State private var searchSuggestionsImages: [String] = UserDefaults.standard.stringArray(forKey: "searchSuggestionsImages") ?? []
    @State private var pinnedSearchSuggestionsImages: [String] = UserDefaults.standard.stringArray(forKey: "pinnedSearchSuggestionsImages") ?? []
    @State private var suggestions: Bool = UserDefaults.standard.object(forKey: "suggestions") == nil ? true : UserDefaults.standard.bool(forKey: "suggestions")
    @State private var numberofsearchSuggestions: Int = UserDefaults.standard.integer(forKey: "numberofsearchSuggestions") == 0 ? 5 : UserDefaults.standard.integer(forKey: "numberofsearchSuggestions")

    @StateObject private var transfer = InventoryTransferController()
    @State private var isEditing = false
    @State private var selectedImageIDs: Set<String> = []
    @State private var allSelected = false
    @State private var showDeleteAlert = false
    @State private var imageMovePresentation: ImageMovePresentation?

    // User preference for visual density; real tile size is computed from available width.
    @AppStorage("imagesTabThumbnailSize") private var thumbnailSize: Double = 120

    // Eine gemeinsame Form hält Bild, Trefferfläche und Auswahlrahmen deckungsgleich.
    private let tileShape = RoundedRectangle(cornerRadius: 26, style: .continuous)

    enum SortCriterion: String, FirstTabSortCriterion {
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

    // Sortierkriterium und Richtung pro Liste optional auch über App-Neustarts hinweg merken.
    @RememberedListSorting("imagesListSortCriterion") private var sortCriterion: SortCriterion = .updatedAt
    @RememberedListSorting("imagesListSortAscending") private var isAscending: Bool = false

    private var locationByID: [UUID: Locations] {
        Dictionary(uniqueKeysWithValues: locations.map { ($0.id, $0) })
    }

    private var boxByID: [UUID: MovingBox] {
        Dictionary(uniqueKeysWithValues: boxes.map { ($0.id, $0) })
    }

    // Build a stable image list with unique IDs (includes storage index) to avoid duplicate link behavior.
    private var allEntries: [ImageEntry] {
        // Zuordnungen einmal pro Auswertung aufbauen statt pro Bild erneut zu durchsuchen.
        let knownLocations = locationByID
        let knownBoxes = boxByID
        let boxEntries = boxes.flatMap { box -> [ImageEntry] in
            let locationName = box.location_uuid.flatMap { knownLocations[$0]?.name } ?? ""
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
            let ownerBox = item.box_uuid.flatMap { knownBoxes[$0] }
            let boxName = ownerBox?.name ?? ""
            let locationName = ownerBox?.location_uuid.flatMap { knownLocations[$0]?.name } ?? ""
            let boxTags = ownerBox?.tags?.joined(separator: " ") ?? ""
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

        let looseEntries = unassignedImages.enumerated().map { index, photo in
            let url = photo.url
            return ImageEntry(id: "unassigned-\(url.lastPathComponent)", imagePath: url.lastPathComponent,
                       title: url.deletingPathExtension().lastPathComponent, sourceType: .unassigned,
                       boxID: nil, itemID: nil, storageIndex: index,
                       createdAt: photo.createdAt, updatedAt: photo.updatedAt,
                       searchBlob: url.lastPathComponent.lowercased())
        }
        return boxEntries + itemEntries + looseEntries
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

    private func shareSelection() {
        let selected = allEntries.filter { selectedImageIDs.contains($0.id) }
        // Gemeinsam verwendete Dateien erscheinen im ZIP nur einmal.
        var names = Set<String>()
        let images = selected.filter { names.insert($0.imagePath).inserted }.map {
            TransferImage(filename: $0.imagePath, title: $0.title)
        }
        transfer.export(InventoryTransferBuilder.images(images))
    }

    var body: some View {
        Group {
            GeometryReader { proxy in
                let layout = gridLayout(for: proxy.size.width)
                let entries = sortedEntries

                ZStack {

                    ScrollView {
                        if !entries.isEmpty {
                            LazyVGrid(columns: layout.columns, spacing: layout.spacing) {
                                ForEach(entries) { entry in
                                    tile(for: entry, side: layout.tileSide)
                                }
                            }
                            .padding(.horizontal, layout.horizontalPadding)
                            .padding(.bottom, 20)
                        }
                    }
                    .overlay {
                        if entries.isEmpty {
                            emptyState
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .allowsHitTesting(false)
                        }
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .navigationBarTitleDisplayMode(.inline)
                .toolbar(isEditing ? .hidden : .visible, for: .tabBar)
                .preference(key: FirstTabSelectionActiveKey.self, value: isEditing)
                .modifier(FirstTabSelectionMode(isEditing: $isEditing))
                .modifier(FirstTabSelectionBarBackground(isEditing: isEditing))
                .modifier(InventoryTransferPresentation(controller: transfer, selectedOption: $selectedOption))
                .onReceive(NotificationCenter.default.publisher(for: .inventoryDidChange)) { _ in
                    // Unsichtbare Galerien starten keine zusätzlichen Datei-Scans.
                    guard isGalleryVisible else { return }
                    reloadData()
                    selectedImageIDs.formIntersection(Set(allEntries.map(\.id)))
                    updateAllSelectedState()
                }
                .onChange(of: storage.mediaRevision) { _, _ in
                    guard isGalleryVisible else { return }
                    reloadData()
                }
                .onReceive(NotificationCenter.default.publisher(for: .inventoryTransferCompleted)) { _ in
                    reloadData(forceFileScan: true)
                    selectedImageIDs.removeAll(); allSelected = false
                    isEditing = false
                }
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            SearchBar(text: $searchText)
                                .frame(width: 200)
                        }

                    FirstTabToolbar(isEditing: $isEditing, transfer: transfer,
                        count: selectedVisibleCount, total: sortedEntries.count,
                        selectedColor: selectedColor,
                        allowImport: false,
                        canMove: true,
                        move: { presentMoveImages() },
                        share: shareSelection,
                        delete: { showDeleteAlert = true },
                        selectAll: { toggleSelectAll() },
                        finish: { selectedImageIDs.removeAll(); allSelected = false }) {

                                FirstTabSortOptions(criterion: $sortCriterion, ascending: $isAscending, list: $selectedOption)

                    }
                    }
                    .onAppear {
                        isGalleryVisible = true
                        UserDefaultsManager.shared.saveLastState("boxes")
                        selectedColor = UserDefaultsManager.loadAccentColor()
                        pressAndHold = UserDefaultsManager.shared.loadPressAndHold()
                        selectedImageOrderOption = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
                        pinnedSearchSuggestionsImages = UserDefaults.standard.stringArray(forKey: "pinnedSearchSuggestionsImages") ?? []
                        searchSuggestionsImages = UserDefaults.standard.stringArray(forKey: "searchSuggestionsImages") ?? []
                        suggestions = UserDefaults.standard.object(forKey: "suggestions") == nil ? true : UserDefaults.standard.bool(forKey: "suggestions")
                        numberofsearchSuggestions = UserDefaults.standard.integer(forKey: "numberofsearchSuggestions") == 0 ? 5 : UserDefaults.standard.integer(forKey: "numberofsearchSuggestions")
                        reloadData(forceFileScan: true)
                    }
                    .onDisappear {
                        isGalleryVisible = false
                        fileScanTask?.cancel()
                        fileScanTask = nil
                    }
                    .onChange(of: selectedImageIDs, initial: false) { _, _ in
                        updateAllSelectedState()
                    }
                    .onChange(of: visibleEntryIDs, initial: false) { _, newIDs in
                        selectedImageIDs = selectedImageIDs.intersection(Set(newIDs))
                        updateAllSelectedState()
                    }
                    // Auswahl und Präsentation gemeinsam übergeben, damit das Sheet keinen leeren alten Zustand erhält.
                    .sheet(item: $imageMovePresentation, onDismiss: { reloadData(forceFileScan: true) }) { presentation in
                        MoveImagesSheetView(selection: presentation.selection, selectedNamesText: presentation.names) { target in
                            try moveSelectedImages(presentation.selection, to: target)
                        }
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
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !isEditing && suggestions {
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



    private func reloadData(forceFileScan: Bool = false) {
        let inventory = storage.readSnapshot()
        if boxes != inventory.boxes { boxes = inventory.boxes }
        if items != inventory.items { items = inventory.items }
        if locations != inventory.locations { locations = inventory.locations }
        let references = InventoryImageGalleryFiles.referencedNames(in: inventory)
        let mediaRevision = storage.mediaRevision
        // Ein umbenanntes Item braucht keinen Dateiscan. Unveränderte Thumbnail-Caches
        // bleiben erhalten; der gemeinsame Loader prüft nur tatsächlich neue Dateiversionen.
        guard forceFileScan || references != lastScanReferences || mediaRevision != lastScanMediaRevision else { return }
        lastScanReferences = references
        lastScanMediaRevision = mediaRevision
        fileScanTask?.cancel()
        let generation = UUID()
        fileScanGeneration = generation
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileScanTask = Task {
            do {
                let files = try await InventoryImageGalleryFiles.scanInBackground(in: directory, referencedNames: references)
                guard !Task.isCancelled, fileScanGeneration == generation else { return }
                if unassignedImages != files { unassignedImages = files }
                selectedImageIDs.formIntersection(Set(allEntries.map(\.id)))
                updateAllSelectedState()
            } catch {
                guard !Task.isCancelled, fileScanGeneration == generation else { return }
                // Der letzte erfolgreiche Bestand bleibt bei einem Lesefehler sichtbar.
                lastScanReferences = nil
                InventoryStorageState.shared.report(error)
            }
        }
    }

    // Die verfügbare Breite bestimmt die Bildgröße; auf allen Geräten bleiben es 2 bis 6 Spalten.
    private func gridLayout(for totalWidth: CGFloat) -> ImageGridLayout {
        let horizontalPadding: CGFloat = 12
        let spacing: CGFloat = 8
        let minColumns = 2
        let maxColumns = 6
        let preferredTile = CGFloat(max(100, min(220, thumbnailSize)))
        let usableWidth = max(1, totalWidth - (horizontalPadding * 2))

        var columns = min(maxColumns, max(minColumns, Int((usableWidth + spacing) / (preferredTile + spacing))))

        func tileSide(for count: Int) -> CGFloat {
            let totalSpacing = CGFloat(max(0, count - 1)) * spacing
            return (usableWidth - totalSpacing) / CGFloat(count)
        }

        var side = tileSide(for: columns)

        // Die Spaltengrenzen haben Vorrang vor der bevorzugten Thumbnail-Größe.
        while side > 220 && columns < maxColumns {
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
            .contentShape(tileShape)
            .clipped()
            .buttonStyle(.plain)
        } else if pressAndHold {
            NavigationLink {
                destination(for: entry)
            } label: {
                tileContent(for: entry, side: side)
            }
            .frame(width: side, height: side)
            .contentShape(tileShape)
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
            .contentShape(tileShape)
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
        .clipShape(tileShape)
        .contentShape(tileShape)
        .overlay {
            if isSelected {
                tileShape
                    .strokeBorder(selectedColor, lineWidth: 3)
            }
        }
    }

    @ViewBuilder
    private func destination(for entry: ImageEntry) -> some View {
        switch entry.sourceType {
        case .unassigned:
            GalleryOriginalImageView(imagePath: entry.imagePath)
                .navigationTitle(entry.title)
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
        guard let box = boxes.first(where: { $0.id == id }) else { return nil }

        return Binding(
            // Cloud-Imports können Listen während der geöffneten Detailansicht neu sortieren.
            get: { boxes.first(where: { $0.id == id }) ?? box },
            set: { newValue in
                // Nur die gewählte UUID im frisch gelesenen Bestand ändern, keine alte Liste ersetzen.
                if let updated = InventoryMutation.box(id, change: { $0 = newValue }) {
                    boxes = updated
                }
            }
        )
    }

    private func bindingForItem(id: UUID) -> Binding<Items>? {
        guard let item = items.first(where: { $0.id == id }) else { return nil }

        return Binding(
            get: { items.first(where: { $0.id == id }) ?? item },
            set: { newValue in
                if let updated = InventoryMutation.item(id, change: { $0 = newValue }) {
                    items = updated
                }
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

    private func presentMoveImages() {
        let selected = sortedEntries.filter { selectedImageIDs.contains($0.id) }
        let selection: [ImageMoveSelection] = selected.compactMap { entry in
            let source: ImageMoveTarget
            switch entry.sourceType {
            case .unassigned: source = .unassigned
            case .box:
                guard let id = entry.boxID else { return nil }
                source = .box(id)
            case .item:
                guard let id = entry.itemID else { return nil }
                source = .item(id)
            }
            return ImageMoveSelection(source: source, storageIndex: entry.storageIndex, filename: entry.imagePath)
        }
        guard !selection.isEmpty else { return }
        let names = Array(Set(selected.map(\.title))).sorted().joined(separator: ", ")
        imageMovePresentation = ImageMovePresentation(selection: selection, names: names)
    }

    private func moveSelectedImages(_ selection: [ImageMoveSelection], to target: ImageMoveTarget) throws {
        // Aktuellen Bestand laden und die beim Öffnen erfassten Zuordnungen vor dem Speichern prüfen.
        let snapshot = try InventoryPersistence.snapshot()
        var updatedBoxes = snapshot.boxes
        var updatedItems = snapshot.items
        try ImageMove.apply(selection, to: target, boxes: &updatedBoxes, items: &updatedItems,
                            unassigned: buildImageInventoryReport().unassignedImages.map(\.lastPathComponent))
        // Quellen und Ziel des Bildes ändern sich in einer gemeinsamen Transaktion.
        try InventoryPersistence.applyInventoryChanges(from: snapshot,
            to: InventorySnapshot(boxes: updatedBoxes, items: updatedItems, locations: snapshot.locations))
        boxes = updatedBoxes
        items = updatedItems
        selectedImageIDs.removeAll()
        allSelected = false
        isEditing = false
        imageMovePresentation = nil
    }

    // Die Position und der Dateiname müssen weiterhin zur ursprünglichen Auswahl gehören.
    private func removeSelectedImages() {
        let selected = allEntries.filter { selectedImageIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        do {
            let snapshot = try InventoryPersistence.snapshot()
            var updatedBoxes = snapshot.boxes
            var updatedItems = snapshot.items
            var removedPaths: [String] = []
            var selectedBoxIndices: [UUID: [Int]] = [:]
            var selectedItemIndices: [UUID: [Int]] = [:]
            for entry in selected {
                switch entry.sourceType {
                case .unassigned: removedPaths.append(entry.imagePath)
                case .box:
                    guard let id = entry.boxID, let owner = updatedBoxes.first(where: { $0.id == id }),
                          owner.images.indices.contains(entry.storageIndex), owner.images[entry.storageIndex] == entry.imagePath else {
                        throw ImageMoveError.changedSelection
                    }
                    selectedBoxIndices[id, default: []].append(entry.storageIndex)
                case .item:
                    guard let id = entry.itemID, let owner = updatedItems.first(where: { $0.id == id }),
                          owner.images.indices.contains(entry.storageIndex), owner.images[entry.storageIndex] == entry.imagePath else {
                        throw ImageMoveError.changedSelection
                    }
                    selectedItemIndices[id, default: []].append(entry.storageIndex)
                }
            }
            for (id, indices) in selectedBoxIndices {
                guard let index = updatedBoxes.firstIndex(where: { $0.id == id }) else { continue }
                for imageIndex in Set(indices).sorted(by: >) {
                    removedPaths.append(updatedBoxes[index].images.remove(at: imageIndex))
                }
            }
            for (id, indices) in selectedItemIndices {
                guard let index = updatedItems.firstIndex(where: { $0.id == id }) else { continue }
                for imageIndex in Set(indices).sorted(by: >) {
                    removedPaths.append(updatedItems[index].images.remove(at: imageIndex))
                }
            }
            // Beide Tabellen bestätigen, bevor Dateien oder die aktive Auswahl entfernt werden.
            try InventoryPersistence.applyInventoryChanges(from: snapshot,
                to: InventorySnapshot(boxes: updatedBoxes, items: updatedItems, locations: snapshot.locations))
            // Auch neue Cloudobjekte können ein ausgewähltes Foto inzwischen mitverwenden.
            let committed = try InventoryPersistence.snapshot()
            let retainedPaths = Set(committed.boxes.flatMap(\.images) + committed.items.flatMap(\.images) + committed.locations.map(\.image))
            for path in Set(removedPaths).subtracting(retainedPaths) {
                UserDefaultsManager.shared.deleteImage(named: path)
            }
            boxes = updatedBoxes
            items = updatedItems
            reloadData(forceFileScan: true)
            selectedImageIDs.removeAll()
            allSelected = false
        } catch { InventoryStorageState.shared.report(error) }
    }

}

/// Die Galerie nutzt denselben versionierten, außerhalb des MainActors dekodierten
/// Cache wie die Listen. Ein iCloud-Statuswechsel leert keine bereits geladenen Bilder.
private struct ThumbnailTileImageView: View {
    let imagePath: String
    let side: CGFloat
    @Environment(\.displayScale) private var displayScale
    @ObservedObject private var storage = InventoryStorageState.shared
    @State private var image: UIImage?
    @State private var loadedPath: String?

    private var request: InventoryThumbnailLoader.Request {
        InventoryThumbnailLoader.Request(filename: imagePath, maxPixelSize: side * displayScale)
    }

    var body: some View {
        Group {
            if loadedPath == imagePath, let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.systemFill))
            }
        }
        .task(id: InventoryThumbnailLoader.TaskIdentity(request: request, mediaRevision: storage.mediaRevision)) {
            if loadedPath != imagePath {
                image = InventoryThumbnailLoader.shared.cachedImage(for: request)
                loadedPath = imagePath
            }
            let result = await InventoryThumbnailLoader.shared.load(request, mediaRevision: storage.mediaRevision)
            guard !Task.isCancelled else { return }
            loadedPath = imagePath
            image = result
        }
    }
}

/// Die Einzelansicht behält das Foto in Originalauflösung. Auch hier lädt und dekodiert
/// der Worker außerhalb des UI-Threads; Galerie-Vorschaubilder ersetzen kein Original.
private struct GalleryOriginalImageView: View {
    let imagePath: String
    @ObservedObject private var storage = InventoryStorageState.shared
    @State private var image: UIImage?
    @State private var loadedPath: String?
    @State private var isLoading = true

    private var request: InventoryThumbnailLoader.Request {
        InventoryThumbnailLoader.Request(filename: imagePath)
    }

    var body: some View {
        Group {
            if loadedPath == imagePath, let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else if isLoading {
                ProgressView()
            }
        }
        .task(id: InventoryThumbnailLoader.TaskIdentity(request: request, mediaRevision: storage.mediaRevision)) {
            isLoading = true
            if loadedPath != imagePath {
                image = InventoryThumbnailLoader.shared.cachedImage(for: request)
                loadedPath = imagePath
            }
            let result = await InventoryThumbnailLoader.shared.load(request, mediaRevision: storage.mediaRevision)
            guard !Task.isCancelled else { return }
            loadedPath = imagePath
            image = result
            isLoading = false
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
        case unassigned

        var sortKey: Int {
            switch self {
            case .unassigned: return 2
            case .box:
                return 0
            case .item:
                return 1
            }
        }

        // Keep icon selection centralized so tile labels stay simple.
        var iconName: String {
            switch self {
            case .unassigned: return "photo"
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

/// Die Auswahl gehört zur jeweiligen Sheet-Instanz und kann nicht vor ihrer Präsentation verloren gehen.
private struct ImageMovePresentation: Identifiable {
    let id = UUID()
    let selection: [ImageMoveSelection]
    let names: String
}

// Old version backup by Codex
// Source: Views/FristTab/Image/ImagesView.swift

/*
import SwiftUI
import UIKit

struct ImagesView: View {
    @Binding var searchText: String
    @Binding var selectedOption: String

    @State private var boxes: [MovingBox] = []
    @State private var items: [Items] = []
    @State private var locations: [Locations] = []
    @State private var loadedImages: [String: UIImage] = [:]

    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @State private var alwaysShowNavBar: Bool = UserDefaults.standard.object(forKey: "alwaysShowNavBar") == nil ? true : UserDefaults.standard.bool(forKey: "alwaysShowNavBar")
    @State private var navBarPosition: String = "Top"
    @State private var pressAndHold: Bool = UserDefaultsManager.shared.loadPressAndHold()
    @State private var selectedImageOrderOption: String = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"

    @State private var isEditing = false
    @State private var selectedImageIDs: Set<String> = []
    @State private var allSelected = false
    @State private var showDeleteAlert = false

    // Kept as preferred size target from settings, real size is calculated automatically.
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

    private var allEntries: [ImageEntry] {
        let boxEntries = boxes.flatMap { box -> [ImageEntry] in
            let orderedPaths = selectedImageOrderOption == "new" ? Array(box.images.reversed()) : box.images
            let locationName = box.location_uuid.flatMap { locationByID[$0]?.name } ?? ""
            let tagText = (box.tags ?? []).joined(separator: " ")

            return orderedPaths.map { path in
                ImageEntry(
                    id: "box-\(box.id.uuidString)-\(path)",
                    imagePath: path,
                    title: box.name.isEmpty ? "👻" : box.name,
                    sourceType: .box,
                    boxID: box.id,
                    itemID: nil,
                    createdAt: box.createdAt,
                    updatedAt: box.updatedAt,
                    searchBlob: [box.name, locationName, tagText].joined(separator: " ").lowercased()
                )
            }
        }

        let itemEntries = items.flatMap { item -> [ImageEntry] in
            let orderedPaths = selectedImageOrderOption == "new" ? Array(item.images.reversed()) : item.images
            let boxName = boxByID[item.box_uuid]?.name ?? ""
            let locationName = boxByID[item.box_uuid]?.location_uuid.flatMap { locationByID[$0]?.name } ?? ""
            let boxTags = boxByID[item.box_uuid]?.tags?.joined(separator: " ") ?? ""
            let itemTags = (item.tags ?? []).joined(separator: " ")

            return orderedPaths.map { path in
                ImageEntry(
                    id: "item-\(item.id.uuidString)-\(path)",
                    imagePath: path,
                    title: item.name.isEmpty ? "👻" : item.name,
                    sourceType: .item,
                    boxID: nil,
                    itemID: item.id,
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

    var body: some View {
        NavigationView {
            GeometryReader { proxy in
                let layout = gridLayout(for: proxy.size.width)

                ZStack {
                    if alwaysShowNavBar && navBarPosition == "Left" {
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

                    if alwaysShowNavBar && navBarPosition == "Right" {
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

                    if alwaysShowNavBar && navBarPosition == "Top" {
                        VStack {
                            listPicker(selection: $selectedOption)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 5)
                        .zIndex(100)
                    }

                    List {
                        if !alwaysShowNavBar {
                            listPicker(selection: $selectedOption)
                        }

                        if alwaysShowNavBar && navBarPosition == "Top" {
                            HStack { Spacer() }
                                .listRowBackground(Color.clear)
                        }

                        if sortedEntries.isEmpty {
                            emptyState
                                .listRowBackground(Color.clear)
                        } else {
                            Section {
                                LazyVGrid(columns: layout.columns, spacing: layout.spacing) {
                                    ForEach(sortedEntries) { entry in
                                        tile(for: entry, side: layout.tileSide)
                                    }
                                }
                                .padding(.horizontal, layout.horizontalPadding)
                                .padding(.vertical, 8)
                            }
                            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listSectionSpacing(8)
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
                        alwaysShowNavBar = UserDefaults.standard.object(forKey: "alwaysShowNavBar") == nil ? true : UserDefaults.standard.bool(forKey: "alwaysShowNavBar")
                        navBarPosition = UserDefaults.standard.string(forKey: "navBarPosition") ?? "Top"
                        reloadData()
                    }
                    .onChange(of: selectedImageIDs, initial: false) { _, _ in
                        updateAllSelectedState()
                    }
                    .onChange(of: visibleEntryIDs, initial: false) { _, newIDs in
                        // Keep selection bound to currently visible results.
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

                    if alwaysShowNavBar && navBarPosition == "Bottom" {
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
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Keine Bilder gefunden")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Füge Bilder zu Kisten oder Gegenständen hinzu")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(.vertical, 24)
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

    // Calculates a square grid that tries to keep at least 3 columns and fills available width.
    private func gridLayout(for totalWidth: CGFloat) -> ImageGridLayout {
        let horizontalPadding: CGFloat = 12
        let spacing: CGFloat = 8
        let preferredSide = CGFloat(max(100, min(200, thumbnailSize)))
        let usableWidth = max(1, totalWidth - (horizontalPadding * 2))

        var columns = max(3, Int((usableWidth + spacing) / (preferredSide + spacing)))

        func tileSide(for columnCount: Int) -> CGFloat {
            let totalSpacing = CGFloat(max(0, columnCount - 1)) * spacing
            return (usableWidth - totalSpacing) / CGFloat(columnCount)
        }

        var side = tileSide(for: columns)

        while side > 200 {
            columns += 1
            side = tileSide(for: columns)
        }

        while side < 100 && columns > 3 {
            columns -= 1
            side = tileSide(for: columns)
        }

        let gridItems = Array(repeating: GridItem(.fixed(side), spacing: spacing), count: columns)
        return ImageGridLayout(columns: gridItems, tileSide: side, spacing: spacing, horizontalPadding: horizontalPadding)
    }

    @ViewBuilder
    private func tile(for entry: ImageEntry, side: CGFloat) -> some View {
        if isEditing {
            Button {
                toggleSelection(for: entry.id)
            } label: {
                tileContent(for: entry, side: side)
            }
            .buttonStyle(.plain)
        } else if pressAndHold {
            NavigationLink {
                destination(for: entry)
            } label: {
                tileContent(for: entry, side: side)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .simultaneousGesture(
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
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func tileContent(for entry: ImageEntry, side: CGFloat) -> some View {
        let isSelected = selectedImageIDs.contains(entry.id)

        ZStack(alignment: .bottom) {
            Group {
                if let image = loadedImages[entry.imagePath] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemFill))
                        .overlay { ProgressView() }
                        .onAppear {
                            loadImage(for: entry.imagePath)
                        }
                }
            }
            .frame(width: side, height: side)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Requested: only show Box/Item name on image.
            Text(entry.title)
                .lineLimit(1)
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
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedColor, lineWidth: 3)
            }
        }
    }

    private func loadImage(for path: String) {
        if loadedImages[path] != nil { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let fileURL = documentsDirectory.appendingPathComponent(path)
            guard let image = UIImage(contentsOfFile: fileURL.path) else { return }
            DispatchQueue.main.async {
                loadedImages[path] = image
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
        let visibleSet = Set(visibleEntryIDs)
        guard !visibleSet.isEmpty else { return }

        if visibleSet.isSubset(of: selectedImageIDs) {
            selectedImageIDs.subtract(visibleSet)
        } else {
            selectedImageIDs.formUnion(visibleSet)
        }

        updateAllSelectedState()
    }

    private func updateAllSelectedState() {
        let visibleSet = Set(visibleEntryIDs)
        allSelected = !visibleSet.isEmpty && visibleSet.isSubset(of: selectedImageIDs)
    }

    // Deletes selected image references from boxes/items and removes orphaned files from disk.
    private func removeSelectedImages() {
        let selectedEntries = allEntries.filter { selectedImageIDs.contains($0.id) }
        guard !selectedEntries.isEmpty else { return }

        var updatedBoxes = boxes
        var updatedItems = items
        var removedPaths: Set<String> = []

        for entry in selectedEntries {
            switch entry.sourceType {
            case .box:
                guard let boxID = entry.boxID,
                      let index = updatedBoxes.firstIndex(where: { $0.id == boxID })
                else { continue }

                let beforeCount = updatedBoxes[index].images.count
                updatedBoxes[index].images.removeAll { $0 == entry.imagePath }
                if updatedBoxes[index].images.count < beforeCount {
                    removedPaths.insert(entry.imagePath)
                }

            case .item:
                guard let itemID = entry.itemID,
                      let index = updatedItems.firstIndex(where: { $0.id == itemID })
                else { continue }

                let beforeCount = updatedItems[index].images.count
                updatedItems[index].images.removeAll { $0 == entry.imagePath }
                if updatedItems[index].images.count < beforeCount {
                    removedPaths.insert(entry.imagePath)
                }
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

        for path in removedPaths where !stillUsedPaths.contains(path) {
            UserDefaultsManager.shared.deleteImage(named: path)
            loadedImages.removeValue(forKey: path)
        }

        selectedImageIDs.removeAll()
        allSelected = false
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
    }

    let id: String
    let imagePath: String
    let title: String
    let sourceType: SourceType
    let boxID: UUID?
    let itemID: UUID?
    let createdAt: Date
    let updatedAt: Date
    let searchBlob: String
}
*/

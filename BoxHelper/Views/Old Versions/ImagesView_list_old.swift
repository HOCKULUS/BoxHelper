// Old version backup by Codex
// Source: Views/FristTab/Image/ImagesView.swift

/*
import SwiftUI

struct ImagesView: View {
    @Binding var searchText: String
    @Binding var selectedOption: String

    @State private var boxes: [MovingBox] = []
    @State private var items: [Items] = []
    @State private var locations: [Locations] = []
    @State private var loadedImages: [String: UIImage] = [:]

    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @State private var alwaysShowNavBar: Bool = true
    @State private var navBarPosition: String = "Top"
    @State private var selectedImageOrderOption: String = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"

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

    private var tileSize: CGFloat {
        CGFloat(max(72, min(220, thumbnailSize)))
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
                    sourceType: .box,
                    title: box.name.isEmpty ? "👻" : box.name,
                    boxName: box.name,
                    locationName: locationName,
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
            let ownerBox = boxByID[item.box_uuid]
            let ownerBoxName = ownerBox?.name ?? ""
            let locationName = ownerBox?.location_uuid.flatMap { locationByID[$0]?.name } ?? ""
            let ownerBoxTags = (ownerBox?.tags ?? []).joined(separator: " ")
            let itemTags = (item.tags ?? []).joined(separator: " ")

            return orderedPaths.map { path in
                ImageEntry(
                    id: "item-\(item.id.uuidString)-\(path)",
                    imagePath: path,
                    sourceType: .item,
                    title: item.name.isEmpty ? "👻" : item.name,
                    boxName: ownerBoxName,
                    locationName: locationName,
                    boxID: nil,
                    itemID: item.id,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt,
                    searchBlob: [item.name, ownerBoxName, locationName, ownerBoxTags, itemTags].joined(separator: " ").lowercased()
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
                return isAscending ? lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending : lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedDescending
            case .source:
                let l = lhs.sourceType.sortKey
                let r = rhs.sourceType.sortKey
                return isAscending ? l < r : l > r
            case .createdAt:
                return isAscending ? lhs.createdAt < rhs.createdAt : lhs.createdAt > rhs.createdAt
            case .updatedAt:
                return isAscending ? lhs.updatedAt < rhs.updatedAt : lhs.updatedAt > rhs.updatedAt
            }
        }
    }

    var body: some View {
        NavigationView {
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
                        HStack {
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }

                    ForEach(sortedEntries) { entry in
                        Section {
                            NavigationLink {
                                destination(for: entry)
                            } label: {
                                rowContent(for: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if sortedEntries.isEmpty {
                        VStack(alignment: .center, spacing: 10) {
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
                        Text("\(sortedEntries.count)")
                            .foregroundStyle(selectedColor)
                            .font(.footnote.bold())
                    }
                }
                .onAppear {
                    selectedColor = UserDefaultsManager.loadAccentColor()
                    alwaysShowNavBar = UserDefaults.standard.object(forKey: "alwaysShowNavBar") == nil ? true : UserDefaults.standard.bool(forKey: "alwaysShowNavBar")
                    navBarPosition = UserDefaults.standard.string(forKey: "navBarPosition") ?? "Top"
                    selectedImageOrderOption = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
                    reloadData()
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
        }
    }

    private func reloadData() {
        boxes = loadBoxes()
        items = loadItems()
        locations = loadLocations()
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

    private func imageForPath(_ path: String) -> UIImage? {
        loadedImages[path]
    }

    @ViewBuilder
    private func rowContent(for entry: ImageEntry) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                Group {
                    if let image = imageForPath(entry.imagePath) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(UIColor.systemFill))
                            .overlay {
                                ProgressView()
                            }
                            .onAppear {
                                loadImage(for: entry.imagePath)
                            }
                    }
                }
                .frame(width: tileSize, height: tileSize)
                .clipped()

                HStack(spacing: 4) {
                    Image(systemName: entry.sourceType.iconName)
                        .font(.caption2)
                    Text(entry.title)
                        .lineLimit(1)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.5))
                .clipShape(Capsule())
                .padding(8)
            }
            .frame(width: tileSize, height: tileSize)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(entry.sourceType.label)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 5))

                    if !entry.boxName.isEmpty {
                        Text(entry.boxName)
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }

                    if !entry.locationName.isEmpty {
                        Text(entry.locationName)
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(locationColor(for: entry.locationName).opacity(0.85))
                            .foregroundStyle(locationTextColor(for: entry.locationName))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }

                Text(entry.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, -8)
    }

    @ViewBuilder
    private func destination(for entry: ImageEntry) -> some View {
        switch entry.sourceType {
        case .box:
            if let boxID = entry.boxID, let boxBinding = bindingForBox(id: boxID) {
                BoxDetailView(searchText: $searchText, selectedOption: $selectedOption, box: boxBinding)
            } else {
                InvalidLinkView()
            }
        case .item:
            if let itemID = entry.itemID, let itemBinding = bindingForItem(id: itemID) {
                ItemsDetailView(searchText: $searchText, item: itemBinding)
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

    private func locationColor(for locationName: String) -> Color {
        guard let location = locations.first(where: { $0.name == locationName }) else {
            return Color.black.opacity(0.2)
        }
        return stringToColor(location.color) ?? Color.black.opacity(0.2)
    }

    private func locationTextColor(for locationName: String) -> Color {
        let color = locationColor(for: locationName)
        return isColorTooDark(color: color) ? .white : .black
    }
}

private struct ImageEntry: Identifiable {
    enum SourceType {
        case box
        case item

        var iconName: String {
            switch self {
            case .box:
                return "shippingbox.fill"
            case .item:
                return "square.grid.2x2.fill"
            }
        }

        var label: String {
            switch self {
            case .box:
                return "Kiste"
            case .item:
                return "Gegenstand"
            }
        }

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
    let sourceType: SourceType
    let title: String
    let boxName: String
    let locationName: String
    let boxID: UUID?
    let itemID: UUID?
    let createdAt: Date
    let updatedAt: Date
    let searchBlob: String
}
*/

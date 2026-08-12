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

    @AppStorage("imagesTabThumbnailSize") private var thumbnailSize: Double = 120
    @State private var alwaysShowNavBar: Bool = UserDefaults.standard.object(forKey: "alwaysShowNavBar") == nil ? true : UserDefaults.standard.bool(forKey: "alwaysShowNavBar")
    @State private var navBarPosition: String = "Top"

    private var locationByID: [UUID: Locations] {
        Dictionary(uniqueKeysWithValues: locations.map { ($0.id, $0) })
    }

    private var boxByID: [UUID: MovingBox] {
        Dictionary(uniqueKeysWithValues: boxes.map { ($0.id, $0) })
    }

    private var allEntries: [ImageEntry] {
        let boxEntries = boxes.flatMap { box -> [ImageEntry] in
            let locationName = box.location_uuid.flatMap { locationByID[$0]?.name } ?? ""
            return box.images.map {
                ImageEntry(
                    id: "box-\(box.id.uuidString)-\($0)",
                    imagePath: $0,
                    title: box.name.isEmpty ? "👻" : box.name,
                    sourceType: .box,
                    boxID: box.id,
                    itemID: nil,
                    searchValues: [
                        box.name,
                        locationName,
                        (box.tags ?? []).joined(separator: " ")
                    ]
                )
            }
        }

        let itemEntries = items.flatMap { item -> [ImageEntry] in
            let boxName = boxByID[item.box_uuid]?.name ?? ""
            let locationName = boxByID[item.box_uuid]?.location_uuid.flatMap { locationByID[$0]?.name } ?? ""
            let boxTags = boxByID[item.box_uuid]?.tags?.joined(separator: " ") ?? ""
            return item.images.map {
                ImageEntry(
                    id: "item-\(item.id.uuidString)-\($0)",
                    imagePath: $0,
                    title: item.name.isEmpty ? "👻" : item.name,
                    sourceType: .item,
                    boxID: nil,
                    itemID: item.id,
                    searchValues: [
                        item.name,
                        boxName,
                        locationName,
                        boxTags,
                        (item.tags ?? []).joined(separator: " ")
                    ]
                )
            }
        }

        return boxEntries + itemEntries
    }

    private var filteredEntries: [ImageEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return allEntries }
        return allEntries.filter { entry in
            entry.searchBlob.contains(query)
        }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: tileSide, maximum: tileSide), spacing: 10)]
    }

    private var tileSide: CGFloat {
        CGFloat(max(72, thumbnailSize))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if alwaysShowNavBar && navBarPosition == "Top" {
                    listPicker(selection: $selectedOption)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                }
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(filteredEntries) { entry in
                            NavigationLink {
                                destination(for: entry)
                            } label: {
                                tile(for: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
                }
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
        .navigationTitle("Images")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                SearchBar(text: $searchText)
                    .frame(width: 200)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("\(filteredEntries.count)")
                    .foregroundStyle(selectedColor)
                    .font(.footnote.bold())
            }
        }
        .onAppear {
            UserDefaultsManager.shared.saveLastState("boxes")
            selectedColor = UserDefaultsManager.loadAccentColor()
            alwaysShowNavBar = UserDefaults.standard.object(forKey: "alwaysShowNavBar") == nil ? true : UserDefaults.standard.bool(forKey: "alwaysShowNavBar")
            navBarPosition = UserDefaults.standard.string(forKey: "navBarPosition") ?? "Top"
            reloadData()
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

    @ViewBuilder
    private func tile(for entry: ImageEntry) -> some View {
        ZStack(alignment: .bottom) {
            ZStack {
                if let image = loadedImages[entry.imagePath] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: tileSide, height: tileSide)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemFill))
                        .frame(width: tileSide, height: tileSide)
                        .overlay { ProgressView() }
                        .onAppear {
                            loadImage(for: entry.imagePath)
                        }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: entry.sourceType.iconName)
                    .font(.caption2)
                Text(entry.title)
                    .lineLimit(1)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.46))
            .clipShape(Capsule())
            .padding(8)
        }
        .frame(width: tileSide, height: tileSide)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
}

private struct ImageEntry: Identifiable {
    enum SourceType {
        case box
        case item

        var iconName: String {
            switch self {
            case .box: return "shippingbox.fill"
            case .item: return "square.grid.2x2.fill"
            }
        }
    }

    let id: String
    let imagePath: String
    let title: String
    let sourceType: SourceType
    let boxID: UUID?
    let itemID: UUID?
    let searchValues: [String]

    var searchBlob: String {
        searchValues.joined(separator: " ").lowercased()
    }
}
*/

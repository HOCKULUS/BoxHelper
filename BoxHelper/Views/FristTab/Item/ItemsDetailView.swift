//
//  ItemsDetailView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 14.04.25.
//
import SwiftUI
import UniformTypeIdentifiers

/// Der Bestätigungsdialog hält die ursprünglichen Bildreferenzen fest, damit
/// zwischenzeitlich veränderte Indizes keine anderen Fotos löschen können.
private enum ItemsDetailAlert: Identifiable {
    case deletePhoto(ImageMoveSelection)
    case deleteSelection([ImageMoveSelection])

    var id: String {
        switch self {
        case .deletePhoto: return "photo"
        case .deleteSelection: return "selection"
        }
    }
}

private struct ItemsDetailImageMovePresentation: Identifiable {
    let id = UUID()
    let selection: [ImageMoveSelection]
    let name: String
}

struct ItemsDetailView: View {
    @ObservedObject private var storage = InventoryStorageState.shared
    @Binding var searchText: String
    @Binding var item: Items
    @State private var searchSuggestionsItems: [String] = UserDefaults.standard.stringArray(forKey: "searchSuggestionsItems") ?? []
    @State private var boxes: [MovingBox] = loadBoxes()
    @State private var  locations: [Locations] = loadLocations()
    @Environment(\.colorScheme) var colorScheme
    @State private var isEditing: Bool = false
    @State private var isSelecting = false
    @State private var selectedPhotos: Set<ImageMoveSelection> = []
    @State private var imageMovePresentation: ItemsDetailImageMovePresentation?
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    
    //Bilder
    let addChangeImageOrder = changeImageOrder()
    @State private var showCameraPicker = false
    @State private var showImagePicker = false
    @State private var selectedImages: [UIImage] = []
    @State private var showDetailView = false
    @State private var loadedImages: [String: UIImage] = [:]
    @State private var arrowuturnleft_clicked = false
    @State private var pressAndHold: Bool = UserDefaultsManager.shared.loadPressAndHold()
    @State private var selectedImageOrderOption = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
    @State private var draggedImagePath: String?
    @State private var previewImage: UIImage? = nil
    @State private var activeAlert: ItemsDetailAlert?
    @State private var selectedImageURL: String?
    @State private var deepNavigation: Bool = UserDefaults.standard.object(forKey: "deepNavigation") == nil ? true : UserDefaults.standard.bool(forKey: "deepNavigation")
    @State private var showTags: Bool = UserDefaults.standard.object(forKey: "showTags") == nil ? true : UserDefaults.standard.bool(forKey: "showTags")
    @State private var hideTags: Bool = UserDefaults.standard.object(forKey: "hideTags") == nil ? true : UserDefaults.standard.bool(forKey: "hideTags")
    @State private var blockedTags: [String] = UserDefaultsManager.shared.loadBlockedTags()
    @State private var isGeneratingItemTags: Bool = false
    @State private var lastTagRefreshSignature: String = ""
    @State private var previewLoadTask: Task<Void, Never>?
    
    var associatedBox: MovingBox? {
        boxes.first(where: { $0.id == item.box_uuid})
    }
    
    var associatedLocation: Locations? {
        if let box = associatedBox {
            return locations.first(where: { $0.id == box.location_uuid })
        }
        return nil
    }

    private var itemTagsSection: some View {
        Section {
            if showTags && !hideTags {
                HStack  {
                    if let tags = item.tags, !tags.isEmpty {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundStyle(.white)
                                .scaleEffect(1.5)
                        }
                        .frame(width: 26, height: 26)
                        .background(.red)
                        .cornerRadius(5)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.top, 3)
                        .padding(.bottom, 3)
                        .onTapGesture {
                            item.tags?.removeAll()
                            arrowuturnleft_clicked = false
                        }
                        .onAppear {
                            arrowuturnleft_clicked = false
                        }
                    }
                    
                    if (item.tags?.isEmpty ?? true) && item.images.count > 0 && !arrowuturnleft_clicked {
                        HStack {
                            Image(systemName: "text.viewfinder")
                                .foregroundStyle(isColorTooDark(color: selectedColor) ? .white : .black)
                                .scaleEffect(1.6)
                        }
                        .frame(width: 26, height: 26)
                        .background(selectedColor)
                        .cornerRadius(5)
                        .font(.footnote)
                        .foregroundStyle(isColorTooDark(color: selectedColor) ? .white : .black)
                        .padding(.top, 3)
                        .padding(.bottom, 3)
                        .onTapGesture {
                            let imagesToProcess = UserDefaultsManager.shared.loadImages(from: item.images)
                            let validImages = imagesToProcess.compactMap { $0 }
                            
                            if !validImages.isEmpty {
                                arrowuturnleft_clicked = true
                                processImages(validImages) { recognizedTexts in
                                    DispatchQueue.main.async {
                                        item.tags = recognizedTexts
                                        arrowuturnleft_clicked = false
                                    }
                                }
                            }
                        }
                    }
                    
                    if arrowuturnleft_clicked && !item.images.isEmpty {
                        HStack {
                            ProgressView().id(UUID())
                        }
                        .frame(width: 26, height: 26)
                        .background(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                        .cornerRadius(5)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.top, 3)
                        .padding(.bottom, 3)
                    }
                    
                    if (item.tags?.isEmpty ?? true) && item.images.isEmpty {
                        HStack {
                            Image(systemName: "arrow.uturn.left")
                                .foregroundStyle(.clear)
                                .scaledToFit()
                        }
                        .frame(width: 26, height: 26)
                        .background(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                        .cornerRadius(5)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.top, 3)
                        .padding(.bottom, 3)
                    }
                    
                    ScrollView(.horizontal) {
                        HStack {
                            if var tags = item.tags {
                                if tags.count > 0 {
                                    ForEach(tags, id: \.self) { text in
                                        HStack {
                                            Button {
                                                if tags.firstIndex(of: text) != nil {
                                                    blockedTags = UserDefaultsManager.shared.loadBlockedTags()
                                                    tags.removeAll(where: { $0 == text })
                                                    if !blockedTags.contains(text) {
                                                        blockedTags.append(text)
                                                    }
                                                    UserDefaultsManager.shared.saveBlockedTags(blockedTags)
                                                }
                                                item.tags = tags
                                            } label: {
                                                Image(systemName: "nosign")
                                                    .scaleEffect(1.4)
                                                    .foregroundStyle(isColorTooDark(color: selectedColor) ? .white : .black)
                                                    .padding(.leading, 8)
                                            }
                                            
                                            Text(text)
                                                .padding(.trailing, 6)
                                                .padding(.leading, -2)
                                                .font(.callout)
                                                .padding(4)
                                        }
                                        .frame(height: 26)
                                        .background(selectedColor)
                                        .foregroundStyle(isColorTooDark(color: selectedColor) ? .white : .black)
                                        .cornerRadius(5)
                                        .font(.footnote)
                                        .foregroundStyle(.white)
                                    }
                                } else {
                                    ForEach(3...5, id: \.self) { _ in
                                        HStack {
                                        }
                                        .frame(width: 75, height: 26)
                                        .background(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                                        .cornerRadius(5)
                                        .font(.footnote)
                                        .foregroundStyle(.white)
                                    }
                                }
                            }
                        }
                    }
                    .cornerRadius(5)
                }
            }
        }
    }
    
    var body: some View {
        VStack {
            photoHeader
            Form {
                Section {
                    
                    HStack {
                        if !isEditing {
                            if deepNavigation && !isSelecting, let boxBinding = bindingForBox() {
                                NavigationLink {
                                    BoxDetailView(
                                        searchText: $searchText,
                                        selectedOption: .constant("boxes"),
                                        box: boxBinding
                                    )
                                } label: {
                                    HStack {
                                        Text("Box")
                                        Spacer()
                                        Text(associatedBox?.name ?? "–")
                                            .lineLimit(1)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } else {
                                Text("Box")
                                Spacer()
                                Text(associatedBox?.name ?? "–")
                                    .lineLimit(1)
                                    .foregroundColor(.secondary)
                            }
                        }
                        else {
                            Text("Box")
                            Spacer()
                            Picker("", selection: $item.box_uuid) {
                                Text("–").tag(nil as UUID?)
                                ForEach(boxes, id: \.id) { box in
                                    Text(box.name.count > 20 ? String(box.name.prefix(17)) + "..." : box.name)
                                        .tag(Optional(box.id))
                                        .lineLimit(1)
                                }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                        }
                    }
                    .frame(height: 20)
                    
                }
                Section(footer: Text("Item locations are set by their respective boxes.")) {
                    HStack {
                        if deepNavigation && !isSelecting, let locationBinding = bindingForLocation() {
                            NavigationLink {
                                LocationDetailView(
                                    searchText: $searchText,
                                    selectedOption: .constant("locations"),
                                    location: locationBinding
                                )
                            } label: {
                                HStack{
                                    Text("Location")
                                        .foregroundStyle(isColorTooDark(color: stringToColor(associatedLocation?.color ?? "") ?? Color.clear ) ? Color.white.opacity(1) : Color.black.opacity(1))
                                    Spacer()
                                    Text(associatedLocation?.name ?? "–")
                                        .lineLimit(1)
                                        .foregroundStyle(isColorTooDark(color: stringToColor(associatedLocation?.color ?? "") ?? Color.clear ) ? Color.white.opacity(1) : Color.black.opacity(1))
                                }
                            }
                        } else {
                            Text("Location")
                                .foregroundStyle(isColorTooDark(color: stringToColor(associatedLocation?.color ?? "") ?? Color.clear ) ? Color.white.opacity(1) : Color.black.opacity(1))
                            Spacer()
                            Text(associatedLocation?.name ?? "–")
                                .lineLimit(1)
                                .foregroundStyle(isColorTooDark(color: stringToColor(associatedLocation?.color ?? "") ?? Color.clear ) ? Color.white.opacity(1) : Color.black.opacity(1))
                        }
                    }
                }
                .listRowBackground(stringToColor(associatedLocation?.color ?? "") ?? Color.secondary)
                Section{
                    Button(action: {
                        item.isFragile.toggle()
                    },
                    label: {
                        HStack {
                            Image(item.isFragile ? "custom.wineglass" : "custom.wineglass.slash")
                                .foregroundStyle(!item.isFragile ? .gray : .primary)
                            Text(item.isFragile ? "Fragil" : "Nicht fragil")
                                .foregroundStyle(!item.isFragile ? .gray : .primary)
                        }
                    })
                    Button(action: {
                        item.isHeavy.toggle()
                    },
                    label: {
                        HStack {
                            Image(item.isHeavy ? "custom.figure.strengthtraining.traditional" : "custom.figure.strengthtraining.traditional.slash")
                                .foregroundStyle(!item.isHeavy ? .gray : .primary)
                            Text(item.isHeavy ? "Schwer" : "Nicht schwer")
                                .foregroundStyle(!item.isHeavy ? .gray : .primary)
                        }
                    })
                }
                itemTagsSection
                HStack {
                    Text("#\(item.id.description.prefix(6))")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .listRowBackground(Color.clear)
                
            }
            .onAppear {
                if searchText.isEmpty == false {
                    searchSuggestionsItems.append(searchText)
                    UserDefaults.standard.set(searchSuggestionsItems, forKey: "searchSuggestionsItems")
                }
                UserDefaultsManager.shared.saveLastState("boxes")
                showTags = UserDefaults.standard.object(forKey: "showTags") == nil ? true : UserDefaults.standard.bool(forKey: "showTags")
                hideTags = UserDefaults.standard.object(forKey: "hideTags") == nil ? true : UserDefaults.standard.bool(forKey: "hideTags")
                blockedTags = UserDefaultsManager.shared.loadBlockedTags()
            }
            .disabled(isSelecting)
            .listSectionSpacing(16.0)
            .navigationTitle(!isEditing ? "\(item.name.isEmpty ? "👻" : item.name)" : "")
            .navigationBarTitleDisplayMode(.inline)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if isEditing {
                    TextField("Item Name", text: $item.name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(5)
                        .padding(.top, -1)
                        .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : .white)
                        .cornerRadius(19)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(width: 150)
                }
            }
            FirstTabDetailToolbar(
                isSelecting: isSelecting,
                isEditing: isEditing,
                count: selectedPhotos.count,
                total: photoReferences.count,
                selectedColor: selectedColor,
                select: startSelecting,
                edit: startEditing,
                selectAll: selectAllPhotos,
                move: presentMovePhotos,
                delete: { activeAlert = .deleteSelection(selectedPhotoReferences) },
                finish: finishInteraction
            )
        }
        
        .background(.ultraThinMaterial)
        .background(
            Group {
                if let previewImage = previewImage {
                    let screenWidth = UIScreen.main.bounds.width
                    let screenHeight = UIScreen.main.bounds.height + 100
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: screenWidth, height: screenHeight) // Setzt das Bild auf die Größe des Bildschirms
                        .clipped()
                    //.blur(radius: 20)
                    //.brightness(colorScheme == .dark ? -0.3 : 0.3)
                        .padding(.top,-500)
                } else {
                    //Color.gray
                }
            }
        )
        .alert(item: $activeAlert) { alertType in
            self.createAlert(for: alertType)
        }
        .sheet(item: $imageMovePresentation) { presentation in
            MoveImagesSheetView(selection: presentation.selection, selectedNamesText: presentation.name) { target in
                try movePhotos(presentation.selection, to: target)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryDidChange)) { _ in
            // Kisten- und Standortnamen sowie Zuordnungen bleiben im Detail aktuell.
            let inventory = storage.readSnapshot()
            if boxes != inventory.boxes { boxes = inventory.boxes }
            if locations != inventory.locations { locations = inventory.locations }
        }
        .onChange(of: storage.mediaRevision) { _, _ in
            // Ein Asset kann nach seiner Referenz eintreffen oder denselben Namen ersetzen.
            for path in item.images { loadImage(for: 0, path: path) }
            refreshPreviewImage()
        }
        .onChange(of: item.images, initial: false) { _, newValue in
            loadedImages = loadedImages.filter { newValue.contains($0.key) }
            selectedPhotos.formIntersection(photoReferences)
            refreshPreviewImage()
            // Reordering fires multiple intermediate updates while dragging. Persist only after drop.
            guard draggedImagePath == nil else { return }
            persistCurrentItem()
            refreshItemTagsIfNeeded()
        }
        .onChange(of: selectedImageOrderOption) { _, _ in refreshPreviewImage() }
        .navigationBarBackButtonHidden(isSelecting)
        .toolbar(isSelecting || isEditing ? .hidden : .visible, for: .tabBar)
        .preference(key: FirstTabSelectionActiveKey.self, value: isSelecting || isEditing)
        .modifier(FirstTabSelectionBarBackground(isEditing: isSelecting))
    }
    // Dateiname und Speicherindex unterscheiden auch mehrfach verwendete Fotos.
    private var photoReferences: [ImageMoveSelection] {
        item.images.enumerated().map {
            ImageMoveSelection(source: .item(item.id), storageIndex: $0.offset, filename: $0.element)
        }
    }

    private var orderedPhotoReferences: [ImageMoveSelection] {
        selectedImageOrderOption == "new" ? Array(photoReferences.reversed()) : photoReferences
    }

    private var selectedPhotoReferences: [ImageMoveSelection] {
        orderedPhotoReferences.filter { selectedPhotos.contains($0) }
    }

    private var photoHeader: some View {
        HStack {
            VStack {
                Button { showImagePicker = true } label: {
                    topHeaderActionIcon("photo.fill")
                }
                .sheet(isPresented: $showImagePicker, onDismiss: applyPickedPhotos) {
                    ImagePicker(selectedImages: $selectedImages)
                        .accentColor(selectedColor)
                }
                Spacer()
                Button { showCameraPicker = true } label: {
                    topHeaderActionIcon("camera.fill")
                }
                .sheet(isPresented: $showCameraPicker, onDismiss: applyPickedPhotos) {
                    CameraPicker(images: $selectedImages)
                        .accentColor(selectedColor)
                }
            }
            .frame(height: 84)
            .allowsHitTesting(!isSelecting)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    if item.images.isEmpty {
                        ForEach(0..<3) { _ in
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                                .frame(width: 84, height: 84)
                        }
                    } else {
                        ForEach(orderedPhotoReferences, id: \.self) { reference in
                            photoCell(reference)
                        }
                    }
                }
                .popoverTip(addChangeImageOrder)
            }
            .cornerRadius(8)
        }
        .padding(8)
        .onAppear {
            pressAndHold = UserDefaultsManager.shared.loadPressAndHold()
            selectedImageOrderOption = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
            selectedColor = UserDefaultsManager.loadAccentColor()
            refreshPreviewImage()
        }
        .sheet(isPresented: $showDetailView) {
            ImageDetailView(
                imagePaths: $item.images,
                selectedImagePath: $selectedImageURL,
                showDetailView: $showDetailView,
                selectedColor: selectedColor
            ) { deletedPath in
                deleteItemPhoto(deletedPath)
            }
        }
    }

    private func photoCell(_ reference: ImageMoveSelection) -> some View {
        ItemsDetailPhotoCell(
            image: loadedImages[reference.filename],
            position: reference.storageIndex + 1,
            total: item.images.count,
            isSelecting: isSelecting,
            isSelected: selectedPhotos.contains(reference),
            isEditing: isEditing,
            pressAndHold: pressAndHold,
            selectedColor: selectedColor,
            reorderDelegate: SortedImageReorderDropDelegate(
                imagePaths: $item.images,
                draggedPath: $draggedImagePath,
                targetPath: reference.filename,
                sortOption: selectedImageOrderOption,
                onReorderCompleted: persistCurrentItem
            ),
            select: {
                if !selectedPhotos.insert(reference).inserted { selectedPhotos.remove(reference) }
            },
            open: {
                selectedImageURL = reference.filename
                showDetailView = true
            },
            edit: {
                startEditing()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            },
            delete: { activeAlert = .deletePhoto(reference) },
            drag: {
                draggedImagePath = reference.filename
                addChangeImageOrder.invalidate(reason: .actionPerformed)
                return NSItemProvider(object: reference.filename as NSString)
            }
        )
        .onAppear { loadImage(for: reference.storageIndex, path: reference.filename) }
    }

    private func applyPickedPhotos() {
        guard !selectedImages.isEmpty else { return }
        updateImages(addImages: selectedImages)
        selectedImages.removeAll()
    }

    private func startSelecting() {
        hideKeyboard()
        withAnimation(.snappy) {
            selectedPhotos.removeAll()
            isEditing = false
            isSelecting = true
        }
    }

    private func startEditing() {
        hideKeyboard()
        withAnimation(.snappy) {
            selectedPhotos.removeAll()
            isSelecting = false
            isEditing = true
        }
    }

    private func finishInteraction() {
        hideKeyboard()
        withAnimation(.snappy) {
            selectedPhotos.removeAll()
            isSelecting = false
            isEditing = false
        }
    }

    private func selectAllPhotos() {
        let references = Set(photoReferences)
        selectedPhotos = selectedPhotos == references ? [] : references
    }

    private func presentMovePhotos() {
        let selection = selectedPhotoReferences
        guard !selection.isEmpty else { return }
        imageMovePresentation = ItemsDetailImageMovePresentation(
            selection: selection,
            name: item.name.isEmpty ? "👻" : item.name
        )
    }

    private func movePhotos(_ selection: [ImageMoveSelection], to target: ImageMoveTarget) throws {
        // Quelle und Ziel gemeinsam bestätigen; ImageMove prüft vorher alle Referenzen.
        let snapshot = try InventoryPersistence.snapshot()
        var updatedBoxes = snapshot.boxes
        var updatedItems = snapshot.items
        try ImageMove.apply(selection, to: target, boxes: &updatedBoxes, items: &updatedItems)
        try InventoryPersistence.applyInventoryChanges(from: snapshot,
            to: InventorySnapshot(boxes: updatedBoxes, items: updatedItems, locations: snapshot.locations))
        boxes = updatedBoxes
        if let confirmed = updatedItems.first(where: { $0.id == item.id }) { item = confirmed }
        finishInteraction()
        imageMovePresentation = nil
    }

    private func deleteSelectedPhotos(_ selection: [ImageMoveSelection]) {
        guard !selection.isEmpty else { return }
        let ownerID = item.id
        Task { @MainActor in
            do {
                guard let original = try InventoryPersistence.selection(itemIDs: [ownerID]).items.first else {
                    throw ImageMoveError.changedSelection
                }
                // Alle Indizes vor dem Commit prüfen, auch bei doppelten Dateinamen.
                guard selection.allSatisfy({ reference in
                    reference.source == .item(ownerID)
                        && original.images.indices.contains(reference.storageIndex)
                        && original.images[reference.storageIndex] == reference.filename
                }) else { throw ImageMoveError.changedSelection }
                var updated = original
                var remaining = original.images
                for index in Set(selection.map(\.storageIndex)).sorted(by: >) {
                    remaining.remove(at: index)
                }
                updated.images = remaining
                try InventoryPersistence.applyItemChanges(from: [original], to: [updated])
                if item.id == ownerID, let confirmed = loadItems().first(where: { $0.id == ownerID }) {
                    item = confirmed
                }
                selectedPhotos.subtract(selection)
                // Gemeinsam genutzte Dateien bleiben erhalten; nur freie Fotos bereinigen.
                try await InventoryDeletion.shared.cleanUnusedPhotos(Set(selection.map(\.filename)))
            } catch {
                InventoryStorageState.shared.report(error)
            }
        }
    }

    // Uses a dark translucent plate to keep action icons readable over bright or busy images.
    private func topHeaderActionIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .frame(width: 38, height: 38)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.5 : 0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
            )
    }

    private func loadImage(for _: Int, path: String) {
        let request = InventoryThumbnailLoader.Request(filename: path)
        let mediaRevision = InventoryStorageState.shared.mediaRevision
        Task { @MainActor in
            let image = await InventoryThumbnailLoader.shared.load(request, mediaRevision: mediaRevision)
            guard !Task.isCancelled, mediaRevision == storage.mediaRevision, item.images.contains(path) else { return }
            loadedImages[path] = image
        }
    }

    /// Auch die große Hintergrundvorschau liest und dekodiert Fotos außerhalb des UI.
    /// Eine neue Auswahl bricht die alte Veröffentlichung ab, damit kein spätes Foto springt.
    private func loadPreviewImage(path: String) {
        previewLoadTask?.cancel()
        let request = InventoryThumbnailLoader.Request(filename: path)
        previewImage = InventoryThumbnailLoader.shared.cachedImage(for: request)
        let mediaRevision = InventoryStorageState.shared.mediaRevision
        previewLoadTask = Task { @MainActor in
            let image = await InventoryThumbnailLoader.shared.load(request, mediaRevision: mediaRevision)
            guard !Task.isCancelled, mediaRevision == storage.mediaRevision else { return }
            previewImage = image
        }
    }

    private func refreshPreviewImage() {
        if let path = (selectedImageOrderOption == "new" ? item.images.reversed().first : item.images.first) {
            loadPreviewImage(path: path)
        } else {
            previewLoadTask?.cancel()
            previewImage = nil
        }
    }

    private func updateImages(addImages: [UIImage] = [], removeIndices: [Int] = []) {
        let currentImages = item.images

        Task(priority: .userInitiated) {
            var updatedImageNames = currentImages

            for image in addImages {
                let fileName = "\(UUID().uuidString).jpg"
                guard let compressedImageData = image.compressImage() else { continue }
                let fileURL = await MainActor.run {
                    UserDefaultsManager.shared.saveImage(compressedImageData, withName: fileName)
                }

                if let fileURL {
                    updatedImageNames.append(fileURL.lastPathComponent)
                }
            }

            for index in removeIndices.sorted(by: >) {
                guard index < updatedImageNames.count else { continue }
                updatedImageNames.remove(at: index)
            }

            await MainActor.run {
                self.item.images = updatedImageNames
            }
        }
    }
    private func createAlert(for alert: ItemsDetailAlert) -> Alert {
        switch alert {
        case .deletePhoto(let reference):
            return Alert(
                title: Text(NSLocalizedString("Delete image?", comment: "")),
                message: Text(NSLocalizedString("Are you shure you want to delete this image?", comment: "")),
                primaryButton: .destructive(Text("Delete")) {
                    deleteItemPhoto(reference.filename, index: reference.storageIndex)
                },
                secondaryButton: .cancel()
            )
        case .deleteSelection(let selection):
            return Alert(
                title: Text(String(format: NSLocalizedString("Delete %d images?", comment: ""), selection.count)),
                message: Text(NSLocalizedString("Are you sure you want to delete the selected images?", comment: "")),
                primaryButton: .destructive(Text("Delete")) { deleteSelectedPhotos(selection) },
                secondaryButton: .cancel()
            )
        }
    }

    private func bindingForBox() -> Binding<MovingBox>? {
        guard let box = associatedBox else { return nil }
        return Binding(
            get: { boxes.first(where: { $0.id == box.id }) ?? box },
            set: { newValue in
                guard let updated = InventoryMutation.box(box.id, change: { $0 = newValue }) else { return }
                boxes = updated
            }
        )
    }

    private func deleteItemPhoto(_ filename: String, index: Int? = nil) {
        let ownerID = item.id
        Task { @MainActor in
            do {
                guard try await InventoryDeletion.shared.imageReference(filename, owner: .item(ownerID), index: index) else { return }
                if let confirmed = loadItems().first(where: { $0.id == ownerID }) { item = confirmed }
                loadedImages.removeValue(forKey: filename)
                if let path = (selectedImageOrderOption == "new" ? item.images.reversed().first : item.images.first) {
                    loadPreviewImage(path: path)
                } else { previewImage = nil }
            } catch { InventoryStorageState.shared.report(error) }
        }
    }

    private func bindingForLocation() -> Binding<Locations>? {
        guard let location = associatedLocation else { return nil }
        return Binding(
            get: { locations.first(where: { $0.id == location.id }) ?? location },
            set: { newValue in
                guard let updated = InventoryMutation.location(location.id, change: { $0 = newValue }) else { return }
                locations = updated
            }
        )
    }

    private func persistCurrentItem() {
        // Nur vorhandene Items aktualisieren; der Adapter bewahrt andere aktuelle Datensätze.
        _ = InventoryMutation.item(item.id, change: { $0 = item })
    }

    // Rebuild item tags whenever the image set changes so search stays aligned with the media.
    private func refreshItemTags(for itemID: UUID) {
        let imagePaths = item.images

        guard !imagePaths.isEmpty else {
            item.tags = []
            persistCurrentItem()
            isGeneratingItemTags = false
            lastTagRefreshSignature = ""
            return
        }

        isGeneratingItemTags = true
        generateAutomaticTagsIfEnabled(fromImagePaths: imagePaths) { generatedTags in
            guard item.id == itemID else { return }
            _ = InventoryMutation.item(itemID, change: { storedItem in
                guard storedItem.images == imagePaths, storedItem.tags != generatedTags else { return }
                storedItem.tags = generatedTags
            })
            isGeneratingItemTags = false
        }
    }

    private func refreshItemTagsIfNeeded() {
        // Tag generation only depends on the image set, not the current display order.
        let signature = item.images.sorted().joined(separator: "|")
        guard signature != lastTagRefreshSignature else { return }
        lastTagRefreshSignature = signature
        refreshItemTags(for: item.id)
    }

    private func removeTagFromCurrentItem(_ tag: String) {
        blockedTags = UserDefaultsManager.shared.loadBlockedTags()
        if !blockedTags.contains(tag) {
            blockedTags.append(tag)
            UserDefaultsManager.shared.saveBlockedTags(blockedTags)
        }
        item.tags?.removeAll(where: { $0 == tag })
        persistCurrentItem()
    }
}

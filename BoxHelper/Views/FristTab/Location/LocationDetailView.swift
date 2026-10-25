//
//  LocationDetailView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 10.01.25.
//

import SwiftUI
import UIKit

struct LocationDetailView: View {
    @ObservedObject private var storage = InventoryStorageState.shared
    @Binding var searchText: String
    @Binding var selectedOption: String
    @Binding var location: Locations
    @Environment(\.colorScheme) var colorScheme  // Zugriff auf Dark/Light Mode
    @State private var isEditing: Bool = false
    @State private var isSelecting = false
    @StateObject private var transfer = InventoryTransferController()
    @State private var color: Color = .blue
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @State private var rotationAngle: Double = 0 // State für den Rotationswinkel
    let colorPalette: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]
    @State private var searchSuggestionsLocations: [String] = UserDefaults.standard.stringArray(forKey: "searchSuggestionsLocations") ?? []
    @State private var boxes: [MovingBox] = loadBoxes()
    @State private var items: [Items] = loadItems()
    @State private var allLocations: [Locations] = loadLocations()
    @State private var deepNavigation: Bool = UserDefaults.standard.object(forKey: "deepNavigation") == nil ? true : UserDefaults.standard.bool(forKey: "deepNavigation")
    @State private var showImagePicker = false
    @State private var showCameraPicker = false
    @State private var selectedImages: [UIImage] = []
    @State private var locationPreviewImage: UIImage?
    @State private var boxPreviewImages: [UUID: UIImage] = [:]
    @State private var boxPreviewRequests: [UUID: InventoryThumbnailLoader.TaskIdentity] = [:]
    @State private var locationPreviewTask: Task<Void, Never>?
    @State private var selectedImageOrderOption: String = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
    @State private var selectedBoxes: Set<UUID> = []
    @State private var showMoveBoxesSheet = false
    @State private var showPrintBoxesSheet = false
    @State private var showAddBoxesSheet = false
    @State private var newBoxName = ""
    @State private var showDeleteBoxesConfirmation = false
    @State private var frame: CGFloat = 156

    private var locationBoxes: [MovingBox] {
        boxes.filter { $0.location_uuid == location.id }
    }

    // Drucken und Teilen verwenden dieselbe Auswahl in der sichtbaren Reihenfolge.
    private var selectedLocationBoxes: [MovingBox] {
        locationBoxes.filter { selectedBoxes.contains($0.id) }
    }

    // Bereits zugeordnete Kisten müssen nicht erneut hinzugefügt werden.
    private var availableBoxes: [MovingBox] {
        boxes.filter { $0.location_uuid != location.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            stickyHeader
                .allowsHitTesting(!isSelecting)
            List {
                if !isSelecting {
                    HStack(spacing: 12) {
                        Text("Color")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if isEditing {
                            ColorPicker("", selection: $color, supportsOpacity: false)
                                .labelsHidden()
                                .onChange(of: color, initial: false) { _, newValue in
                                    location.color = colorToString(newValue) ?? "clear"
                                }
                        } else {
                            Circle()
                                .fill(stringToColor(location.color) ?? .clear)
                                .frame(width: 28, height: 28)
                                .accessibilityHidden(true)
                        }
                    }
                    LocationAddBoxesSection(
                        newBoxName: $newBoxName,
                        hasAvailableBoxes: !availableBoxes.isEmpty,
                        selectBoxes: openAddBoxesPicker,
                        createBox: createBoxAtLocation
                    )
                }
                Section {
                    if locationBoxes.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "shippingbox")
                                .font(.system(size: 26, weight: .regular))
                                .foregroundStyle(.secondary)
                            Text("Keine Kisten an diesem Standort")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(locationBoxes) { box in
                            if isSelecting {
                                Button {
                                    toggleSelection(for: box)
                                } label: {
                                    HStack {
                                        Image(systemName: selectedBoxes.contains(box.id) ? "checkmark.circle.fill" : "circle")
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                            .foregroundColor(selectedColor)
                                        boxRowContent(box)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(selectedBoxes.contains(box.id) ? [.isSelected] : [])
                                .alignmentGuide(.listRowSeparatorLeading) { d in
                                    d[.leading]
                                }
                            } else if deepNavigation && !isEditing {
                                let row = boxRowContent(box)
                                NavigationLink(
                                    destination: BoxDetailView(
                                        searchText: $searchText,
                                        selectedOption: $selectedOption,
                                        box: binding(for: box)
                                    )
                                ) {
                                    row
                                }
                                .alignmentGuide(.listRowSeparatorLeading) { d in
                                    d[.leading]
                                }
                            } else {
                                boxRowContent(box)
                                    .alignmentGuide(.listRowSeparatorLeading) { d in
                                        d[.leading]
                                    }
                            }
                        }
                    }
                }
                HStack {
                    Spacer()
                    Text("#\(location.id.description.prefix(6))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            .listSectionSpacing(16.0)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
        }
        .background(.ultraThinMaterial)
        .background(
            Group {
                if let previewImage = locationPreviewImage {
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
        .onReceive(NotificationCenter.default.publisher(for: .inventoryDidChange)) { _ in
            // Neue Kisten und Gegenstände erscheinen auch im bereits geöffneten Standort.
            let inventory = storage.readSnapshot()
            if boxes != inventory.boxes { boxes = inventory.boxes }
            if items != inventory.items { items = inventory.items }
            if allLocations != inventory.locations { allLocations = inventory.locations }
            // Verschobene Kisten gehören nicht mehr zur Auswahl dieses Standorts.
            selectedBoxes.formIntersection(Set(locationBoxes.map(\.id)))
            preloadBoxPreviews()
        }
        .onChange(of: storage.mediaRevision) { _, _ in
            refreshLocationPreview()
            preloadBoxPreviews()
        }
        .onChange(of: location.image) { _, _ in refreshLocationPreview() }
        .onAppear {
            UserDefaultsManager.shared.saveLastState("boxes")
            color = stringToColor(location.color) ?? .clear
            selectedColor = UserDefaultsManager.loadAccentColor()
            deepNavigation = UserDefaults.standard.object(forKey: "deepNavigation") == nil ? true : UserDefaults.standard.bool(forKey: "deepNavigation")
            boxes = loadBoxes()
            items = loadItems()
            allLocations = loadLocations()
            selectedImageOrderOption = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
            refreshLocationPreview()
            preloadBoxPreviews()
            if searchText.isEmpty == false {
                searchSuggestionsLocations.append(searchText)
                UserDefaults.standard.set(searchSuggestionsLocations, forKey: "searchSuggestionsLocations")
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImages: $selectedImages, selectionLimit: 1)
                .onDisappear {
                    handleImagePickerDismiss()
                }
                .accentColor(selectedColor)
        }
        .sheet(isPresented: $showCameraPicker) {
            CameraPicker(images: $selectedImages)
                .onDisappear {
                    applyFirstSelectedImage()
                }
                .accentColor(selectedColor)
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
        .sheet(isPresented: $showPrintBoxesSheet) {
            // Derselbe QR-Druckdialog wie in der Kistenliste, inklusive Vorschau.
            BoxBatchPrintSheet(boxes: selectedLocationBoxes, locations: allLocations)
        }
        .sheet(isPresented: $showAddBoxesSheet) {
            CreateLocationBoxesSheet(
                boxes: availableBoxes,
                locations: allLocations,
                targetName: location.name,
                selection: [],
                confirmationMessage: "Die ausgewählten Kisten werden mit Übernehmen diesem Standort zugeordnet."
            ) { selectedIDs in
                addBoxesToLocation(selectedIDs)
                showAddBoxesSheet = false
            }
            .tint(selectedColor)
        }
        .alert(
            "Kisten löschen?",
            isPresented: $showDeleteBoxesConfirmation
        ) {
            Button("Löschen", role: .destructive) {
                deleteSelectedBoxes()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text(
                String.localizedStringWithFormat(
                    String(localized: "%lld ausgewählte Kisten werden dauerhaft gelöscht."),
                    selectedBoxes.count
                )
            )
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if isEditing {
                    TextField("Location Name", text: $location.name)
                        .font(.headline)
                        .multilineTextAlignment(.center) // Zentriert den Text
                        .padding(5) // Innenabstand
                        .padding(.top, -1)
                        .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : .white)
                        .cornerRadius(19) // Ecken abrunden
                        .foregroundColor(colorScheme == .dark ? .white : .black) // Textfarbe
                        .frame(width: 150)
                }
                else {
                    HStack {
                        Spacer()
                        Text(location.name.isEmpty ? "👻" : location.name)
                            .font(.headline)
                            .foregroundStyle(isColorTooDark(color: stringToColor(location.color) ?? Color.clear ) ? Color.white.opacity(1) : Color.black.opacity(1))
                        Spacer()
                    }
                    .padding(5) // Innenabstand
                    .padding(.top, -1)
                    .background(stringToColor(location.color) ?? .clear)
                    .cornerRadius(19)
                    .frame(width: 150, height: 10)
                }
            }
            FirstTabDetailToolbar(
                isSelecting: isSelecting,
                isEditing: isEditing,
                count: selectedBoxes.count,
                total: locationBoxes.count,
                selectedColor: selectedColor,
                select: startSelecting,
                edit: startEditing,
                selectAll: selectAllBoxes,
                move: { showMoveBoxesSheet = true },
                delete: { showDeleteBoxesConfirmation = true },
                finish: finishInteraction,
                canMove: !moveTargetLocations.isEmpty,
                printSelection: { showPrintBoxesSheet = true },
                share: shareSelectedBoxes,
                isSharing: transfer.isBusy
            )
        }
        .navigationBarBackButtonHidden(isSelecting)
        .toolbar(isSelecting || isEditing ? .hidden : .visible, for: .tabBar)
        .preference(key: FirstTabSelectionActiveKey.self, value: isSelecting || isEditing)
        .modifier(FirstTabSelectionBarBackground(isEditing: isSelecting))
        .modifier(InventoryTransferPresentation(controller: transfer, selectedOption: $selectedOption))
    }

    // Header stays fixed at the top while only the boxes list scrolls.
    private var stickyHeader: some View {
        VStack {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let image = locationPreviewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .onAppear {
                                frame = 156
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                            .onAppear {
                                frame = 68
                            }
                    }
                }
                .frame(height: frame)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if hasLocationImage, isEditing {
                    Button(role: .destructive) {
                        deleteLocationImage()
                    } label: {
                        Image(systemName: "trash.fill")
                            //.font(.system(size: 14, weight: .semibold))
                            .frame(width: 38, height: 38)
                            .foregroundStyle(Color(.white))
                    }
                    .tint(.red)
                    .buttonStyle(.borderedProminent)
                    // Erzwingt eine quadratische Form statt der kapselartigen Standardform.
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .padding(8)
                } else if !hasLocationImage {
                    HStack(spacing: 8) {
                        Button {
                            selectedImages.removeAll()
                            showImagePicker = true
                        } label: {
                            Image(systemName: "photo.fill")
                                //.font(.system(size: 14, weight: .semibold))
                                .frame(width: 38, height: 38)
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.primary)
                        // Erzwingt eine quadratische Form statt der kapselartigen Standardform.
                        .buttonBorderShape(.roundedRectangle(radius: 10))

                        Button {
                            selectedImages.removeAll()
                            showCameraPicker = true
                        } label: {
                            Image(systemName: "camera.fill")
                                //.font(.system(size: 14, weight: .semibold))
                                .frame(width: 38, height: 38)
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.primary)
                        // Erzwingt eine quadratische Form statt der kapselartigen Standardform.
                        .buttonBorderShape(.roundedRectangle(radius: 10))
                    }
                    .padding(8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        //.background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func openAddBoxesPicker() {
        hideKeyboard()
        boxes = loadBoxes()
        allLocations = loadLocations()
        showAddBoxesSheet = true
    }

    private func addBoxesToLocation(_ selectedIDs: Set<UUID>) {
        guard !selectedIDs.isEmpty else { return }
        // Frisch laden, damit Änderungen anderer Ansichten oder Kurzbefehle erhalten bleiben.
        var allBoxes = loadBoxes()
        for index in allBoxes.indices where selectedIDs.contains(allBoxes[index].id) {
            allBoxes[index].location_uuid = location.id
        }
        guard saveBoxes(allBoxes) else { return }
        refreshLocationBoxes(allBoxes)
    }

    private func createBoxAtLocation() {
        let name = newBoxName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var allBoxes = loadBoxes()
        allBoxes.append(MovingBox(name: name, items: [], images: [], location_uuid: location.id))
        guard saveBoxes(allBoxes) else { return }
        newBoxName = ""
        refreshLocationBoxes(allBoxes)
    }

    private func refreshLocationBoxes(_ allBoxes: [MovingBox]) {
        boxes = allBoxes
        items = loadItems()
        // Eine aktive Bearbeitung darf nur weiterhin vorhandene Standortkisten auswählen.
        selectedBoxes.formIntersection(Set(locationBoxes.map(\.id)))
        preloadBoxPreviews()
    }

    private func binding(for box: MovingBox) -> Binding<MovingBox> {
        Binding(
            get: {
                boxes.first(where: { $0.id == box.id }) ?? box
            },
            set: { newValue in
                guard let updated = InventoryMutation.box(box.id, change: { $0 = newValue }) else { return }
                boxes = updated
            }
        )
    }

    // Keep row layout close to the default item rows from BoxDetailView.
    @ViewBuilder
    private func boxRowContent(_ box: MovingBox) -> some View {
        HStack(spacing: 12) {
            Group {
                if let preview = boxPreviewImages[box.id] {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.systemFill))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(box.name.isEmpty ? "👻" : box.name)
                .lineLimit(1)
                .frame(maxHeight: 100)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundStyle(.secondary)
                    .scaleEffect(0.7)
                Text("\(itemCount(for: box))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            loadPreviewImage(for: box)
        }
    }

    private func itemCount(for box: MovingBox) -> Int {
        items.filter { $0.box_uuid == box.id }.count
    }

    private func previewPath(for box: MovingBox) -> String? {
        selectedImageOrderOption == "new" ? box.images.reversed().first : box.images.first
    }

    private func loadPreviewImage(for box: MovingBox) {
        guard let path = previewPath(for: box) else {
            boxPreviewImages.removeValue(forKey: box.id)
            boxPreviewRequests.removeValue(forKey: box.id)
            return
        }
        // Die 46-Punkt-Zeile braucht kein dekodiertes Originalfoto im Speicher.
        let request = InventoryThumbnailLoader.Request(filename: path, maxPixelSize: 46 * UIScreen.main.scale)
        let identity = InventoryThumbnailLoader.TaskIdentity(request: request, mediaRevision: storage.mediaRevision)
        guard boxPreviewRequests[box.id] != identity else { return }
        if boxPreviewRequests[box.id]?.request != request { boxPreviewImages.removeValue(forKey: box.id) }
        boxPreviewRequests[box.id] = identity
        Task { @MainActor in
            let image = await InventoryThumbnailLoader.shared.load(request, mediaRevision: identity.mediaRevision)
            guard !Task.isCancelled, boxPreviewRequests[box.id] == identity,
                  storage.mediaRevision == identity.mediaRevision else { return }
            boxPreviewImages[box.id] = image
        }
    }

    private func preloadBoxPreviews() {
        let current = locationBoxes
        let ids = Set(current.map(\.id))
        boxPreviewImages = boxPreviewImages.filter { ids.contains($0.key) }
        boxPreviewRequests = boxPreviewRequests.filter { ids.contains($0.key) }
        // Neue Zeilen laden bei onAppear. Bereits sichtbare Fotos werden nur bei einer
        // neuen Referenz oder Medienrevision geprüft, nicht bei jedem Inventarereignis.
        for box in current where boxPreviewRequests[box.id] != nil { loadPreviewImage(for: box) }
    }

    private func refreshLocationPreview() {
        locationPreviewTask?.cancel()
        guard !location.image.isEmpty else { locationPreviewImage = nil; return }
        let path = location.image
        let pixelSide = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * UIScreen.main.scale
        let request = InventoryThumbnailLoader.Request(filename: path, maxPixelSize: pixelSide)
        let mediaRevision = storage.mediaRevision
        locationPreviewTask = Task { @MainActor in
            let image = await InventoryThumbnailLoader.shared.load(request, mediaRevision: mediaRevision)
            guard !Task.isCancelled, location.image == path, storage.mediaRevision == mediaRevision else { return }
            locationPreviewImage = image
        }
    }

    private var hasLocationImage: Bool {
        location.image.isEmpty == false || locationPreviewImage != nil
    }

    private func handleImagePickerDismiss() {
        // Location only stores one image, so we always keep just the first selected image.
        applyFirstSelectedImage()
    }

    private func applyFirstSelectedImage() {
        guard let first = selectedImages.first else { return }
        selectedImages.removeAll()
        saveLocationImage(first)
    }

    private func saveLocationImage(_ image: UIImage) {
        let oldFilename = location.image
        let fileName = "\(UUID().uuidString).jpg"
        guard let compressed = image.compressImage(),
              let url = UserDefaultsManager.shared.saveImage(compressed, withName: fileName) else { return }
        location.image = url.lastPathComponent
        guard location.image == url.lastPathComponent else { return }
        locationPreviewImage = image
        if !oldFilename.isEmpty {
            // Ein Bildwechsel entfernt die alte Datei erst nach dem bestätigten
            // Binding-Save und nur, wenn kein anderes Objekt sie verwendet.
            Task {
                do { try await InventoryDeletion.shared.cleanUnusedPhotos([oldFilename]) }
                catch { InventoryStorageState.shared.report(error) }
            }
        }
    }

    private func deleteLocationImage() {
        guard !location.image.isEmpty else { return }
        let filename = location.image
        let ownerID = location.id
        Task { @MainActor in
            do {
                guard try await InventoryDeletion.shared.imageReference(filename, owner: .location(ownerID)) else { return }
                if let confirmed = loadLocations().first(where: { $0.id == ownerID }) { location = confirmed }
                locationPreviewImage = nil
            } catch { InventoryStorageState.shared.report(error) }
        }
    }

    private var moveTargetLocations: [Locations] {
        allLocations.filter { $0.id != location.id }
    }

    private var selectedBoxNamesText: String {
        let names = locationBoxes
            .filter { selectedBoxes.contains($0.id) }
            .map { $0.name.isEmpty ? "👻" : $0.name }
        return names.isEmpty ? "Keine Kisten ausgewählt." : names.joined(separator: ", ")
    }

    private func boxCount(for targetLocation: Locations) -> Int {
        boxes.filter { $0.location_uuid == targetLocation.id }.count
    }

    private func toggleSelection(for box: MovingBox) {
        if selectedBoxes.contains(box.id) {
            selectedBoxes.remove(box.id)
        } else {
            selectedBoxes.insert(box.id)
        }
    }

    private func selectAllBoxes() {
        let allIDs = Set(locationBoxes.map(\.id))
        if selectedBoxes == allIDs {
            selectedBoxes.removeAll()
        } else {
            selectedBoxes = allIDs
        }
    }

    private func startSelecting() {
        hideKeyboard()
        withAnimation(.snappy) {
            selectedBoxes.removeAll()
            isEditing = false
            isSelecting = true
        }
    }

    private func startEditing() {
        hideKeyboard()
        color = stringToColor(location.color) ?? .clear
        withAnimation(.snappy) {
            selectedBoxes.removeAll()
            isSelecting = false
            isEditing = true
        }
    }

    private func finishInteraction() {
        hideKeyboard()
        withAnimation(.snappy) {
            selectedBoxes.removeAll()
            isSelecting = false
            isEditing = false
        }
    }

    private func shareSelectedBoxes() {
        // Das Auswahlarchiv enthält Kisten, Gegenstände, Fotos und den Standort.
        let inventory = storage.readSnapshot()
        let selected = inventory.boxes.filter {
            $0.location_uuid == location.id && selectedBoxes.contains($0.id)
        }
        transfer.export(InventoryTransferBuilder.boxes(selected,
            allItems: inventory.items, allLocations: inventory.locations))
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
            showMoveBoxesSheet = false
            finishInteraction()
        } catch { InventoryStorageState.shared.report(error) }
    }

    private func deleteSelectedBoxes() {
        guard !selectedBoxes.isEmpty else { return }
        let ids = selectedBoxes
        Task { @MainActor in
            do {
                _ = try await InventoryDeletion.shared.boxes(ids)
                boxes = loadBoxes()
                items = loadItems()
                finishInteraction()
                preloadBoxPreviews()
            } catch { InventoryStorageState.shared.report(error) }
        }
    }
}

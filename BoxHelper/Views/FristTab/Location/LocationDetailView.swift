//
//  LocationDetailView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 10.01.25.
//

import SwiftUI
import UIKit

struct LocationDetailView: View {
    @Binding var searchText: String
    @Binding var selectedOption: String
    @Binding var location: Locations
    @Environment(\.colorScheme) var colorScheme  // Zugriff auf Dark/Light Mode
    @State private var isEditing: Bool = false
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
    @State private var selectedImageOrderOption: String = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
    @State private var selectedBoxes: Set<UUID> = []
    @State private var showMoveBoxesSheet = false
    @State private var showDeleteBoxesConfirmation = false
    @State private var frame: CGFloat = 156

    private var locationBoxes: [MovingBox] {
        boxes.filter { $0.location_uuid == location.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            stickyHeader
            List {
                HStack(spacing: 12) {
                    Text("Color")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    ColorPicker("", selection: $color, supportsOpacity: false)
                        .labelsHidden()
                        .onChange(of: color, initial: false) { _, newValue in
                            location.color = colorToString(newValue) ?? "clear"
                        }
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
                            if isEditing {
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
                                .alignmentGuide(.listRowSeparatorLeading) { d in
                                    d[.leading]
                                }
                            } else if deepNavigation {
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
        .onAppear {
            UserDefaultsManager.shared.saveLastState("boxes")
            color = stringToColor(location.color) ?? .clear
            selectedColor = UserDefaultsManager.loadAccentColor()
            deepNavigation = UserDefaults.standard.object(forKey: "deepNavigation") == nil ? true : UserDefaults.standard.bool(forKey: "deepNavigation")
            boxes = loadBoxes()
            items = loadItems()
            allLocations = loadLocations()
            selectedImageOrderOption = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
            locationPreviewImage = location.image.isEmpty ? nil : UserDefaultsManager.shared.loadImage(from: location.image)
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isEditing {
                if #available(iOS 26.0, *) {
                    HStack {
                        Button {
                            showDeleteBoxesConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .padding(10)
                                .foregroundColor(selectedBoxes.isEmpty ? .gray : .red)
                        }
                        .disabled(selectedBoxes.isEmpty)
                        .glassEffect()

                        Button {
                            showMoveBoxesSheet = true
                        } label: {
                            Image(systemName: "arrow.left.arrow.right")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .padding(10)
                                .foregroundColor(selectedBoxes.isEmpty ? .gray : selectedColor)
                        }
                        .disabled(selectedBoxes.isEmpty)
                        .glassEffect()

                        Spacer()

                        Text("\(selectedBoxes.count) / \(locationBoxes.count)")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 18)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 2)

                        Spacer()

                        Button {
                            clearSelectedBoxes()
                        } label: {
                            Image(systemName: "xmark.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .padding(10)
                                .foregroundColor(selectedBoxes.isEmpty ? .gray : selectedColor)
                        }
                        .disabled(true)
                        .glassEffect()
                        .opacity(0)

                        Button {
                            selectAllBoxes()
                        } label: {
                            Image(systemName: selectedBoxes.count == locationBoxes.count ? "checklist.unchecked" : "checklist.checked")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .padding(10)
                                .foregroundColor(locationBoxes.isEmpty ? .gray : selectedColor)
                        }
                        .disabled(locationBoxes.isEmpty)
                        .glassEffect()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                } else {
                    HStack {
                        Button {
                            showDeleteBoxesConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .padding(10)
                                .foregroundColor(selectedBoxes.isEmpty ? .gray : .red)
                        }
                        .disabled(selectedBoxes.isEmpty)

                        Button {
                            showMoveBoxesSheet = true
                        } label: {
                            Image(systemName: "arrow.left.arrow.right")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .padding(10)
                                .foregroundColor(selectedBoxes.isEmpty ? .gray : selectedColor)
                        }
                        .disabled(selectedBoxes.isEmpty)

                        Spacer()

                        Text("\(selectedBoxes.count) / \(locationBoxes.count)")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 18)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 2)

                        Spacer()

                        Button {
                            clearSelectedBoxes()
                        } label: {
                            Image(systemName: "")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .padding(10)
                                .foregroundColor(selectedBoxes.isEmpty ? .gray : selectedColor)
                        }
                        .disabled(true)
                        .opacity(0)

                        Button {
                            selectAllBoxes()
                        } label: {
                            Image(systemName: selectedBoxes.count == locationBoxes.count ? "checklist.unchecked" : "checklist.checked")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .padding(10)
                                .foregroundColor(locationBoxes.isEmpty ? .gray : selectedColor)
                        }
                        .disabled(locationBoxes.isEmpty)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
            }
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    hideKeyboard()
                    if isEditing { selectedBoxes.removeAll() }
                    isEditing.toggle()
                }) {
                    Image(systemName: isEditing ? "xmark" : "pencil")
                        .foregroundColor(selectedColor)
                }
            }
        }
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

    private func binding(for box: MovingBox) -> Binding<MovingBox> {
        Binding(
            get: {
                boxes.first(where: { $0.id == box.id }) ?? box
            },
            set: { newValue in
                if let index = boxes.firstIndex(where: { $0.id == box.id }) {
                    boxes[index] = newValue
                } else {
                    boxes.append(newValue)
                }
                saveBoxes(boxes)
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
        guard boxPreviewImages[box.id] == nil,
              let path = previewPath(for: box) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let image = UserDefaultsManager.shared.loadImage(from: path)
            DispatchQueue.main.async {
                if let image {
                    boxPreviewImages[box.id] = image
                }
            }
        }
    }

    private func preloadBoxPreviews() {
        boxPreviewImages.removeAll()
        for box in locationBoxes {
            loadPreviewImage(for: box)
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
        if !location.image.isEmpty {
            UserDefaultsManager.shared.deleteImage(named: location.image)
        }
        let fileName = "\(UUID().uuidString).jpg"
        guard let compressed = image.compressImage(),
              let url = UserDefaultsManager.shared.saveImage(compressed, withName: fileName) else { return }
        location.image = url.lastPathComponent
        locationPreviewImage = image
    }

    private func deleteLocationImage() {
        guard !location.image.isEmpty else { return }
        UserDefaultsManager.shared.deleteImage(named: location.image)
        location.image = ""
        locationPreviewImage = nil
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

    private func clearSelectedBoxes() {
        selectedBoxes.removeAll()
    }

    private func moveSelectedBoxes(to targetLocationID: UUID) {
        guard !selectedBoxes.isEmpty else { return }
        for index in boxes.indices where selectedBoxes.contains(boxes[index].id) {
            boxes[index].location_uuid = targetLocationID
        }
        saveBoxes(boxes)
        selectedBoxes.removeAll()
        showMoveBoxesSheet = false
        isEditing = false
    }

    private func deleteSelectedBoxes() {
        guard !selectedBoxes.isEmpty else { return }
        let selectedIDs = selectedBoxes

        // Löscht Bilddateien der betroffenen Kisten aus dem Dateisystem.
        for box in boxes where selectedIDs.contains(box.id) {
            for imagePath in box.images {
                UserDefaultsManager.shared.deleteImage(named: imagePath)
            }
        }

        // Löscht Gegenstände der gelöschten Kisten inkl. deren Bilddateien.
        let itemImagesToDelete = items
            .filter { selectedIDs.contains($0.box_uuid) }
            .flatMap { $0.images }
        for imagePath in itemImagesToDelete {
            UserDefaultsManager.shared.deleteImage(named: imagePath)
        }

        boxes.removeAll { selectedIDs.contains($0.id) }
        items.removeAll { selectedIDs.contains($0.box_uuid) }
        saveBoxes(boxes)
        saveItems(items)
        selectedBoxes.removeAll()
        isEditing = false
        preloadBoxPreviews()
    }
}

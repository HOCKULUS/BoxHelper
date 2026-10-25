//
//  BoxDetailView.swift
//  ios-app-test
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum AlertType: Identifiable {
    case deleteImage
    case deleteItems
    
    var id: String {
        switch self {
        case .deleteImage:
            return "deleteImage"
        case .deleteItems:
            return "deleteItems"
        }
    }
}

struct BoxDetailView: View {
    @ObservedObject private var storage = InventoryStorageState.shared
    @Binding var searchText: String
    @Binding var selectedOption: String
    @Binding var box: MovingBox // Verwende Binding, um die Box zu bearbeiten
    @State private var searchSuggestions: [String] = UserDefaults.standard.stringArray(forKey: "searchSuggestions") ?? []
    @State private var selectedImageOrderOption = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
    @State private var previewImage: UIImage? = nil
    @State private var selectedItems: Set<UUID> = [] // Enthält die ausgewählten Item-IDs
    @State private var isSelecting = false
    @State private var isEditing: Bool = false
    @State private var pressAndHold: Bool = UserDefaultsManager.shared.loadPressAndHold()
    ///TAGS DEAKTIVIERT!!!!
    @State private var showTags: Bool = UserDefaults.standard.object(forKey: "showTags") == nil ? true : UserDefaults.standard.bool(forKey: "showTags")
    @State private var hideTags: Bool = UserDefaults.standard.object(forKey: "hideTags") == nil ? true : UserDefaults.standard.bool(forKey: "hideTags")
    @State private var newItem: String = ""
    @State private var selectedItem: String? = nil // Für die Bearbeitung eines Items
    @Environment(\.colorScheme) var colorScheme  // Zugriff auf Dark/Light Mode
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @State private var selectedImageURL: String?
    @State private var showDetailView = false // Zum Anzeigen des Sheets
    @State private var showCameraPicker = false
    @State private var showImagePicker = false
    @State private var selectedImages: [UIImage] = []
    @State private var showItemCameraPicker = false
    @State private var showItemImagePicker = false
    @State private var selectedItemPickerImages: [UIImage] = []
    @State private var activeItemImageID: UUID?
    @State private var createItemImageInputSource: String = UserDefaultsManager.shared.loadCreateItemImageInputSource()
    @State private var showAlert: Bool = false
    @State private var activeAlert: AlertType? = nil
    @State private var deleteIndex: Int?
    @State private var arrowuturnleft_clicked = false
    @State private var imagesToProcess: [UIImage?] = []
    @State private var recognizedTexts: [String] = [] // Ergebnisse der Texterkennung
    @State private var blockedTags: [String] = UserDefaultsManager.shared.loadBlockedTags()
    @State private var showMoveItemView: Bool = false
    @State var sourceBoxUUID: UUID = UUID()
    @State private var itemsToMove: Set<UUID> = []
    @State private var locations: [Locations] = loadLocations()
    @State private var items: [Items] = loadItems()
    @State private var draggedImagePath: String?
    @FocusState private var isTextFieldFocused: Bool
    @FocusState private var isNotesTextFieldFocused: Bool
    @State var items_uuid : [UUID] = []
    @State var item_uuid : UUID = UUID()
    @State var currentUUID : UUID = UUID()
    @State var collapsed: Bool = UserDefaults.standard.bool(forKey: "showAllItems")
    @State private var deepNavigation: Bool = UserDefaults.standard.object(forKey: "deepNavigation") == nil ? true : UserDefaults.standard.bool(forKey: "deepNavigation")
    @State private var QRCodeCopies: Int = UserDefaultsManager.shared.getQRCodeCopies()
    @State private var QRCodeNumber: Int = UserDefaultsManager.shared.getQRCodeNumber()
    @State private var boxes = loadBoxes()
    let addChangeImageOrder = changeImageOrder()
    var filteredItems: [Items] {
        // Neue Gegenstände zuerst anzeigen, unabhängig von der Speicherreihenfolge.
        items.filter { $0.box_uuid == box.id }.sorted { $0.createdAt > $1.createdAt }
    }
    var boxHasItemImages: Bool {
        filteredItems.contains { !$0.images.isEmpty }
    }
    var location: Locations {
        if let locationUUID = box.location_uuid,
           let foundLocation = locations.first(where: { $0.id == locationUUID }) {
            return foundLocation
        }
        return Locations(id: UUID(), name: "", color: "")
    }
    var locationColor: String {
        guard let location_uuid = box.location_uuid,
              let location = locations.first(where: { $0.id == location_uuid }) else {
            return ""
        }

        return location.color
    }

    private var firstPreviewImagePath: String? {
        selectedImageOrderOption == "new" ? box.images.reversed().first : box.images.first
    }

    // Lädt das aktuell erste Vorschaubild gemäß aktiver Sortierung.
    private func refreshPreviewImage() {
        guard let firstImagePath = firstPreviewImagePath else {
            previewImage = nil
            return
        }

        let previewPixelSize = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * UIScreen.main.scale
        let mediaRevision = storage.mediaRevision
        Task {
            let image = await BoxDetailPreviewLoader.shared.loadPreview(
                path: firstImagePath,
                maxPixelSize: previewPixelSize
            )
            guard !Task.isCancelled, mediaRevision == storage.mediaRevision,
                  firstImagePath == self.firstPreviewImagePath else { return }
            previewImage = image
        }
    }

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    if #available(iOS 2996.0, *) {
                        /*iOS26 GlassEffectContainer(spacing: 40.0) {
                            VStack(alignment: .center) {
                                // QR-Code anzeigen
                                //if let qrCodeImage = generateQRCodeForBox(box.id , text: box.name, standort: locationName) {
                                Button(action: {
                                    if let qrCodeImage = generateQRCodeForBox(box.id , text: box.name, standort: locationName, standortColor: stringToColor(locationColor).map { UIColor($0) }) {
                                        printQRCode(qrCodeImage, count: QRCodeCopies, perPage: QRCodeNumber)
                                    }
                                }) {
                                    HStack {
                                        HStack {
                                            Image(systemName: "printer.fill.and.paper.fill")
                                                .frame(width: 38, height: 38)
                                            //.padding(8)
                                            //.padding(.leading, 6)
                                        }
                                    }
                                    //.background(Color(UIColor.systemFill))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .cornerRadius(8) // Abgerundete Ecken
                                }
                                /*iOS26*/ .glassEffect()
                                //}
                                Button(action: {
                                    
                                }) {
                                    HStack {
                                        Image(systemName: "photo.fill")
                                            .frame(width: 38, height: 38)
                                        //.padding(8)
                                        //.padding(.leading, 6)
                                    }
                                    .onTapGesture {
                                        showImagePicker = true
                                    }
                                    //.background(Color(UIColor.systemFill))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .cornerRadius(8)
                                    .sheet(isPresented: $showImagePicker) {
                                        ImagePicker(selectedImages: $selectedImages)
                                            .onDisappear {
                                                // Check if there are any selected images to add
                                                if !selectedImages.isEmpty {
                                                    updateImages(addImages: selectedImages)
                                                    // Optionally, clear selectedImages if you want to reset after adding
                                                    selectedImages.removeAll() // Clear after updating, if needed
                                                }
                                                //showImagePicker.toggle()
                                            }
                                            .accentColor(selectedColor)
                                    }
                                }
                                /*iOS26*/ .glassEffect()
                                Button(action: {
                                    
                                }) {
                                    HStack {
                                        Image(systemName: "camera.fill")
                                            .frame(width: 38, height: 38)
                                        //.padding(8)
                                        //.padding(.leading, 6)
                                    }
                                    .onTapGesture {
                                        showCameraPicker = true
                                    }
                                    //.background(Color(UIColor.systemFill))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .cornerRadius(5)
                                    .sheet(isPresented: $showCameraPicker) {
                                        CameraPicker(images: $selectedImages)
                                            .onDisappear {
                                                // Check if there are any selected images to add
                                                if !selectedImages.isEmpty {
                                                    updateImages(addImages: selectedImages)
                                                    // Optionally, clear selectedImages if you want to reset after adding
                                                    selectedImages.removeAll() // Clear after updating, if needed
                                                    showCameraPicker.toggle()
                                                }
                                            }
                                            .accentColor(selectedColor)
                                    }
                                }
                                /*iOS26*/ .glassEffect()
                            }
                            .padding(.leading, 7)
                            .frame(height: 132)
                        /*iOS26*/ }*/
                    }
                    else {
                        VStack {
                            // QR-Code anzeigen
                            //if let qrCodeImage = generateQRCodeForBox(box.id , text: box.name, standort: locationName) {
                            Button(action: {
                                if let qrCodeImage = generateQRCodeForBox(box.id , text: box.name, standort: location.name, standortColor: stringToColor(locationColor).map { UIColor($0) }) {
                                    printQRCode(qrCodeImage, count: QRCodeCopies, perPage: QRCodeNumber)
                                }
                            }) {
                                topHeaderActionIcon("printer.fill.and.paper.fill")
                            }
                            //}
                            Spacer()
                            Button(action: {
                                showImagePicker = true
                            }) {
                                topHeaderActionIcon("photo.fill")
                            }
                            .sheet(isPresented: $showImagePicker) {
                                ImagePicker(selectedImages: $selectedImages)
                                    .onDisappear {
                                        // Check if there are any selected images to add
                                        if !selectedImages.isEmpty {
                                            updateImages(addImages: selectedImages)
                                            // Optionally, clear selectedImages if you want to reset after adding
                                            selectedImages.removeAll() // Clear after updating, if needed
                                        }
                                        //showImagePicker.toggle()
                                    }
                                    .accentColor(selectedColor)
                            }
                            Spacer()
                            Button(action: {
                                showCameraPicker = true
                            }) {
                                topHeaderActionIcon("camera.fill")
                            }
                            .sheet(isPresented: $showCameraPicker) {
                                CameraPicker(images: $selectedImages)
                                    .onDisappear {
                                        // Check if there are any selected images to add
                                        if !selectedImages.isEmpty {
                                            updateImages(addImages: selectedImages)
                                            // Optionally, clear selectedImages if you want to reset after adding
                                            selectedImages.removeAll() // Clear after updating, if needed
                                            showCameraPicker.toggle()
                                        }
                                    }
                                    .accentColor(selectedColor)
                            }
                        }
                        .frame(height: 132)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        if !box.images.isEmpty {
                            HStack {
                                let images = selectedImageOrderOption == "new" ? Array(box.images.enumerated().reversed()) : Array(box.images.enumerated())
                                
                                ForEach(images, id: \.offset) { index, imagePath in
                                    BoxDetailThumbnailCell(
                                        imagePath: imagePath,
                                        isEditing: isEditing,
                                        pressAndHold: pressAndHold,
                                        selectedImageOrderOption: selectedImageOrderOption,
                                        draggedImagePath: $draggedImagePath,
                                        boxImages: $box.images,
                                        selectedImageURL: $selectedImageURL,
                                        showDetailView: $showDetailView,
                                        onDelete: {
                                            deleteIndex = index
                                            activeAlert = .deleteImage
                                            showAlert = true
                                        },
                                        onLongPress: {
                                            startEditing()
                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                            generator.impactOccurred()
                                        }
                                    )
                                }
                                .sheet(isPresented: $showDetailView) {
                                    ImageDetailView(
                                        imagePaths: $box.images,
                                        selectedImagePath: $selectedImageURL,
                                        showDetailView: $showDetailView,
                                        selectedColor: selectedColor
                                    ) { deletedPath in
                                        deleteBoxPhoto(deletedPath)
                                        BoxDetailThumbnailLoader.shared.removeCachedThumbnails(for: deletedPath)
                                        BoxDetailPreviewLoader.shared.removeCachedPreview(for: deletedPath)
                                        let remainingPaths = box.images.filter { $0 != deletedPath }
                                        if let firstImagePath = (selectedImageOrderOption == "new" ? remainingPaths.reversed().first : remainingPaths.first) {
                                            let previewPixelSize = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * UIScreen.main.scale
                                            Task {
                                                previewImage = await BoxDetailPreviewLoader.shared.loadPreview(
                                                    path: firstImagePath,
                                                    maxPixelSize: previewPixelSize
                                                )
                                            }
                                        } else {
                                            previewImage = nil
                                        }
                                    }
                                    //.interactiveDismissDisabled()
                                }
                            }
                            .popoverTip(addChangeImageOrder)
                            .onAppear {
                                // Gleicher Initialisierungszeitpunkt wie in ItemsDetailView:
                                // erst wenn der Bildbereich wirklich erscheint.
                                selectedImageOrderOption = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
                                refreshPreviewImage()
                                pressAndHold = UserDefaultsManager.shared.loadPressAndHold()
                                selectedColor = UserDefaultsManager.loadAccentColor()
                            }
                        }
                        else {
                            if #available(iOS 296.0, *) {
                                HStack {
                                    ForEach(3...5, id: \.self) { number in
                                        VStack {
                                            
                                        }
                                        .frame(width: 132, height: 132)
                                        .background(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                        //.glassEffect(in: .rect(cornerRadius: 19.0))
                                    }
                                }
                            }
                            else {
                                HStack {
                                    ForEach(3...5, id: \.self) { number in
                                        VStack {
                                            
                                        }
                                        .frame(width: 132, height: 132)
                                        .background(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            
                        }
                        
                    }
                    .cornerRadius(8)
                    HStack {
                        
                    }
                    .padding(2)
                }
                .padding(8)
                .allowsHitTesting(!isSelecting)
                
                Form {
                    
                    Section {
                        if !isEditing {
                            if deepNavigation && !isSelecting {
                                ZStack {
                                    NavigationLink(
                                        destination: LocationDetailView(
                                            searchText: $searchText,
                                            selectedOption: $selectedOption,
                                            location: Binding(
                                                get: { locations.first(where: { $0.id == location.id }) ?? location },
                                                set: { newValue in
                                                    if let updated = InventoryMutation.location(location.id, change: { $0 = newValue }) {
                                                        locations = updated
                                                    }
                                                }
                                            )
                                        )
                                    ) {
                                        EmptyView()
                                    }
                                    .contentShape(Rectangle())
                                    .opacity(0.0)
                                    HStack {
                                        Text("Location")
                                            .foregroundStyle(isColorTooDark(color: stringToColor(locationColor) ?? .clear) ? .white : .black)
                                        Spacer()
                                        Text(location.name.isEmpty ? "👻" : location.name)
                                            .foregroundStyle(isColorTooDark(color: stringToColor(locationColor) ?? .clear) ? .white : .black)
                                        Image(systemName:"chevron.forward")
                                            .foregroundStyle(isColorTooDark(color: stringToColor(locationColor) ?? .clear) ? .white : .black)
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                }
                            }
                            else {
                                HStack {
                                    Text("Location")
                                        .foregroundStyle(isColorTooDark(color: stringToColor(locationColor) ?? .clear) ? .white : .black)
                                    Spacer()
                                    Text(location.name.isEmpty ? "👻" : location.name)
                                        .foregroundStyle(isColorTooDark(color: stringToColor(locationColor) ?? .clear) ? .white : .black)
                                }
                            }
                            /*
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
                             */
                        }
                        else {
                            HStack {
                                Text("Location")
                                    .foregroundStyle(isColorTooDark(color: stringToColor(locationColor) ?? .clear) ? Color.white.opacity(1) : Color.black.opacity(1))
                                Spacer()
                                if !locations.isEmpty {
                                    
                                    Picker("", selection: $box.location_uuid) {
                                        ForEach(locations, id: \.id) { location in
                                            Text(location.name.count > 20 ? String(location.name.prefix(17)) + "..." : location.name)
                                                .tag(location.id)
                                                .lineLimit(1)
                                        }
                                    }
                                    .accentColor(isColorTooDark(color: stringToColor(locationColor) ?? .clear) ? Color.white : Color.black)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .pickerStyle(MenuPickerStyle())
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 4)
                                    
                                    
                                }
                            }
                        }
                    }
                    .listRowBackground(stringToColor(locationColor))
                    .frame(height: 20)

                    itemsSection
                    Section {
                        VStack {
                            TextField("Notes", text: Binding(
                                get: { box.notes ?? "" },
                                set: { box.notes = $0 }
                            ), axis: .vertical)
                            .disabled(isSelecting)
                            .scrollIndicators(.visible, axes: .vertical)
                            .padding(.top, 3)
                            .ignoresSafeArea(.keyboard, edges: .bottom)
                        }
                        .frame(minHeight: 20)
                        .frame(maxHeight: 132)
                    }
                    .frame(maxHeight: 132)
                    Section {
                        if showTags && !hideTags {
                            HStack {
                                if let tags = box.tags, !tags.isEmpty {
                                    HStack {
                                        Image(systemName: "trash")
                                        //.frame(width: 20, height: 20)
                                            .foregroundStyle(.white)
                                        //.scaledToFit()
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
                                        box.tags?.removeAll()
                                        arrowuturnleft_clicked = false
                                    }
                                    .onAppear {
                                        //filteredLocations = locations.filter { box.location_uuid == $0.id }
                                        arrowuturnleft_clicked = false
                                        //blockedTags = UserDefaultsManager.shared.loadBlockedTags()
                                    }
                                }
                                //Bekannter Fehler: Wenn OverviewView nach Änderungsdatum sortiert wird, schließt sich dieser View bei der Suche nach Tags
                                if (box.tags?.isEmpty ?? true) && box.images.count > 0 && !arrowuturnleft_clicked {
                                    HStack {
                                        Image(systemName: "text.viewfinder")
                                        //.frame(width: 20, height: 20)
                                            .foregroundStyle(isColorTooDark(color: selectedColor) ? .white : .black)
                                        //.scaledToFit()
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
                                        // Lade die Bilder
                                        let imagesToProcess = UserDefaultsManager.shared.loadImages(from: box.images)
                                        
                                        // Filtere die gültigen Bilder (entferne nil-Werte)
                                        let validImages = imagesToProcess.compactMap { $0 }  // Hier entfernen wir `nil` und behalten nur gültige `UIImage`-Instanzen
                                        
                                        if !validImages.isEmpty {
                                            arrowuturnleft_clicked = true
                                            processImages(validImages) { recognizedTexts in
                                                // Sicher auf dem Hauptthread
                                                DispatchQueue.main.async {
                                                    // Erkennte Texte verarbeiten
                                                    self.recognizedTexts = recognizedTexts
                                                    // Update der UI oder andere Hauptthread-Aufgaben
                                                    box.tags = recognizedTexts
                                                    arrowuturnleft_clicked = false
                                                }
                                            }
                                        } else {
                                            //print("Fehler: Keine gültigen Bilder zum Verarbeiten")
                                        }
                                    }
                                }
                                if arrowuturnleft_clicked && !box.images.isEmpty {
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
                                if (box.tags?.isEmpty ?? true) && box.images.isEmpty {
                                    HStack {
                                        Image(systemName: "arrow.uturn.left")
                                        //.frame(width: 20, height: 20)
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
                                        if var tags = box.tags {
                                            if tags.count > 0 {
                                                ForEach(tags, id: \.self) { text in
                                                    HStack {
                                                        Button {
                                                            if tags.firstIndex(of: text) != nil {
                                                                //deleteTags(at: index)
                                                                //print("Delete \(text)")
                                                                blockedTags = UserDefaultsManager.shared.loadBlockedTags()
                                                                tags.removeAll(where: {$0 == text })
                                                                //print("blockedTags create: \(blockedTags)")
                                                                if !blockedTags.contains(text) {
                                                                    blockedTags.append(text)
                                                                }
                                                                UserDefaultsManager.shared.saveBlockedTags(blockedTags)
                                                                //print("blockedTags create: \(blockedTags)")
                                                            }
                                                            box.tags = tags
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
                                            }
                                            else {
                                                ForEach(3...5, id: \.self) { number in
                                                    HStack {
                                                        
                                                    }
                                                    .frame(width: 75,height: 26)
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
                    // Anzahl der Items anzeigen
                    VStack {
                        let itemCount = items.filter { $0.box_uuid == box.id }.count
                        Text(String(format: NSLocalizedString("BoxDetailView.Objects", comment: ""), itemCount))
                            .font(.headline) // Optional: Stil für die Überschrift
                            .foregroundColor(.gray) // Textfarbe
                            .padding(.vertical, 4) // Verringere das vertikale Padding
                            .background(Color.clear) // Neutrale Hintergrundfarbe
                            .cornerRadius(8) // Optional: Abgerundete Ecken
                            .frame(maxWidth: .infinity, alignment: .center) // Text zentrieren
                            .onTapGesture {
                                // Kopiere die Box-ID in die Zwischenablage
                                UIPasteboard.general.string = "boxhelper://box/\(box.id)"
                            }
                        HStack {
                            Text("#\(box.id.description.prefix(6))")
                                .font(.footnote)
                                .foregroundStyle(Color.secondary.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Color.clear) // Hintergrundfarbe der Zeile
                }
                .listSectionSpacing(16.0)
                .navigationTitle(!isEditing ? "\(box.name)" : "")
                .navigationBarTitleDisplayMode(.inline)
                .scrollDismissesKeyboard(.immediately)
            }
            .alert(item: $activeAlert) { alertType in
                self.createAlert(for: alertType)
            }
            .onAppear {
                UserDefaultsManager.shared.saveLastState("boxes")
                items = UserDefaultsManager.shared.loadItems()
                boxes = loadBoxes()
                //selectedOption = "boxes"
                deepNavigation = UserDefaults.standard.object(forKey: "deepNavigation") == nil ? true : UserDefaults.standard.bool(forKey: "deepNavigation")
            }
            .toolbar() {
                ToolbarItem(placement: .principal){
                    if isEditing {
                        TextField("CreateView.BoxTitle", text: $box.name)
                            .font(.headline)
                            .multilineTextAlignment(.center) // Zentriert den Text
                            .padding(5) // Innenabstand
                            .padding(.top, -1)
                            .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : .white)
                            .cornerRadius(19) // Ecken abrunden
                            .foregroundColor(colorScheme == .dark ? .white : .black) // Textfarbe
                            .frame(width: UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac ? UIScreen.main.bounds.width / 5 : UIScreen.main.bounds.width / 2.5)
                    }
                }
                FirstTabDetailToolbar(
                    isSelecting: isSelecting,
                    isEditing: isEditing,
                    count: selectedItems.count,
                    total: filteredItems.count,
                    selectedColor: selectedColor,
                    select: startSelecting,
                    edit: startEditing,
                    selectAll: selectAll,
                    move: {
                        itemsToMove = selectedItems
                        showMoveItemView = true
                    },
                    delete: { activeAlert = .deleteItems },
                    finish: finishInteraction
                )
            }
            .sheet(isPresented: $showMoveItemView){
                NavigationStack {
                    MoveItemView(itemsToMove: $itemsToMove) {
                        // Erst nach erfolgreichem Speichern Auswahl und Navigation zurücksetzen.
                        items = loadItems()
                        boxes = loadBoxes()
                        locations = loadLocations()
                        finishInteraction()
                    }
                }
            }
            .onAppear {
                if searchText.isEmpty == false {
                    searchSuggestions.append(searchText)
                    UserDefaults.standard.set(searchSuggestions, forKey: "searchSuggestions")
                }
                pressAndHold = UserDefaultsManager.shared.loadPressAndHold()
                selectedImageOrderOption = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
                refreshPreviewImage()
                QRCodeCopies = UserDefaultsManager.shared.getQRCodeCopies()
                QRCodeNumber = UserDefaultsManager.shared.getQRCodeNumber()
                selectedColor = UserDefaultsManager.loadAccentColor()
                createItemImageInputSource = UserDefaultsManager.shared.loadCreateItemImageInputSource()
                blockedTags = UserDefaultsManager.shared.loadBlockedTags()
                ///TAGS DEAKTIVIERT!!!!
                showTags = UserDefaults.standard.object(forKey: "showTags") == nil ? true : UserDefaults.standard.bool(forKey: "showTags")
                hideTags = UserDefaults.standard.object(forKey: "hideTags") == nil ? true : UserDefaults.standard.bool(forKey: "hideTags")
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
        }
        .sheet(isPresented: $showItemImagePicker, onDismiss: {
            applySelectedImageToActiveItem()
        }) {
            ImagePicker(selectedImages: $selectedItemPickerImages, selectionLimit: 1)
                .accentColor(selectedColor)
        }
        .sheet(isPresented: $showItemCameraPicker, onDismiss: {
            applySelectedImageToActiveItem()
        }) {
            CameraPicker(images: $selectedItemPickerImages)
                .accentColor(selectedColor)
        }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryDidChange)) { _ in
            // Zugehörige Daten neu laden, den aktuellen Bearbeitungsmodus erhalten.
            let inventory = InventoryStorageState.shared.readSnapshot()
            if boxes != inventory.boxes { boxes = inventory.boxes }
            if items != inventory.items { items = inventory.items }
            if locations != inventory.locations { locations = inventory.locations }
            // Verschobene Gegenstände gehören nicht mehr zur Auswahl dieser Kiste.
            selectedItems.formIntersection(Set(filteredItems.map(\.id)))
        }
        .onChange(of: storage.mediaRevision) { _, _ in refreshPreviewImage() }
        .onChange(of: box.images) { _, paths in
            // Rebuild OCR tags after adding or deleting photos; ignore outdated callbacks.
            let boxID = box.id
            generateAutomaticTagsIfEnabled(fromImagePaths: paths) { tags in
                guard box.id == boxID else { return }
                // Nur die Tags des aktuellen Datensatzes ändern, keine alte Kistenkopie zurückschreiben.
                if let updated = InventoryMutation.box(boxID, change: { storedBox in
                    guard storedBox.images == paths, storedBox.tags != tags else { return }
                    storedBox.tags = tags
                }) {
                    boxes = updated
                }
            }
        }
        .navigationBarBackButtonHidden(isSelecting)
        .toolbar(isSelecting || isEditing ? .hidden : .visible, for: .tabBar)
        .preference(key: FirstTabSelectionActiveKey.self, value: isSelecting || isEditing)
        .modifier(FirstTabSelectionBarBackground(isEditing: isSelecting))
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

    /// Im Auswahlmodus bleiben alle Inhalte sichtbar; die gespeicherte Einklappung
    /// gilt wieder, sobald der Modus beendet wird.
    private var itemsSection: some View {
        Section {
            List {
                if !isSelecting {
                    HStack {
                        TextField("BoxDetailView.NewObject", text: $newItem)
                            .focused($isTextFieldFocused)
                            .frame(maxHeight: 100)
                            .onSubmit {
                                addItem()
                                isTextFieldFocused = true
                            }
                        Button(action: addItem) {
                            Image(systemName: "plus")
                        }
                        .disabled(newItem.isEmpty)
                    }
                }

                ForEach(Array(filteredItems.enumerated()), id: \.1.id) { index, item in
                    if isSelecting || !collapsed || index < 3 || filteredItems.count <= 4 {
                        itemListRow(item)
                            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                            .swipeActions(edge: .leading) {
                                if !isSelecting {
                                    Button { toggleIsFragile(for: item) } label: {
                                        Label("", image: item.isFragile ? "custom.wineglass.slash" : "custom.wineglass")
                                    }
                                    .tint(.blue)
                                    Button { toggleIsHeavy(for: item) } label: {
                                        Label("", image: item.isHeavy ? "custom.figure.strengthtraining.traditional.slash" : "custom.figure.strengthtraining.traditional")
                                    }
                                    .tint(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                if !isSelecting {
                                    Button(role: .destructive) { deleteItem(item) } label: {
                                        Label("", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }

                if !isSelecting && filteredItems.count > 4 {
                    Button {
                        withAnimation { collapsed.toggle() }
                        UserDefaults.standard.set(collapsed, forKey: "showAllItems")
                    } label: {
                        Label(
                            collapsed
                                ? String(format: NSLocalizedString("show %ld more", comment: ""), filteredItems.count - 3)
                                : NSLocalizedString("show less", comment: ""),
                            systemImage: collapsed ? "chevron.down" : "chevron.up"
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func itemListRow(_ item: Items) -> some View {
        if isSelecting {
            // Die komplette Zeile wählt aus, ohne Eingabefelder oder Navigation zu öffnen.
            Button { toggleSelection(for: item) } label: {
                HStack {
                    Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(selectedColor)
                    itemSummaryContent(item)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selectedItems.contains(item.id) ? [.isSelected] : [])
        } else if isEditing {
            HStack {
                itemImageSlot(for: item, isEditing: true)
                TextField("BoxDetailView.NewObject", text: Binding(
                    get: { items.first(where: { $0.id == item.id })?.name ?? item.name },
                    set: { newValue in
                        // Einzelne Eingaben speichern, ohne eine veraltete Item-Kopie zu schreiben.
                        if let updated = InventoryMutation.item(item.id, change: { $0.name = newValue }) {
                            items = updated
                        }
                    }
                ))
                .frame(maxHeight: 100)
            }
        } else if deepNavigation, let index = items.firstIndex(where: { $0.id == item.id }) {
            NavigationLink {
                ItemsDetailView(searchText: $searchText, item: bindingForItemDetail(at: index))
            } label: {
                itemRowContent(item)
            }
        } else {
            itemRowContent(item)
        }
    }

    private func startSelecting() {
        hideKeyboard()
        withAnimation(.snappy) {
            selectedItems.removeAll()
            isEditing = false
            isSelecting = true
        }
    }

    private func startEditing() {
        hideKeyboard()
        withAnimation(.snappy) {
            selectedItems.removeAll()
            isSelecting = false
            isEditing = true
        }
    }

    private func finishInteraction() {
        hideKeyboard()
        withAnimation(.snappy) {
            selectedItems.removeAll()
            itemsToMove.removeAll()
            isSelecting = false
            isEditing = false
        }
    }

    private func selectAll() {
        if selectedItems.count == filteredItems.count {
            selectedItems.removeAll()
        } else {
            selectedItems = Set(filteredItems.map { $0.id })
        }
    }
    private func toggleSelection(for item: Items) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    // Die ID bleibt nach Imports, Löschungen und neuer Sortierung stabil.
    private func bindingForItemDetail(at index: Int) -> Binding<Items> {
        let item = items[index]
        return Binding(
            get: { items.first(where: { $0.id == item.id }) ?? item },
            set: { newValue in
                guard let updated = InventoryMutation.item(item.id, change: { $0 = newValue }) else { return }
                items = updated
            }
        )
    }

    private func deleteSelectedItems() {
        deleteItems(with: selectedItems)
    }

    private func addItem() {
        guard !newItem.isEmpty, loadBoxes().contains(where: { $0.id == box.id }) else { return }
        let newItemObject = Items(id: UUID(), name: newItem, box_uuid: box.id)
        guard let updated = InventoryMutation.items(change: { $0.append(newItemObject) }) else { return }
        items = updated
        newItem = ""
    }

    private func deleteItems(at offsets: IndexSet) {
        let boxItems = items.filter { $0.box_uuid == box.id }
        let ids = Set(offsets.compactMap { boxItems.indices.contains($0) ? boxItems[$0].id : nil })
        deleteItems(with: ids)
    }

    private func deleteItem(_ item: Items) {
        deleteItems(with: [item.id])
    }

    private func deleteItems(with ids: Set<UUID>) {
        Task { @MainActor in
            do {
                _ = try await InventoryDeletion.shared.items(ids)
                items = loadItems()
                selectedItems.subtract(ids)
            } catch { InventoryStorageState.shared.report(error) }
        }
    }

    private func deleteBoxPhoto(_ filename: String, index: Int? = nil) {
        let ownerID = box.id
        Task { @MainActor in
            do {
                guard try await InventoryDeletion.shared.imageReference(filename, owner: .box(ownerID), index: index) else { return }
                if let confirmed = loadBoxes().first(where: { $0.id == ownerID }) { box = confirmed }
                BoxDetailThumbnailLoader.shared.removeCachedThumbnails(for: filename)
                BoxDetailPreviewLoader.shared.removeCachedPreview(for: filename)
                refreshPreviewImage()
            } catch { InventoryStorageState.shared.report(error) }
        }
    }

    private func toggleIsFragile(for item: Items) {
        if let updated = InventoryMutation.item(item.id, change: { $0.isFragile.toggle() }) { items = updated }
    }

    private func toggleIsHeavy(for item: Items) {
        if let updated = InventoryMutation.item(item.id, change: { $0.isHeavy.toggle() }) { items = updated }
    }

    @ViewBuilder
    private func itemImageSlot(for item: Items, isEditing: Bool) -> some View {
        if let imagePath = item.images.first {
            BoxDetailThumbnailView(imagePath: imagePath, side: 32)
        } else if isEditing, createItemImageInputSource != "none" {
            Button {
                openItemImagePicker(for: item.id)
            } label: {
                Image(systemName: createItemImageInputSource == "gallery" ? "photo.fill" : "camera.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(Color(UIColor.systemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        } else if boxHasItemImages {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(colorScheme == .dark ? 0.28 : 0.08))
                .frame(width: 32, height: 32)
        }
    }

    private func openItemImagePicker(for itemID: UUID) {
        activeItemImageID = itemID
        selectedItemPickerImages.removeAll()

        if createItemImageInputSource == "gallery" {
            showItemImagePicker = true
        } else if createItemImageInputSource == "camera" {
            showItemCameraPicker = true
        }
    }

    private func applySelectedImageToActiveItem() {
        guard let itemID = activeItemImageID, let image = selectedItemPickerImages.first else {
            selectedItemPickerImages.removeAll()
            activeItemImageID = nil
            return
        }
        let fileName = "\(UUID().uuidString).jpg"
        guard let data = image.compressImage(),
              let fileURL = UserDefaultsManager.shared.saveImage(data, withName: fileName) else { return }
        // Nur dieses Foto ergänzen: während der Auswahl gespeicherte Bilder bleiben erhalten.
        guard let updated = InventoryMutation.item(itemID, change: { $0.images.append(fileURL.lastPathComponent) }) else {
            UserDefaultsManager.shared.deleteImage(named: fileURL.lastPathComponent)
            return
        }
        items = updated
        refreshTagsForItem(withID: itemID)
        selectedItemPickerImages.removeAll()
        activeItemImageID = nil
    }

    private func refreshTagsForItem(withID itemID: UUID) {
        guard let savedItem = loadItems().first(where: { $0.id == itemID }) else { return }
        let imagePaths = savedItem.images
        generateAutomaticTagsIfEnabled(fromImagePaths: imagePaths) { generatedTags in
            if let updated = InventoryMutation.item(itemID, change: { storedItem in
                guard storedItem.images == imagePaths, storedItem.tags != generatedTags else { return }
                storedItem.tags = generatedTags
            }) {
                items = updated
            }
        }
    }
    
    @ViewBuilder
    private func itemSummaryContent(_ item: Items) -> some View {
        HStack {
            itemImageSlot(for: item, isEditing: false)
            if item.name.isEmpty {
                Text("👻")
            } else {
                Text(item.name)
                    .frame(maxHeight: 100)
            }
            Spacer()
            if item.isFragile {
                Image(systemName: "wineglass")
                    .foregroundStyle(Color.customGray)
            }
            if item.isHeavy {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(Color.customGray)
            }
        }
    }

    private func itemRowContent(_ item: Items) -> some View {
        HStack {
            itemSummaryContent(item)
            Menu {
                Section(header: Text("#\(item.id.description.prefix(6))")) { }
                Section {
                    Button(action: { toggleIsFragile(for: item) }) {
                        Label(item.isFragile ? "Nicht fragil" : "Fragil", image: item.isFragile ? "custom.wineglass.slash" : "custom.wineglass")
                    }
                    Button(action: { toggleIsHeavy(for: item) }) {
                        Label(item.isHeavy ? "Nicht schwer" : "Schwer", image: item.isHeavy ? "custom.figure.strengthtraining.traditional.slash" : "custom.figure.strengthtraining.traditional")
                    }
                }
                Section {
                    Button(role: .destructive, action: { deleteItem(item) }) {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(selectedColor)
                    .scaleEffect(1.2)
            }
        }
    }
    /*
    private func deleteTags(at offsets: IndexSet) {
        if let tags = box.tags {
            box.tags = tags.enumerated()
                .filter { !offsets.contains($0.offset) }
                .map { $0.element }
        }
    }
     */
    // Funktion zum Drucken des QR-Codes
    func printQRCode(_ qrCodeImage: UIImage, count: Int, perPage: Int) {
        let safeCount = max(count, 1)
        let safePerPage = max(perPage, 1)
        let totalPages = Int(ceil(Double(safeCount) / Double(safePerPage)))

        let printController = UIPrintInteractionController.shared
        printController.delegate = nil

        let pageWidth: CGFloat = 595.0
        let pageHeight: CGFloat = 842.0
        let margin: CGFloat = 28.35
        let spacing: CGFloat = 20.0 // Abstand zwischen Bildern

        let contentWidth = pageWidth - 2 * margin
        let contentHeight = pageHeight - 2 * margin
        let contentSize = CGSize(width: contentWidth, height: contentHeight)

        func createFittedImage(from image: UIImage, in size: CGSize, rotate90: Bool = false) -> UIImage {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 3
            let renderer = UIGraphicsImageRenderer(size: size, format: format)

            return renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))

                let imageToDraw = rotate90
                    ? UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: .right)
                    : image

                let imageSize = imageToDraw.size
                let widthRatio = size.width / imageSize.width
                let heightRatio = size.height / imageSize.height
                let scale = min(widthRatio, heightRatio)

                let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                let origin = CGPoint(
                    x: (size.width - scaledSize.width) / 2,
                    y: (size.height - scaledSize.height) / 2
                )

                imageToDraw.draw(in: CGRect(origin: origin, size: scaledSize))
            }
        }

        let pdfData = NSMutableData()
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)

        var printed = 0

        for _ in 0..<totalPages {
            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)

            if safePerPage == 1 {
                if printed < safeCount {
                    let fittedImage = createFittedImage(from: qrCodeImage, in: contentSize)
                    fittedImage.draw(in: CGRect(x: margin, y: margin, width: contentWidth, height: contentHeight))
                    printed += 1
                }
            } else if safePerPage == 2 {
                let availableHeight = contentHeight - spacing
                let halfHeight = availableHeight / 2
                for i in 0..<2 {
                    if printed >= safeCount { break }
                    let originY = margin + CGFloat(i) * (halfHeight + spacing)
                    let frame = CGRect(x: margin, y: originY, width: contentWidth, height: halfHeight)
                    let fittedImage = createFittedImage(from: qrCodeImage, in: frame.size, rotate90: true)
                    fittedImage.draw(in: frame)
                    printed += 1
                }
            } else {
                let cols = Int(ceil(sqrt(Double(safePerPage))))
                let rows = Int(ceil(Double(safePerPage) / Double(cols)))

                let totalSpacingX = CGFloat(cols - 1) * spacing
                let totalSpacingY = CGFloat(rows - 1) * spacing

                let itemWidth = (contentWidth - totalSpacingX) / CGFloat(cols)
                let itemHeight = (contentHeight - totalSpacingY) / CGFloat(rows)

                var slotsUsed = 0
                for row in 0..<rows {
                    for col in 0..<cols {
                        if slotsUsed >= safePerPage || printed >= safeCount { break }
                        let x = margin + CGFloat(col) * (itemWidth + spacing)
                        let y = margin + CGFloat(row) * (itemHeight + spacing)
                        let frame = CGRect(x: x, y: y, width: itemWidth, height: itemHeight)
                        let fittedImage = createFittedImage(from: qrCodeImage, in: frame.size)
                        fittedImage.draw(in: frame)
                        printed += 1
                        slotsUsed += 1
                    }
                }
            }
        }

        UIGraphicsEndPDFContext()
        printController.printingItem = pdfData
        printController.present(animated: true, completionHandler: nil)
    }
    private func updateImages(addImages: [UIImage] = [], removeIndices: [Int] = []) {
        let currentImages = box.images
        let boxID = box.id

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
                self.box.images = updatedImageNames
                var boxes = UserDefaultsManager.shared.loadBoxes()
                if let boxIndex = boxes.firstIndex(where: { $0.id == boxID }) {
                    boxes[boxIndex] = self.box
                }
            }
        }
    }
    func shareFile(fileURL: URL) {
        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)

        // Find the current active scene and its window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
           let topVC = keyWindow.rootViewController {
                // Ensure that it's iPad where the popover presentation happens
                if let popoverController = activityViewController.popoverPresentationController {
                    // Specify the source view or barButtonItem for the popover
                    popoverController.sourceView = topVC.view  // Use the root view or a specific button view
                    popoverController.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 1, height: 1) // Use a small area (adjust as needed)
                }
                // Present the activity view controller
                topVC.present(activityViewController, animated: true, completion: nil)
        }
    }
    private func createAlert(for alertType: AlertType) -> Alert {
            switch alertType {
            case .deleteImage:
                return Alert(
                    title: Text(NSLocalizedString("Delete image?", comment: "")),
                    message: Text(NSLocalizedString("Are you shure you want to delete this image?", comment: "")),
                    primaryButton: .destructive(Text(NSLocalizedString("Delete", comment: ""))) {
                        if let index = deleteIndex, box.images.indices.contains(index) {
                            deleteBoxPhoto(box.images[index], index: index)
                            deleteIndex = nil
                        }
                        showAlert = false
                    },
                    secondaryButton: .cancel {
                        deleteIndex = nil
                        showAlert = false
                    }
                )
            case .deleteItems:
                return Alert(
                    title: Text(String(format: NSLocalizedString("Delete %d Items?", comment: ""), selectedItems.count)),
                    message: Text(NSLocalizedString("Are you shure you want to delete the selected items?", comment: "")),
                    primaryButton: .destructive(Text(NSLocalizedString("Delete", comment: ""))) {
                        deleteSelectedItems()
                        showAlert = false
                    },
                    secondaryButton: .cancel {
                        showAlert = false
                    }
                )
            }
    }
}

private struct BoxDetailThumbnailCell: View {
    let imagePath: String
    let isEditing: Bool
    let pressAndHold: Bool
    let selectedImageOrderOption: String
    @Binding var draggedImagePath: String?
    @Binding var boxImages: [String]
    @Binding var selectedImageURL: String?
    @Binding var showDetailView: Bool
    let onDelete: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        ZStack {
            BoxDetailThumbnailView(imagePath: imagePath, side: 132)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onTapGesture {
                    selectedImageURL = imagePath
                    showDetailView = true
                }
                .onDrag {
                    draggedImagePath = imagePath
                    return NSItemProvider(object: imagePath as NSString)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: SortedImageReorderDropDelegate(
                        imagePaths: $boxImages,
                        draggedPath: $draggedImagePath,
                        targetPath: imagePath,
                        sortOption: selectedImageOrderOption
                    )
                )

            if isEditing {
                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .resizable()
                        .foregroundStyle(Color.white.opacity(0.8))
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .frame(width: 38, height: 38)
                .padding(.top, -60)
                .padding(.leading, -60)
            }
        }
        .frame(width: 132, height: 132)
        .background(Color.secondary)
        .foregroundColor(.white)
        .cornerRadius(8)
        .onLongPressGesture {
            guard pressAndHold else { return }
            onLongPress()
        }
    }
}

private struct BoxDetailThumbnailView: View {
    @ObservedObject private var storage = InventoryStorageState.shared
    let imagePath: String
    let side: CGFloat
    private let pixelSide: CGFloat
    private let cacheKey: String

    @State private var image: UIImage?

    init(imagePath: String, side: CGFloat) {
        self.imagePath = imagePath
        self.side = side
        pixelSide = side * UIScreen.main.scale
        cacheKey = "\(imagePath)#detail#\(Int(pixelSide.rounded(.up)))"
        _image = State(initialValue: BoxDetailImageMemoryCache.shared.image(for: cacheKey))
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(UIColor.systemFill))
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: "\(cacheKey)#\(storage.mediaRevision)") {
            let result = await BoxDetailThumbnailLoader.shared.loadThumbnail(
                path: imagePath,
                maxPixelSize: pixelSide,
                cacheKey: cacheKey
            )
            guard !Task.isCancelled else { return }
            image = result
        }
    }
}

@MainActor
private final class BoxDetailThumbnailLoader {
    static let shared = BoxDetailThumbnailLoader()

    func loadThumbnail(path: String, maxPixelSize: CGFloat, cacheKey: String) async -> UIImage? {
        let request = InventoryThumbnailLoader.Request(filename: path, maxPixelSize: maxPixelSize)
        let image = await InventoryThumbnailLoader.shared.load(request, mediaRevision: InventoryStorageState.shared.mediaRevision)
        if let image { BoxDetailImageMemoryCache.shared.insert(image, for: cacheKey) }
        return image
    }

    func removeCachedThumbnails(for path: String) {
        BoxDetailImageMemoryCache.shared.removeCachedEntries(withPrefix: "\(path)#detail#")
    }
}

@MainActor
private final class BoxDetailPreviewLoader {
    static let shared = BoxDetailPreviewLoader()

    func loadPreview(path: String, maxPixelSize: CGFloat) async -> UIImage? {
        // Derselbe versionierte Hintergrund-Loader versorgt Vorschau und Fotozellen.
        let request = InventoryThumbnailLoader.Request(filename: path, maxPixelSize: maxPixelSize)
        return await InventoryThumbnailLoader.shared.load(request, mediaRevision: InventoryStorageState.shared.mediaRevision)
    }

    func removeCachedPreview(for path: String) {
        BoxDetailImageMemoryCache.shared.removeCachedEntries(withPrefix: "\(path)#preview#")
    }
}

private final class BoxDetailImageMemoryCache: @unchecked Sendable {
    static let shared = BoxDetailImageMemoryCache()

    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var cachedKeys: Set<String> = []

    private init() {
        cache.countLimit = 500
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

    func removeCachedEntries(withPrefix prefix: String) {
        lock.lock()
        let matchingKeys = cachedKeys.filter { $0.hasPrefix(prefix) }
        matchingKeys.forEach { cachedKeys.remove($0) }
        lock.unlock()

        for key in matchingKeys {
            cache.removeObject(forKey: key as NSString)
        }
    }
}

struct ImageDropDelegate: DropDelegate {
    @Binding var images: [String] // Array der Bilder
    let fromIndex: Int?           // Index des verschobenen Elements
    let toIndex: Int              // Zielindex

    func performDrop(info: DropInfo) -> Bool {
        guard let fromIndex = fromIndex else { return false }
        if fromIndex != toIndex {
            images.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
        return true
    }
}
#Preview {
    ContentView(lastState: Binding(get: { "" }, set: { (_: String) in }))
        .environmentObject(QuickActionState.shared)
}

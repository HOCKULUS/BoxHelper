//
//  ItemsDetailView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 14.04.25.
//
import SwiftUI
import UniformTypeIdentifiers

struct ItemsDetailView: View {
    @Binding var searchText: String
    @Binding var item: Items
    @State private var searchSuggestionsItems: [String] = UserDefaults.standard.stringArray(forKey: "searchSuggestionsItems") ?? []
    @State private var boxes: [MovingBox] = loadBoxes()
    @State private var  locations: [Locations] = loadLocations()
    @Environment(\.colorScheme) var colorScheme
    @State private var isEditing: Bool = false
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
    @State private var showAlert: Bool = false
    @State private var activeAlert: AlertType? = nil
    @State private var deleteIndex: Int?
    @State private var selectedImageURL: String?
    @State private var deepNavigation: Bool = UserDefaults.standard.object(forKey: "deepNavigation") == nil ? true : UserDefaults.standard.bool(forKey: "deepNavigation")
    @State private var showTags: Bool = UserDefaults.standard.object(forKey: "showTags") == nil ? true : UserDefaults.standard.bool(forKey: "showTags")
    @State private var hideTags: Bool = UserDefaults.standard.object(forKey: "hideTags") == nil ? true : UserDefaults.standard.bool(forKey: "hideTags")
    @State private var blockedTags: [String] = UserDefaultsManager.shared.loadBlockedTags()
    @State private var isGeneratingItemTags: Bool = false
    @State private var lastTagRefreshSignature: String = ""
    
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
            HStack {
                Spacer()
                if #available(iOS 2996.0, *) {
                    /*iOS26 GlassEffectContainer(spacing: 40.0) {
                        VStack(alignment: .center) {
                            // QR-Code anzeigen
                            //if let qrCodeImage = generateQRCodeForBox(box.id , text: box.name, standort: locationName) {
                            /*
                            Button(action: {
                                /*if let qrCodeImage = generateQRCodeForBox(item.id , text: item.name, standort: locationName) {
                                    printQRCode(qrCodeImage, count: QRCodeCopies, perPage: QRCodeNumber)
                                }*/
                            }) {
                                HStack {
                                    HStack {
                                        Image(systemName: "printer.fill.and.paper.fill")
                                            .frame(width: 38, height: 38)
                                            .foregroundStyle(Color.gray)
                                        //.padding(8)
                                        //.padding(.leading, 6)
                                    }
                                }
                                //.background(Color(UIColor.systemFill))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .cornerRadius(8) // Abgerundete Ecken
                            }
                            .disabled(true)
                             */
                            //iOS26.glassEffect()
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
                        /*
                        Button(action: {
                            /*if let qrCodeImage = generateQRCodeForBox(box.id , text: box.name, standort: locationName) {
                                printQRCode(qrCodeImage, count: QRCodeCopies, perPage: QRCodeNumber)
                            }*/
                        }) {
                            HStack {
                                HStack {
                                    Image(systemName: "printer.fill.and.paper.fill")
                                        .frame(width: 38, height: 38)
                                        .foregroundStyle(Color.gray)
                                    //.padding(8)
                                    //.padding(.leading, 6)
                                }
                            }
                            .background(Color(UIColor.systemFill))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .cornerRadius(8) // Abgerundete Ecken
                        }
                        .disabled(true)
                         */
                        //}
                        //Spacer()
                        
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
                    .frame(height: 84)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    if !item.images.isEmpty {
                        HStack {
                            let images = selectedImageOrderOption == "new" ? Array(item.images.enumerated().reversed()) : Array(item.images.enumerated())
                            
                            ForEach(images, id: \.offset) { index, imagePath in
                                if let uiImage = loadedImages[imagePath] {
                                    if pressAndHold {
                                        ZStack {
                                            // Bildcontainer
                                            Button(action: {
                                                selectedImageURL = imagePath
                                                showDetailView = true
                                            }) {
                                                if #available(iOS 296.0, *) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 84, height: 84)
                                                        .frame(maxWidth: 84, maxHeight: 84)
                                                        .cornerRadius(8)
                                                        .clipped()
                                                        .shadow(radius: 0)
                                                        .glassEffect(in: .rect(cornerRadius: 19.0))
                                                        .onTapGesture {
                                                            selectedImageURL = imagePath
                                                            showDetailView = true
                                                        }
                                                        .onDrag {
                                                            // Drag-Element mit Index als Identifikator
                                                            draggedImagePath = imagePath
                                                            addChangeImageOrder.invalidate(reason: .actionPerformed)
                                                            return NSItemProvider(object: imagePath as NSString)
                                                        }
                                                        .onDrop(
                                                            of: [UTType.text],
                                                            delegate: SortedImageReorderDropDelegate(
                                                                imagePaths: $item.images,
                                                                draggedPath: $draggedImagePath,
                                                                targetPath: imagePath,
                                                                sortOption: selectedImageOrderOption,
                                                                onReorderCompleted: persistCurrentItem
                                                            )
                                                        )
                                                } else {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 84, height: 84)
                                                        .frame(maxWidth: 84, maxHeight: 84)
                                                        .cornerRadius(8)
                                                        .clipped()
                                                        .onTapGesture {
                                                            selectedImageURL = imagePath
                                                            showDetailView = true
                                                        }
                                                        .onDrag {
                                                            // Drag-Element mit Index als Identifikator
                                                            draggedImagePath = imagePath
                                                            addChangeImageOrder.invalidate(reason: .actionPerformed)
                                                            return NSItemProvider(object: imagePath as NSString)
                                                        }
                                                        .onDrop(
                                                            of: [UTType.text],
                                                            delegate: SortedImageReorderDropDelegate(
                                                                imagePaths: $item.images,
                                                                draggedPath: $draggedImagePath,
                                                                targetPath: imagePath,
                                                                sortOption: selectedImageOrderOption,
                                                                onReorderCompleted: persistCurrentItem
                                                            )
                                                        )
                                                }
                                            }
                                            .frame(maxWidth: 84, maxHeight: 84)
                                            .clipped()
                                            if #available(iOS 26.0, *) {
                                                if isEditing {
                                                    Button(action: {
                                                        deleteIndex = index
                                                        activeAlert = .deleteImage
                                                        showAlert = true
                                                    }) {
                                                        Image(systemName: "trash.circle.fill")
                                                            .resizable()
                                                        //.foregroundStyle(Color.white.opacity(0.8))
                                                            .background(Color.black.opacity(0.5))
                                                            .clipShape(Circle())
                                                    }
                                                    .frame(width: 38, height: 38)
                                                    .padding(.top,-37)
                                                    .padding(.leading,-37)
                                                    .glassEffect()
                                                }
                                            }
                                            else {
                                                if isEditing {
                                                    Button(action: {
                                                        deleteIndex = index
                                                        activeAlert = .deleteImage
                                                        showAlert = true
                                                    }) {
                                                        Image(systemName: "trash.circle.fill")
                                                            .resizable()
                                                            .foregroundStyle(Color.white.opacity(0.8))
                                                            .background(Color.black.opacity(0.5))
                                                            .clipShape(Circle())
                                                    }
                                                    .frame(width: 38, height: 38)
                                                    .padding(.top,-37)
                                                    .padding(.leading,-37)
                                                }
                                            }
                                        }
                                        
                                        .onChange(of: item.images, initial: false){ oldValue, newValue in
                                            loadImage(for: index, path: imagePath)
                                            if let firstImagePath = (selectedImageOrderOption == "new" ? item.images.reversed().first : item.images.first) {
                                                previewImage = UserDefaultsManager.shared.loadImage(from: firstImagePath)
                                            } else {
                                                previewImage = nil // oder ein Platzhalterbild
                                            }
                                        }
                                        
                                        .onChange(of: selectedImageOrderOption, initial: false){ oldValue, newValue in
                                            if let firstImagePath = (selectedImageOrderOption == "new" ? item.images.reversed().first : item.images.first) {
                                                previewImage = UserDefaultsManager.shared.loadImage(from: firstImagePath)
                                            } else {
                                                previewImage = nil // oder ein Platzhalterbild
                                            }
                                        }
                                         
                                        .frame(width: 84, height: 84)
                                        .background(Color.secondary)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
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
                                    }
                                    else { //iOS17
                                        
                                        ZStack {
                                            // Bildcontainer
                                            Button(action: {
                                                selectedImageURL = imagePath
                                                showDetailView = true
                                            }) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 84, height: 84)
                                                    .frame(maxWidth: 84, maxHeight: 84)
                                                    .cornerRadius(8)
                                                    .clipped()
                                                    .onTapGesture {
                                                        selectedImageURL = imagePath
                                                        showDetailView = true
                                                    }
                                                    .onDrag {
                                                        // Drag-Element mit Index als Identifikator
                                                        draggedImagePath = imagePath
                                                        addChangeImageOrder.invalidate(reason: .actionPerformed)
                                                        return NSItemProvider(object: imagePath as NSString)
                                                    }
                                                    .onDrop(
                                                        of: [UTType.text],
                                                        delegate: SortedImageReorderDropDelegate(
                                                            imagePaths: $item.images,
                                                            draggedPath: $draggedImagePath,
                                                            targetPath: imagePath,
                                                            sortOption: selectedImageOrderOption,
                                                            onReorderCompleted: persistCurrentItem
                                                        )
                                                    )
                                            }
                                            .frame(maxWidth: 84, maxHeight: 84)
                                            .clipped()
                                            if isEditing {
                                                Button(action: {
                                                    deleteIndex = index
                                                    activeAlert = .deleteImage
                                                    showAlert = true
                                                }) {
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
                                        .onChange(of: item.images, initial: false){ oldValue, newValue in
                                            loadImage(for: index, path: imagePath)
                                            if let firstImagePath = (selectedImageOrderOption == "new" ? item.images.reversed().first : item.images.first) {
                                                previewImage = UserDefaultsManager.shared.loadImage(from: firstImagePath)
                                            } else {
                                                previewImage = nil // oder ein Platzhalterbild
                                            }
                                        }
                                        .onChange(of: selectedImageOrderOption, initial: false){ oldValue, newValue in
                                            if let firstImagePath = (selectedImageOrderOption == "new" ? item.images.reversed().first : item.images.first) {
                                                previewImage = UserDefaultsManager.shared.loadImage(from: firstImagePath)
                                            } else {
                                                previewImage = nil // oder ein Platzhalterbild
                                            }
                                        }
                                        .frame(width: 84, height: 84)
                                        .background(Color.secondary)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                }
                                else {
                                    if #available(iOS 296.0, *) {
                                        HStack {
                                            Spacer()
                                            // Zeige den ProgressView, falls das Bild noch geladen wird
                                            VStack {
                                                Spacer()
                                                ProgressView()
                                                    .onAppear {
                                                        loadImage(for: index, path: imagePath)
                                                    }
                                                Spacer()
                                            }
                                            Spacer()
                                        }
                                        .background(.thinMaterial)
                                        .frame(width: 84, height: 84)
                                        .glassEffect()
                                    }
                                    else {
                                        HStack {
                                            Spacer()
                                            // Zeige den ProgressView, falls das Bild noch geladen wird
                                            VStack {
                                                Spacer()
                                                ProgressView()
                                                    .onAppear {
                                                        loadImage(for: index, path: imagePath)
                                                    }
                                                Spacer()
                                            }
                                            Spacer()
                                        }
                                        .background(.thinMaterial)
                                        .frame(width: 84, height: 84)
                                    }
                                }
                            }
                            .sheet(isPresented: $showDetailView) {
                                ImageDetailView(
                                    imagePaths: $item.images,
                                    selectedImagePath: $selectedImageURL,
                                    showDetailView: $showDetailView,
                                    selectedColor: selectedColor
                                ) { deletedPath in
                                    UserDefaultsManager.shared.deleteImage(named: deletedPath)
                                    loadedImages.removeValue(forKey: deletedPath)
                                    let remainingPaths = item.images.filter { $0 != deletedPath }
                                    if let firstImagePath = (selectedImageOrderOption == "new" ? remainingPaths.reversed().first : remainingPaths.first) {
                                        previewImage = UserDefaultsManager.shared.loadImage(from: firstImagePath)
                                    } else {
                                        previewImage = nil
                                    }
                                }
                                //.interactiveDismissDisabled(true)
                            }
                        }
                        .onAppear {
                            if let firstImagePath = (selectedImageOrderOption == "new" ? item.images.reversed().first : item.images.first) {
                                previewImage = UserDefaultsManager.shared.loadImage(from: firstImagePath)
                            } else {
                                previewImage = nil // oder ein Platzhalterbild
                            }
                            pressAndHold = UserDefaultsManager.shared.loadPressAndHold()
                            selectedImageOrderOption = UserDefaults.standard.string(forKey: "imageSortingOption") ?? "new"
                            selectedColor = UserDefaultsManager.loadAccentColor()
                            
                        }
                        .popoverTip(addChangeImageOrder)
                    }
                    else {
                        if #available(iOS 296.0, *) {
                            HStack {
                                ForEach(3...5, id: \.self) { number in
                                    VStack {
                                        
                                    }
                                    .frame(width: 84, height: 84)
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
                                    .frame(width: 84, height: 84 )
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
            Form {
                Section {
                    
                    HStack {
                        if !isEditing {
                            if deepNavigation, let boxBinding = bindingForBox() {
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
                                ForEach(boxes, id: \.id) { box in
                                    Text(box.name.count > 20 ? String(box.name.prefix(17)) + "..." : box.name)
                                        .tag(box.id)
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
                        if deepNavigation, let locationBinding = bindingForLocation() {
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
            .listSectionSpacing(16.0)
            .navigationTitle(!isEditing ? "\(item.name.isEmpty ? "👻" : item.name)" : "")
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
                    } else {
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        hideKeyboard()
                        isEditing.toggle()
                    }) {
                        Image(systemName: isEditing ? "xmark" : "pencil")
                            .foregroundColor(selectedColor)
                    }
                }
            }
        }
        
        /*
        .onChange(of: item.box_uuid, initial: true) { oldValue, newValue in
            associatedBox = boxes.first { $0.id == newValue }
            if let box = associatedBox {
                associatedLocation = locations.first(where: { $0.id == box.location_uuid })
            }
        }*/
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
        .onChange(of: item.images, initial: false) { _, newValue in
            loadedImages = loadedImages.filter { newValue.contains($0.key) }
            refreshPreviewImage()
            // Reordering fires multiple intermediate updates while dragging. Persist only after drop.
            guard draggedImagePath == nil else { return }
            persistCurrentItem()
            refreshItemTagsIfNeeded()
        }
        .onChange(of: item.box_uuid, initial: true) { oldValue, newValue in
            showAlert = showAlert
            print("Change")
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
        Task(priority: .userInitiated) {
            let imageData = await MainActor.run {
                UserDefaultsManager.shared.loadImage(from: path)
            }

            if let uiImage = imageData {
                await MainActor.run {
                    self.loadedImages[path] = uiImage
                }
            } else {
                print("Fehler beim Konvertieren von imageData zu UIImage")
            }
        }
    }

    private func refreshPreviewImage() {
        if let firstImagePath = (selectedImageOrderOption == "new" ? item.images.reversed().first : item.images.first) {
            previewImage = UserDefaultsManager.shared.loadImage(from: firstImagePath)
        } else {
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
    private func createAlert(for alertType: AlertType) -> Alert {
           // switch alertType {
            //case .deleteImage:
                return Alert(
                    title: Text(NSLocalizedString("Delete image?", comment: "")),
                    message: Text(NSLocalizedString("Are you shure you want to delete this image?", comment: "")),
                    primaryButton: .destructive(Text(NSLocalizedString("Delete", comment: ""))) {
                        if let index = deleteIndex, item.images.indices.contains(index) {
                            let deletedImagePath = item.images[index]
                            UserDefaultsManager.shared.deleteImage(named: deletedImagePath)
                            item.images.remove(at: index)
                            deleteIndex = nil
                        }
                        showAlert = false
                    },
                    secondaryButton: .cancel {
                        deleteIndex = nil
                        showAlert = false
                    }
                )
                /*
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
                 */
            //}
    }

    private func bindingForBox() -> Binding<MovingBox>? {
        guard let box = associatedBox, let index = boxes.firstIndex(where: { $0.id == box.id }) else { return nil }
        return Binding(
            get: { boxes[index] },
            set: { newValue in
                boxes[index] = newValue
                saveBoxes(boxes)
                item.box_uuid = newValue.id
            }
        )
    }

    private func bindingForLocation() -> Binding<Locations>? {
        guard let location = associatedLocation, let index = locations.firstIndex(where: { $0.id == location.id }) else { return nil }
        return Binding(
            get: { locations[index] },
            set: { newValue in
                locations[index] = newValue
                saveLocations(locations)
            }
        )
    }

    private func persistCurrentItem() {
        var items = UserDefaultsManager.shared.loadItems()
        if let itemIndex = items.firstIndex(where: { $0.id == item.id }) {
            items[itemIndex] = item
        } else {
            items.append(item)
        }
        UserDefaultsManager.shared.saveItems(items)
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
            item.tags = generatedTags
            isGeneratingItemTags = false
            persistCurrentItem()
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

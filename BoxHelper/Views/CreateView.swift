import SwiftUI
import TipKit
import PhotosUI
import UIKit
import StoreKit

struct CreateView: View {
    private enum CreateFocusedField: String {
        case newItem
        case newLocation
    }

    private enum CreateNewItemInputAutofocusMode: String {
        case no
        case smart
        case yes
    }
    
    @Binding var missingUUID : UUID?
    @Environment(\.colorScheme) var colorScheme  // Zugriff auf Dark/Light Mode
    @Environment(\.scenePhase) private var scenePhase
    //@State private var showQRCodeLogo: Bool = UserDefaults.standard.object(forKey: "showQRCodeLogo") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeLogo")
    @State private var showQRCodeLocation: Bool = UserDefaults.standard.object(forKey: "showQRCodeLocation") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeLocation")
    @State private var showQRCodeName: Bool = UserDefaults.standard.object(forKey: "showQRCodeName") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeName")
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @State private var pregeneratedUUIDString: String = ""
    @State private var pregeneratedUUID: UUID? = nil
    @State private var boxUUID: UUID? = nil
    ///TAGS DEAKTIVIERT!!!!
    @State private var showTags: Bool = UserDefaults.standard.object(forKey: "showTags") == nil ? true : UserDefaults.standard.bool(forKey: "showTags")
    @State private var hideTags: Bool = UserDefaults.standard.object(forKey: "hideTags") == nil ? true : UserDefaults.standard.bool(forKey: "hideTags")
    @State private var boxName: String = " " // leerzeichen damit es nicht von Anfrang an als leer erkannt wird
    @State private var notes: String = ""
    @State private var items: [Items] = []
    @State private var missingitems: [String] = []
    @State private var newItem: String = ""
    @State private var newmissingItem: String = ""
    @State private var locations: [Locations] = loadLocations()
    @State private var selectedCategory : UUID? = loadBoxes().last?.location_uuid
    @State private var newCategory: String = ""
    @State private var categories = loadCategories() //OLD
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var showCameraPicker = false
    @State private var selectedImage: UIImage? // Für das ausgewählte Bild
    @State private var showDetailView = false // Zum Anzeigen des Sheets
    @State private var isEdditing = false
    @State private var blockedTags: [String] = UserDefaultsManager.shared.loadBlockedTags()
    @State private var addBlockedTags: [String] = []
    @State private var showActionSheet: Bool = false
    @State var isDisabled: Bool = false // form disable flag; items bleiben jetzt editierbar
    @State var isEmpty: Bool = true
    @State var height: CGFloat = 1.0
    @AppStorage("sliderValue3") private var sliderValue3: Double = 50.0
    @Environment(\.requestReview) var requestReview
    @State var tapcount = 0
    @State private var recognizedTexts: [String] = [] // Ergebnisse der Texterkennung
    @State var animationValue = 0.0
    @State var arrowuturnleft_clicked = true
    @State var textFieldColor: Color = Color(UIColor.secondarySystemGroupedBackground)
    @State var items_uuid : [UUID] = []
    @State private var showBoxNameSheme = UserDefaultsManager.shared.loadShowBoxNameSheme()
    @State private var useBoxUUIDasBoxName = UserDefaultsManager.shared.loadUseBoxUUIDasBoxName()
    @State private var showBoxNumberSheme = UserDefaultsManager.shared.loadShowBoxNumberSheme()
    @State private var boxNameSchemeIsEmpty: Bool = UserDefaults.standard.string(forKey: "boxNameScheme")?.isEmpty ?? true
    @State private var boxNameScheme = NSLocalizedString(UserDefaults.standard.string(forKey: "boxNameScheme") ?? "CreateView.Box", comment: "")
    @FocusState private var focusedField: CreateFocusedField?
    @State private var QRCodeCopies: Int = UserDefaultsManager.shared.getQRCodeCopies()
    @State private var QRCodeNumber: Int = UserDefaultsManager.shared.getQRCodeNumber()
    @State private var newLocation : Locations? = nil
    @State private var showReviewAlert : Bool = false
    @State private var loadLastInput: Bool = UserDefaults.standard.object(forKey: "loadLastInput") == nil ? true : UserDefaults.standard.bool(forKey: "loadLastInput")
    @AppStorage("saveCreateFormData") private var saveCreateFormData: Bool = true
    @State private var draftImageFileNames: [String] = []
    @State private var isLoadingCreateDraft: Bool = false
    @State private var draggedCreateImage: UIImage?
    @State private var showItemImagePicker = false
    @State private var showItemCameraPicker = false
    @State private var selectedItemPickerImages: [UIImage] = []
    @State private var pendingNewItemImageFileName: String?
    @State private var showFeedbackSheet = false
    @State private var activeItemImageTarget: CreateItemImageTarget?
    @State private var itemImageInputSource: ItemImageInputSource = .camera
    @AppStorage("createNewItemInputAutofocusMode") private var createNewItemInputAutofocusMode: String = "yes"
    private let createDraftKey = "createFormDraftV1"
    private let createDraftImagePrefix = "create_draft_"
    private let createItemDraftImagePrefix = "create_item_draft_"

    let addIntroduceBoxNaming = introduceBoxNaming()
    let addCustomizableQRCodeTip = customizableQRCodeTip()
    
    private var selectedLocationUIColor: UIColor? {
        guard let selectedCategory,
              let location = locations.first(where: { $0.id == selectedCategory }),
              let color = stringToColor(location.color) else {
            return nil
        }
        return UIColor(color)
    }

    private var pendingNewItemPreviewImage: UIImage? {
        guard let pendingNewItemImageFileName else { return nil }
        return UserDefaultsManager.shared.loadImage(from: pendingNewItemImageFileName)
    }

    private var itemSection: AnyView {
        AnyView(
            Section {
                List {
                    newItemRow

                    ForEach(items) { item in
                        existingItemRow(item)
                    }
                }
            }
        )
    }

    private var newItemRow: AnyView {
        AnyView(
            HStack {
                TextField("BoxDetailView.NewObject", text: $newItem)
                    .focused($focusedField, equals: .newItem)
                    .onSubmit {
                        addItem()
                        focusedField = .newItem
                    }
                    .frame(maxHeight: 100)
                    .disabled(isDisabled)
                    .submitLabel(.next)

                Button(action: addItem) {
                    Image(systemName: "plus")
                }
                .disabled(newItem.isEmpty || isDisabled)
            }
        )
    }

    private var missingBoxBanner: AnyView {
        AnyView(
            Group {
                if missingUUID != nil {
                    HStack {
                        Spacer()
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.blue)
                        Text("Create missing Box")
                            .foregroundStyle(Color.blue)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
        )
    }

    private var qrCodeSection: AnyView {
        let selectedLocationName = locations.first(where: { $0.id == selectedCategory })?.name ?? ""
        let currentQRCodeImage: UIImage? = {
            if let oldUUID = missingUUID {
                return generateQRCodeForBox(oldUUID, text: boxName, standort: selectedLocationName, standortColor: selectedLocationUIColor)
            }
            if let uuid = pregeneratedUUID {
                return generateQRCodeForBox(uuid, text: boxName, standort: selectedLocationName, standortColor: selectedLocationUIColor)
            }
            return nil
        }()

        return AnyView(
            Section {
                VStack(spacing: 10) {
                    TipView(addCustomizableQRCodeTip)

                    HStack(spacing: 10) {
                        Group {
                            if let qrCodeImage = currentQRCodeImage {
                                Image(uiImage: qrCodeImage)
                                    .resizable()
                                    .scaledToFit()
                                    .background(Color.white)
                                    .scaleEffect(0.92)
                                    .frame(width: 75, height: 100)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(UIColor.systemFill))
                                    .frame(width: 75, height: 100)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary, lineWidth: 2)
                        )
                        .background(Color.white)
                        .cornerRadius(8)
                        .frame(width: 75, height: 100)

                        VStack {
                            if showQRCodeName {
                                HStack {
                                    Image(systemName: boxName.isEmpty ? "xmark.circle" : "checkmark.circle.fill")
                                        .foregroundStyle(boxName.isEmpty ? Color.secondary : selectedColor)
                                    Text("CreateView.BoxTitle")
                                        .font(.caption)
                                    Spacer()
                                }
                            }

                            if showQRCodeLocation {
                                HStack {
                                    Image(systemName: selectedCategory == nil ? "xmark.circle" : "checkmark.circle.fill")
                                        .foregroundStyle(selectedCategory == nil ? Color.secondary : selectedColor)
                                    Text("CreateView.Location")
                                        .font(.caption)
                                    Spacer()
                                }
                            }

                            Spacer()

                            HStack(spacing: 8) {
                                Button {
                                    UserDefaults.standard.set(true, forKey: "openBoxQRSettingsFromCreate")
                                    NotificationCenter.default.post(name: .openSettingsFromCreate, object: nil)
                                } label: {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .frame(width: 40, height: 40)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("QR Code Settings")
                                .background(Color(UIColor.systemFill))
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                Button {
                                    guard let qrCodeImage = currentQRCodeImage else { return }
                                    printQRCode(qrCodeImage, count: QRCodeCopies, perPage: QRCodeNumber)
                                } label: {
                                    Label("Print QR Code", systemImage: "printer.fill.and.paper.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 40)
                                }
                                .buttonStyle(.plain)
                                .background(Color(UIColor.systemFill))
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .disabled(currentQRCodeImage == nil)
                            }
                        }
                        .frame(height: 100)
                    }
                    .padding(.vertical, 4)
                }
                .background { EmptyView() }
            }
        )
    }

    private var locationSection: AnyView {
        AnyView(
            Section {
                VStack {
                    if !locations.isEmpty {
                        if locations.count <= 3 {
                            Picker("", selection: $selectedCategory) {
                                ForEach(locations, id: \.id) { location in
                                    Text(location.name.count > 20 ? String(location.name.prefix(17)) + "..." : location.name)
                                        .tag(location.id)
                                }
                            }
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        } else {
                            Picker("", selection: $selectedCategory) {
                                ForEach(locations, id: \.id) { location in
                                    Text(location.name.count > 20 ? String(location.name.prefix(17)) + "..." : location.name)
                                        .tag(location.id)
                                }
                            }
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                    } else {
                        HStack {
                            Spacer()
                        }
                        .frame(height: 34)
                        .background(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                        .cornerRadius(8)
                    }

                    HStack {
                        TextField("CreateView.addLocation", text: $newCategory)
                            .focused($focusedField, equals: .newLocation)
                            .frame(maxWidth: .infinity)
                            .disabled(isDisabled)
                            .onSubmit { addCategory() }

                        Button(action: addCategory) {
                            Image(systemName: "plus")
                        }
                        .disabled(newCategory.isEmpty)
                        .disabled(isDisabled)
                        .accentColor(selectedColor)
                    }
                    .onChange(of: newCategory, initial: false) { _, _ in checkIfEmpty() }
                    .onChange(of: selectedCategory, initial: false) { _, _ in
                        checkIfEmpty()
                        if selectedCategory == nil {
                            selectedCategory = locations.last?.id
                        }
                    }
                }
            }
        )
    }

    private var notesSection: AnyView {
        AnyView(
            Section {
                VStack {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .scrollIndicators(.visible, axes: .vertical)
                        .padding(.top, 3)
                        .ignoresSafeArea(.keyboard, edges: .bottom)
                }
                .frame(minHeight: 20)
                .frame(maxHeight: 132)
            }
        )
    }

    private var identifierSection: AnyView {
        AnyView(
            Section {
                HStack {
                    if let uuid = missingUUID {
                        Text("#\(uuid.uuidString.prefix(6))")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("#\(pregeneratedUUIDString.prefix(6))")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
        )
    }

    private var createImagesSection: AnyView {
        AnyView(
            Section {
                VStack {
                    HStack {
                        VStack(spacing: 7) {
                            VStack {
                                Spacer()
                                Image(systemName: "photo.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Spacer()
                            }
                            .frame(width: 38, height: 38)
                            .background(Color(UIColor.systemFill))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .cornerRadius(8)
                            .onTapGesture {
                                showImagePicker = true
                                arrowuturnleft_clicked = true
                            }
                            .sheet(isPresented: $showImagePicker, onDismiss: {
                                refreshRecognizedTextsFromSelectedImages()
                            }) {
                                ImagePicker(selectedImages: $selectedImages)
                            }

                            VStack {
                                Spacer()
                                Image(systemName: "camera.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Spacer()
                            }
                            .frame(width: 38, height: 38)
                            .background(Color(UIColor.systemFill))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .cornerRadius(8)
                            .onTapGesture {
                                showCameraPicker = true
                                arrowuturnleft_clicked = true
                            }
                            .sheet(isPresented: $showCameraPicker, onDismiss: {
                                refreshRecognizedTextsFromSelectedImages()
                            }) {
                                CameraPicker(images: $selectedImages)
                            }
                        }

                        ScrollView(.horizontal) {
                            HStack {
                                if !selectedImages.isEmpty {
                                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                        ZStack {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .clipped()
                                                .frame(width: 84, height: 84)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                            Button(action: {
                                                removeSelectedCreateImage(at: index)
                                            }) {
                                                Image(systemName: "trash.circle.fill")
                                                    .resizable()
                                                    .frame(width: 38, height: 38)
                                                    .foregroundStyle(Color.white.opacity(0.8))
                                                    .background(Color.black.opacity(0.5))
                                                    .clipShape(Circle())
                                                    .clipped()
                                            }
                                            .padding(.top, -37)
                                            .padding(.leading, -37)
                                        }
                                    }
                                } else {
                                    ForEach(3...5, id: \.self) { _ in
                                        HStack { }
                                            .frame(width: 84, height: 84)
                                            .background(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .cornerRadius(8)
                            .frame(height: 84)
                        }
                        .cornerRadius(8)
                        if !selectedImages.isEmpty {
                            Text("\(selectedImages.count)")
                        }
                    }
                    .padding(.vertical, 8)
                }

                if showTags && !hideTags {
                    HStack {
                        if !recognizedTexts.isEmpty && !arrowuturnleft_clicked {
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
                                recognizedTexts.removeAll()
                                arrowuturnleft_clicked = false
                            }
                            .onAppear {
                                arrowuturnleft_clicked = false
                                blockedTags = UserDefaultsManager.shared.loadBlockedTags()
                            }
                        }

                        if recognizedTexts.isEmpty && selectedImages.count > 0 && !arrowuturnleft_clicked {
                            HStack {
                                Image(systemName: "text.viewfinder")
                                    .foregroundStyle(isColorTooDark(color: selectedColor) ? .white : .black)
                                    .scaleEffect(1.6)
                            }
                            .frame(width: 26, height: 26)
                            .background(selectedColor)
                            .cornerRadius(5)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(.top, 3)
                            .padding(.bottom, 3)
                            .onTapGesture {
                                arrowuturnleft_clicked = true
                                refreshRecognizedTextsFromSelectedImages()
                            }
                        }

                        if arrowuturnleft_clicked && !selectedImages.isEmpty {
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

                        if selectedImages.count == 0 && recognizedTexts.isEmpty {
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
                                if !recognizedTexts.isEmpty {
                                    ForEach(recognizedTexts, id: \.self) { text in
                                        HStack {
                                            Button {
                                                addBlockedTags.append(text)
                                                recognizedTexts.removeAll(where: { $0 == text })
                                                blockedTags = UserDefaultsManager.shared.loadBlockedTags()
                                                blockedTags.append(contentsOf: addBlockedTags)
                                                UserDefaultsManager.shared.saveBlockedTags(blockedTags)
                                                addBlockedTags.removeAll()
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
                                        .cornerRadius(5)
                                        .font(.footnote)
                                        .foregroundStyle(isColorTooDark(color: selectedColor) ? .white : .black)
                                    }
                                } else {
                                    ForEach(3...5, id: \.self) { _ in
                                        HStack { }
                                            .frame(width: 75, height: 26)
                                            .background(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                                            .cornerRadius(5)
                                            .font(.footnote)
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                        }
                        .cornerRadius(5)
                    }
                    .padding(.bottom, 5)
                }
            }
        )
    }
    
    private var createFormContent: some View {
        Form {
                /*
                 // Abschnitt für das Hinzufügen einer Kiste
                 Section {
                 TextField("CreateView.BoxTitle", text: $boxName)
                 .disabled(isDisabled)
                 .onAppear {
                 UserDefaultsManager.shared.saveLastState("create")
                 showTags = UserDefaults.standard.object(forKey: "showTags") == nil ? true : UserDefaults.standard.bool(forKey: "showTags")
                 selectedColor = UserDefaultsManager.loadAccentColor()
                 /*// Prüfe, ob es bereits einen gespeicherten Wert gibt, und lade ihn, wenn er vorhanden ist
                  if let savedBoxName = UserDefaultsManager.shared.loadBoxName() {
                  boxName = savedBoxName
                  } else {
                  // Falls kein Wert gespeichert ist, setze den Standardwert*/
                 if !isEdditing {
                 boxName = buildBoxName()
                 }
                 // }
                 }
                 .onChange(of: boxName) { // Nur ein Parameter hier
                 // Speichere den Wert bei jeder Änderung in den UserDefaults
                 isEdditing = true
                 if boxName.isEmpty {
                 textFieldColor = .red.opacity(0.3)
                 isEmpty = true
                 }
                 else{
                 textFieldColor = Color(UIColor.secondarySystemGroupedBackground)
                 isEmpty = false
                 }
                 }
                 .frame(maxWidth: .infinity)
                 }
                 .listRowBackground(textFieldColor)
                 */
                missingBoxBanner
                qrCodeSection
                locationSection
                /*
                .listRowBackground(
                    stringToColor(
                        locations.first(where: { $0.id == selectedCategory })?.color
                        ?? colorToString(Color(UIColor.secondarySystemBackground)) ?? "#ffffff"
                    ) ?? Color(UIColor.secondarySystemBackground)
                )
                */
                createImagesSection
                // Abschnitt für den Inhalt der Kiste
                itemSection
                notesSection
                identifierSection
            }
            .toolbarTitleDisplayMode(.inline)
            .listRowInsets(EdgeInsets())
            .onChange(of: saveCreateFormData, initial: false) { _, newValue in
                if newValue {
                    persistDraftImagesAndStateIfEnabled()
                } else {
                    clearCreateDraft()
                }
            }
            .onChange(of: draftFieldsAutosaveTrigger, initial: false) { _, _ in
                persistCreateDraftIfEnabled()
            }
            .onChange(of: selectedImages, initial: false) { _, _ in
                persistDraftImagesAndStateIfEnabled()
            }
            .onChange(of: selectedItemPickerImages, initial: false) { _, newValue in
                guard let pickedImage = newValue.first else { return }
                assignImageToActiveItem(pickedImage)
                selectedItemPickerImages.removeAll()
            }
            .sheet(isPresented: $showItemImagePicker, onDismiss: {
                selectedItemPickerImages.removeAll()
            }) {
                ImagePicker(selectedImages: $selectedItemPickerImages, selectionLimit: 1)
            }
            .sheet(isPresented: $showItemCameraPicker, onDismiss: {
                selectedItemPickerImages.removeAll()
            }) {
                CameraPicker(images: $selectedItemPickerImages)
            }
            .sheet(isPresented: $showFeedbackSheet) {
                FeedbackReportSheet()
            }
            /*
            .onChange(of: selectedImages, initial: false) { oldValue, newValue in
                TempImageManager.shared.save(images: newValue)
            }
            .onChange(of: selectedCategory, initial: false) { oldValue, newValue in
                //saveCreate(newValue, forKey: "selectedCategory")
            }
            .onChange(of: boxName, initial: false) { oldValue, newValue in
                //saveCreate(newValue, forKey: "boxName")
            }
            .onChange(of: items, initial: false) { oldValue, newValue in
                //saveCreate(newValue, forKey: "items")
            }
            .onChange(of: newItem, initial: false) { oldValue, newValue in
                //saveCreate(newValue, forKey: "newItem")
            }
            .onChange(of: newLocation, initial: false) { oldValue, newValue in
                //saveCreate(newValue, forKey: "newLocation")
            }
             */
            .onChange(of: scenePhase, initial: false) { _, newValue in
                guard newValue == .inactive || newValue == .background else { return }
                persistCreateFocusForSmartMode()
            }
            .onAppear {
                applyInitialCreateFocus()
                loadLastInput = UserDefaults.standard.object(forKey: "loadLastInput") == nil ? true : UserDefaults.standard.bool(forKey: "loadLastInput")
                if selectedCategory == nil {
                    selectedCategory = locations.last?.id
                }
                //showQRCodeLogo = UserDefaults.standard.object(forKey: "showQRCodeLogo") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeLogo")
                showQRCodeLocation = UserDefaults.standard.object(forKey: "showQRCodeLocation") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeLocation")
                showQRCodeName = UserDefaults.standard.object(forKey: "showQRCodeName") == nil ? true : UserDefaults.standard.bool(forKey: "showQRCodeName")
                showTags = UserDefaults.standard.object(forKey: "showTags") == nil ? true : UserDefaults.standard.bool(forKey: "showTags")
                hideTags = UserDefaults.standard.object(forKey: "hideTags") == nil ? true : UserDefaults.standard.bool(forKey: "hideTags")
                if boxName.isEmpty || newLocation == nil || selectedCategory == nil {
                    //textFieldColor = .red.opacity(0.3)
                    checkIfEmpty()
                }
                else{
                //textFieldColor = Color(UIColor.secondarySystemGroupedBackground)
                    checkIfEmpty()
                }
            }
            /*
            .sheet(isPresented: $showActionSheet) {
                ActionSheetView()
            }
             */
            .toolbar {
                /*
                ToolbarItem(placement: .topBarTrailing){
                    Button {
                        showActionSheet = true
                    } label: {
                        if #available(iOS 18.0, *) {
                            Image("custom.percent.seal.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(
                                    Color.white,
                                    Color.red
                                )
                                .symbolEffect(.bounce.up.byLayer, options: .nonRepeating)
                        } else {
                            Image("custom.percent.seal.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(
                                    Color.white,
                                    Color.red
                                )
                        }
                    }
                }
                 */
                ToolbarItem(placement: .topBarLeading) {
                    if (Locale.current.language.languageCode == "de" || Locale.current.language.languageCode == "en") && !UserDefaults.standard.bool(forKey: "Bewertet") {
                        HStack {
                            Button("♥") {
                                showReviewAlert = true
                            }
                            .foregroundColor(.red)
                            .alert("Zeig, dass du die App nutzt!", isPresented: $showReviewAlert) {
                                Button("Bewerten") {
                                    UserDefaults.standard.set(true, forKey: "Bewertet")
                                    if let url = URL(string: "https://apps.apple.com/de/app/boxhelper/id6737223705?action=write-review") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                Button("Später", role: .cancel) { }
                            } message: {
                                Text("Ich entwickle BoxHelper ohne In-App-Tracking, Werbung oder externe Finanzierung.\n\nDamit ich weiß, ob sich der Aufwand, die laufenden Kosten und meine Zeit lohnen, bin ich auf dein Feedback angewiesen.")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFeedbackSheet = true
                    } label: {
                        Image(systemName: "flag")
                    }
                    .accessibilityLabel("Open feedback form")
                }
                ToolbarItem(placement: .principal){
                    HStack {
                        TextField("CreateView.BoxTitle", text: $boxName)
                            .popoverTip(addIntroduceBoxNaming)
                            .font(.headline)
                            .multilineTextAlignment(.center) // Zentriert den Text
                            .padding(5) // Innenabstand
                            .padding(.top, -1)
                            .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : .white) // Hintergrundfarbe
                            .cornerRadius(19) // Ecken abrunden
                            .foregroundColor(colorScheme == .dark ? .white : .black) // Textfarbe
                            .frame(width: UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac ? UIScreen.main.bounds.width / 5 : UIScreen.main.bounds.width / 2.5)
                            .onChange(of: boxName, initial: false) { oldValue, newValue in
                                checkIfEmpty()
                            }
                    }
                }
            }
            .listSectionSpacing(16.0)
            .scaleEffect(height)
            .animation(.easeInOut(duration: 0.5), value: height) // Animation hinzufügen
            //.frame(maxHeight: height)
            .scrollDismissesKeyboard(.immediately)
            .onAppear {
                //selectedImages = TempImageManager.shared.load()
                locations = loadLocations()
                QRCodeNumber = UserDefaultsManager.shared.getQRCodeNumber()
                QRCodeCopies = UserDefaultsManager.shared.getQRCodeCopies()
                selectedColor = UserDefaultsManager.loadAccentColor()
                UserDefaultsManager.shared.saveLastState("create")
                itemImageInputSource = ItemImageInputSource(rawValue: UserDefaultsManager.shared.loadCreateItemImageInputSource()) ?? .camera
                boxNameSchemeIsEmpty = UserDefaults.standard.string(forKey: "boxNameScheme")?.isEmpty ?? true
                boxNameScheme = NSLocalizedString(UserDefaults.standard.string(forKey: "boxNameScheme") ?? "CreateView.Box", comment: "")
                showBoxNameSheme = UserDefaultsManager.shared.loadShowBoxNameSheme()
                useBoxUUIDasBoxName = UserDefaultsManager.shared.loadUseBoxUUIDasBoxName()
                showBoxNumberSheme = UserDefaultsManager.shared.loadShowBoxNumberSheme()
                if useBoxUUIDasBoxName {
                    if let uuid = missingUUID {
                        boxName = "#"+uuid.uuidString.prefix(6)
                        print("Missing UUID: \(uuid)")
                    }
                    else{
                        if let pregeneratedUUIDString = UserDefaults.standard.string(forKey: "pregeneratedUUID") {
                            boxName = "#"+pregeneratedUUIDString.prefix(6)
                            print("pregeneratedUUIDString UUID: \(pregeneratedUUIDString)")
                        }
                        //print("ELSEEEEEEEE")
                    }
                }
                else{
                    //print("ELSEEEEEEEE")
                    boxName = buildBoxName()
                    categories = loadCategories()
                }
                if missingUUID != nil {
                    print("missing UUID: \(missingUUID!)")
                    boxUUID = missingUUID
                }
                else{
                    print("missingUUID: nil")
                    
                }
                if let savedUUIDString = UserDefaults.standard.string(forKey: "pregeneratedUUID"),
                   let savedUUID = UUID(uuidString: savedUUIDString) {
                    pregeneratedUUID = savedUUID
                    pregeneratedUUIDString = savedUUIDString
                    //print("existing UUID: \(pregeneratedUUID.description)")
                } else {
                    let newUUID = UUID()
                    pregeneratedUUID = newUUID
                    UserDefaults.standard.set(newUUID.uuidString, forKey: "pregeneratedUUID")
                    pregeneratedUUIDString = newUUID.uuidString
                    //print("generated new UUID: \(pregeneratedUUIDString.description)")
                }
                loadCreateDraftIfNeeded()
            }
            .toolbar {
                //ios26
                ToolbarItem(placement: .bottomBar) {
                    if #available(iOS 26.0, *) {
                        
                    }
                    else {
                        Button(action: {
                            if !boxName.isEmpty && !isEmpty {
                                isDisabled = true
                                saveBox()
                                missingUUID = nil
                                Task{ await introduceBoxNaming.saveBoxEvent.donate()}
                                tapcount += 1
                                if tapcount == 2 {
                                    if let lastRequest = UserDefaults.standard.object(forKey: "lastAppReviewRequestDate") as? Date {
                                        let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequest, to: Date()).day ?? 0
                                        if daysSinceLastRequest >= 30 {
                                            requestAppReview()
                                            UserDefaults.standard.set(Date(), forKey: "lastAppReviewRequestDate")
                                        }
                                    } else {
                                        // Erster Aufruf, wenn noch kein Datum gespeichert ist
                                        requestAppReview()
                                        UserDefaults.standard.set(Date(), forKey: "lastAppReviewRequestDate")
                                    }
                                }
                            }
                            else{
                                isEmpty = true
                            }
                            
                        }) {
                            HStack{
                                Image(systemName: "square.and.arrow.down")
                                Text("CreateView.saveBox")
                            }
                        }
                        .accentColor(selectedColor)
                        .disabled((isDisabled || isEmpty))
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if #available(iOS 26.0, *) {
                    HStack {
                        Button(action: {
                            if !boxName.isEmpty && !isEmpty {
                                isDisabled = true
                                saveBox()
                                missingUUID = nil
                                Task{ await introduceBoxNaming.saveBoxEvent.donate()}
                                tapcount += 1
                                if tapcount == 5 {
                                    if let lastRequest = UserDefaults.standard.object(forKey: "lastAppReviewRequestDate") as? Date {
                                        let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequest, to: Date()).day ?? 0
                                        if daysSinceLastRequest >= 30 {
                                            requestAppReview()
                                            UserDefaults.standard.set(Date(), forKey: "lastAppReviewRequestDate")
                                        }
                                    } else {
                                        // Erster Aufruf, wenn noch kein Datum gespeichert ist
                                        requestAppReview()
                                        UserDefaults.standard.set(Date(), forKey: "lastAppReviewRequestDate")
                                    }
                                }
                            }
                            else{
                                isEmpty = true
                            }
                            
                        }) {
                            HStack{
                                Image(systemName: "square.and.arrow.down")
                                Text("CreateView.saveBox")
                            }
                            .padding(10)
                        }
                        //.disabled(selectedBoxes.isEmpty)
                        .glassEffect()
                        .accentColor(selectedColor)
                        .disabled((isDisabled || isEmpty))
                        /*
                        Button(action: {
                            showAlert = true
                        }) {
                            Image(systemName: "trash")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .padding(10) // Damit die Fläche groß genug ist
                                .foregroundColor(selectedBoxes.isEmpty ? .gray : .red)
                            
                        }
                        .disabled(selectedBoxes.isEmpty)
                        .glassEffect()
                         */
                    }
                    //.background(.ultraThinMaterial)
                    //.ignoresSafeArea(.all , edges: .all)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    //.background(.ultraThinMaterial)
                    /*.clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(radius: 4)
                     */
                    //.transition(.move(edge: .bottom).combined(with: .opacity))
                    //.animation(.easeInOut, value: isEditing)
                }
        }
    }

    var body: some View {
        NavigationView {
            createFormContent
        }
        .onChange(of: missingUUID, initial: false) { oldValue, newValue in
            if useBoxUUIDasBoxName, let uuid = newValue {
                boxName = "#" + uuid.uuidString.prefix(6)
                print("SET BOXNAME: \(boxName)")
            }
        }
        .onChange(of: boxName, initial: false) { oldValue, newValue in
            checkIfEmpty()
        }
    }

    private var draftFieldsAutosaveTrigger: String {
        let itemSignature = items.map { item in
            "\(item.id.uuidString)|\(item.name)|\(item.isFragile)|\(item.isHeavy)|\(item.images.first ?? "")"
        }.joined(separator: ";")
        let missingItemsSignature = missingitems.joined(separator: "|")
        let tagsSignature = recognizedTexts.joined(separator: "|")
        return [
            boxName,
            notes,
            selectedCategory?.uuidString ?? "",
            newCategory,
            itemSignature,
            missingItemsSignature,
            newItem,
            pendingNewItemImageFileName ?? "",
            newmissingItem,
            tagsSignature
        ].joined(separator: "||")
    }
    /*
    func printQRCode(_ qrCodeImage: UIImage) {
        let printController = UIPrintInteractionController.shared
        printController.delegate = nil
        
        printController.printingItem = qrCodeImage
        
        // Zeige den Druckdialog an
        printController.present(animated: true, completionHandler: nil)
    }
     */
    
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
        if safePerPage != 8 {
            UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
        }

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
            } else if safePerPage == 8 {
                struct AveryLayout {
                    let rows: Int
                    let columns: Int
                    let labelSize: CGSize
                    let marginTop: CGFloat
                    let marginLeft: CGFloat
                    let horizontalSpacing: CGFloat
                    let verticalSpacing: CGFloat
                    let rotateImage: Bool
                }
                let AveryLayout4782 = AveryLayout(
                    rows: 4,
                    columns: 2,
                    labelSize: CGSize(width: (97.0*2.3), height: (67.7*2.3)),
                    marginTop: 55.0,
                    marginLeft: 45.84,
                    horizontalSpacing: 60.08,
                    verticalSpacing: 37,
                    rotateImage: true
                )

                let layout = AveryLayout4782
                let safeCount2 = max(count, 1)
                let perPage = layout.rows * layout.columns
                let totalPages = Int(ceil(Double(safeCount2) / Double(perPage)))

                let pageWidth: CGFloat = 595.0
                let pageHeight: CGFloat = 842.0
                let pdfData = NSMutableData()
                let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
                UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)

                func createFittedImage2(from image: UIImage, in size: CGSize, rotate90: Bool = false) -> UIImage {
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

                var printed = 0

                for _ in 0..<totalPages {
                    UIGraphicsBeginPDFPageWithInfo(pageRect, nil)

                    for row in 0..<layout.rows {
                        for col in 0..<layout.columns {
                            if printed >= safeCount2 { break }

                            let x = layout.marginLeft + CGFloat(col) * (layout.labelSize.width + layout.horizontalSpacing)
                            let y = layout.marginTop + CGFloat(row) * (layout.labelSize.height + layout.verticalSpacing)
                            let frame = CGRect(x: x, y: y, width: layout.labelSize.width, height: layout.labelSize.height)

                            let fittedImage = createFittedImage2(from: qrCodeImage, in: frame.size, rotate90: layout.rotateImage)
                            fittedImage.draw(in: frame)

                            printed += 1
                        }
                    }
                }

                UIGraphicsEndPDFContext()

                let printController = UIPrintInteractionController.shared

                printController.printingItem = pdfData
                printController.present(animated: true, completionHandler: nil)
                
            } else {
                // Standard-Layout wie vorher
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
        if safePerPage != 8 {
            UIGraphicsEndPDFContext()
            printController.printingItem = pdfData
            printController.present(animated: true, completionHandler: nil)
        }
    }
    func printQRCode_1(_ qrCodeImage: UIImage, count: Int, perPage: Int) {
        //let safeCount = count > 0 ? count : 1

        let printController = UIPrintInteractionController.shared
        printController.delegate = nil

        let pageWidth: CGFloat = 595.0
        let pageHeight: CGFloat = 842.0
        let margin: CGFloat = 28.35
        let contentWidth = pageWidth - 2 * margin
        let contentHeight = pageHeight - 2 * margin
        let contentSize = CGSize(width: contentWidth, height: contentHeight)
        
        func createFittedImage(from image: UIImage, in size: CGSize, rotate90: Bool = false) -> UIImage {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: size, format: format)

            return renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))

                let imageToDraw = rotate90 ? UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: .right) : image

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

        let safePerPage = perPage > 0 ? perPage : 1
        let pages = Int(ceil(Double(count) / Double(safePerPage)))

        var printed = 0
        for _ in 0..<pages {
            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)

            if perPage == 1 {
                // Zentriert 1x
                let fittedImage = createFittedImage(from: qrCodeImage, in: contentSize)
                fittedImage.draw(in: CGRect(x: margin, y: margin, width: contentWidth, height: contentHeight))
                printed += 1
            } else if perPage == 2 {
                // Zwei rotierte QR-Codes übereinander
                let halfHeight = contentHeight / 2
                for i in 0..<2 where printed < count {
                    let originY = margin + CGFloat(i) * halfHeight
                    let imageFrame = CGRect(x: margin, y: originY, width: contentWidth, height: halfHeight)
                    let fittedImage = createFittedImage(from: qrCodeImage, in: imageFrame.size, rotate90: true)
                    fittedImage.draw(in: imageFrame)
                    printed += 1
                }
            } else {
                // Raster für 3 oder mehr pro Seite
                let cols = Int(ceil(sqrt(Double(perPage))))
                let rows = Int(ceil(Double(perPage) / Double(cols)))
                let itemWidth = contentWidth / CGFloat(cols)
                let itemHeight = contentHeight / CGFloat(rows)

                for row in 0..<rows {
                    for col in 0..<cols {
                        if printed >= count { break }
                        let x = margin + CGFloat(col) * itemWidth
                        let y = margin + CGFloat(row) * itemHeight
                        let frame = CGRect(x: x, y: y, width: itemWidth, height: itemHeight)
                        let fittedImage = createFittedImage(from: qrCodeImage, in: frame.size)
                        fittedImage.draw(in: frame)
                        printed += 1
                    }
                }
            }
        }

        UIGraphicsEndPDFContext()

        printController.printingItem = pdfData
        printController.present(animated: true, completionHandler: nil)
    }
    func printQRCode_old(_ qrCodeImage: UIImage, count: Int) {
        let printController = UIPrintInteractionController.shared
        printController.delegate = nil

        let pageWidth: CGFloat = 595.0
        let pageHeight: CGFloat = 842.0
        let margin: CGFloat = 28.35 // 1 cm in pt
        let contentWidth = pageWidth - 2 * margin
        let contentHeight = pageHeight - 2 * margin
        let contentSize = CGSize(width: contentWidth, height: contentHeight)
        
        // Hilfsfunktion zum Einpassen des QR-Codes in den Contentbereich
        func createFittedImage(from image: UIImage, in size: CGSize) -> UIImage {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1 // Für 72 dpi, passend zum PDF-Kontext
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            
            return renderer.image { context in
                // Hintergrund optional weiß
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                
                let imageSize = image.size
                let widthRatio = size.width / imageSize.width
                let heightRatio = size.height / imageSize.height
                let scale = min(widthRatio, heightRatio)
                
                let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                let origin = CGPoint(
                    x: (size.width - scaledSize.width) / 2,
                    y: (size.height - scaledSize.height) / 2
                )
                image.draw(in: CGRect(origin: origin, size: scaledSize))
            }
        }

        // Erstelle das PDF
        let pdfData = NSMutableData()
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
        let fittedImage = createFittedImage(from: qrCodeImage, in: contentSize)
        
        for _ in 0..<count {
            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
            
            // Zeichne das vorbereitete Bild exakt im Content-Bereich
            fittedImage.draw(in: CGRect(x: margin, y: margin, width: contentWidth, height: contentHeight))
        }
        UIGraphicsEndPDFContext()
        
        printController.printingItem = pdfData
        printController.present(animated: true, completionHandler: nil)
    }
    
    // Funktion zum Hinzufügen einer neuen Kategorie
    func addCategory() {
        sanitizeCreateInputBeforeMutation()

        if let color = colorToString(randomColor()) {
            if !newCategory.isEmpty && !categories.contains(newCategory) {
                newLocation = Locations(id: UUID(), name: newCategory, color: color)
                if let newLocation = newLocation {
                    locations.append(newLocation)
                    if let firstLocation = locations.last {
                        selectedCategory = firstLocation.id
                        newCategory = ""
                    }
                    
                    
                }
            }
        }
        saveLocations(locations)
    }
    
    private func checkIfEmpty() {
        if (newCategory.isEmpty && selectedCategory == nil) || boxName.isEmpty {
            isEmpty = true
        } else {
            isEmpty = false
        }
    }

    private func addItem() {
        sanitizeCreateInputBeforeMutation()

        if !newItem.isEmpty {
            let itemImageFileNames = pendingNewItemImageFileName.map { [$0] } ?? []
            let newUUID = UUID()
            if let uuid = missingUUID {
                items_uuid.append(newUUID)
                items.append(Items(id: newUUID, name: newItem, box_uuid: uuid, images: itemImageFileNames))
                newItem = ""
            }
            else{
                items_uuid.append(newUUID)
                items.append(Items(id: newUUID, name: newItem, box_uuid: UUID(uuidString: pregeneratedUUIDString) ?? UUID(), images: itemImageFileNames))
                newItem = ""
            }
            pendingNewItemImageFileName = nil
            refreshTagsForItem(withID: newUUID)
        }
    }
    private func addmissingItem() {
        sanitizeCreateInputBeforeMutation()

        if !newmissingItem.isEmpty {
            missingitems.append(newmissingItem)
            newmissingItem = ""
        }
    }
    
    private func removeItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        items_uuid.remove(atOffsets: offsets)
        hideKeyboard()  // Blendet die Tastatur aus
    }

    private func saveItems(_ itemsToSave: [Items]) {
        //withAnimation(.easeInOut(duration: 1)) {
            height = 0.8
        //}
        guard !boxName.isEmpty else { return }
        print("Aktuelle Items vor dem Speichern: \(itemsToSave)")
        var allitems: [Items] = UserDefaultsManager.shared.loadItems()
        allitems.append(contentsOf: itemsToSave)
        UserDefaultsManager.shared.saveItems(allitems)
    }
    private func saveBox() {
        sanitizeCreateInputBeforeMutation()

        if selectedCategory != nil && !boxName.isEmpty || !newCategory.isEmpty && !boxName.isEmpty {
            // Zuerst die Animation starten, um die Höhe auf 0 zu setzen
            withAnimation(.easeInOut(duration: 1)) {
                height = 0.3
            }
            addCategory()
            //var dataManager = DataManager(boxes: [], itemsDatabase: [], locationsDatabase: [])
            //dataManager.migrateLocationsToNewModel()
            addItem()
            guard !boxName.isEmpty else { return }
            let finalizedItems = finalizeDraftImages(for: items)
            
            print("Aktuelle Items vor dem Speichern: \(finalizedItems)")
            saveItems(finalizedItems)
            saveLocations(locations)
            // Speichere die Bilder und sammle die Dateinamen
            var imageNames: [String] = []
            for image in selectedImages {
                let fileName = "\(UUID().uuidString).jpg" // Einzigartiger Dateiname
                
                if let compressedImageData = image.compressImage() {
                    if let fileURL = UserDefaultsManager.shared.saveImage(compressedImageData, withName: fileName) {
                        imageNames.append(fileURL.lastPathComponent)
                    }
                }
            }
            print("selectCategory: \(String(describing: selectedCategory))")
            
            // Wenn missingUUID nil ist neue UUID benutzen
            if missingUUID == nil {
                boxUUID = pregeneratedUUID
            }
            else{
                if !missingUUID!.uuidString.isEmpty {
                    boxUUID = missingUUID
                }
            }
            
            
            if let UUID = boxUUID {
                if let selectedCategory = selectedCategory {
                    // Erstelle das neue MovingBox mit der angegebenen UUID
                    let normalizedNotes = notes.isEmpty ? nil : notes
                    let newBox = MovingBox(
                        id: UUID,
                        name: boxName,
                        items: [],
                        images: imageNames,
                        category: "",
                        location_uuid: selectedCategory,
                        color: "",
                        tags: recognizedTexts,
                        notes: normalizedNotes
                    )
                    var boxes = UserDefaultsManager.shared.loadBoxes() // Lade bereits gespeicherte Boxen
                    boxes.append(newBox) // Neue Box hinzufügen
                    print("uuid: \(String(describing: UUID.debugDescription))")
                    print("Speichere Kiste: \(newBox.name) mit Items: \(newBox.items)")
                    print(imageNames)
                    
                    UserDefaultsManager.shared.saveBoxes(boxes) // Speichere die aktualisierte Liste der Boxen
                    UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "lastBoxID") + 1, forKey: "lastBoxID") //setze die neue Boxnummer
                    //Eingabefelder zurücksetzen & namen abrufen
                    showBoxNameSheme = UserDefaultsManager.shared.loadShowBoxNameSheme()
                    showBoxNumberSheme = UserDefaultsManager.shared.loadShowBoxNumberSheme()
                    boxNameSchemeIsEmpty = UserDefaults.standard.string(forKey: "boxNameScheme")?.isEmpty ?? true
                    boxNameScheme = NSLocalizedString(UserDefaults.standard.string(forKey: "boxNameScheme") ?? "CreateView.Box", comment: "")
                    items = []
                    newItem = ""
                    missingitems = []
                    newmissingItem = ""
                    notes = ""
                    recognizedTexts = []
                    items_uuid = []
                    pendingNewItemImageFileName = nil
                    missingUUID = nil
                }
                else {
                    print("Fehler beim Wählen der Kategorie")
                }
            }
            else {
                print("Fehler beim Erstellen der UUID")
            }
            
            //Nach dem Speichern eine neue UUID für die nächste Kiste erstellen
            let newUUID = UUID()
            pregeneratedUUID = newUUID
            UserDefaults.standard.set(newUUID.uuidString, forKey: "pregeneratedUUID")
            pregeneratedUUIDString = newUUID.uuidString
            
            selectedCategory = loadBoxes().last?.location_uuid ?? nil
            selectedImages.removeAll() // Bilder nach dem Speichern löschen
            clearCreateDraft()
            categories = loadCategories()
            if useBoxUUIDasBoxName {
                if let uuid = boxUUID {
                    boxName = "#"+uuid.uuidString.prefix(6)
                }
                if let uuid = missingUUID {
                    boxName = "#"+uuid.uuidString.prefix(6)
                }
                else{
                    boxName = "#"+pregeneratedUUIDString.prefix(6)
                }
            }
            else{
                boxName = buildBoxName()
                categories = loadCategories()
            }
            //Animation beenden
            withAnimation(.easeInOut(duration: 1)) {
                height = 1.0
            }
            isDisabled = false
        }
        else {
            isEmpty = true
        }
    }

    private struct CreateFormDraft: Codable {
        var boxName: String
        var items: [Items]
        var missingitems: [String]
        var newItem: String
        var pendingNewItemImageFileName: String?
        var newmissingItem: String
        var selectedCategory: UUID?
        var newCategory: String
        var recognizedTexts: [String]
        var notes: String?
        var imageFileNames: [String]
    }

    private func persistCreateDraftIfEnabled() {
        guard saveCreateFormData, !isLoadingCreateDraft else { return }
        let draft = CreateFormDraft(
            boxName: boxName,
            items: items,
            missingitems: missingitems,
            newItem: newItem,
            pendingNewItemImageFileName: pendingNewItemImageFileName,
            newmissingItem: newmissingItem,
            selectedCategory: selectedCategory,
            newCategory: newCategory,
            recognizedTexts: recognizedTexts,
            notes: notes,
            imageFileNames: draftImageFileNames
        )
        saveCreate(draft, forKey: createDraftKey)
    }

    private func persistDraftImagesAndStateIfEnabled() {
        guard saveCreateFormData, !isLoadingCreateDraft else { return }
        deleteDraftImages(named: draftImageFileNames)
        var fileNames: [String] = []
        for image in selectedImages {
            let fileName = "\(createDraftImagePrefix)\(UUID().uuidString).jpg"
            if let compressedImageData = image.compressImage(),
               let fileURL = UserDefaultsManager.shared.saveImage(compressedImageData, withName: fileName) {
                fileNames.append(fileURL.lastPathComponent)
            }
        }
        draftImageFileNames = fileNames
        persistCreateDraftIfEnabled()
    }

    private func loadCreateDraftIfNeeded() {
        guard saveCreateFormData else { return }
        guard missingUUID == nil else { return }
        guard let draft = loadCreate(CreateFormDraft.self, forKey: createDraftKey) else { return }

        isLoadingCreateDraft = true
        boxName = draft.boxName
        items = draft.items
        missingitems = draft.missingitems
        newItem = draft.newItem
        pendingNewItemImageFileName = draft.pendingNewItemImageFileName
        newmissingItem = draft.newmissingItem
        selectedCategory = draft.selectedCategory
        newCategory = draft.newCategory
        recognizedTexts = draft.recognizedTexts
        notes = draft.notes ?? ""
        draftImageFileNames = draft.imageFileNames
        selectedImages = draft.imageFileNames.compactMap { UserDefaultsManager.shared.loadImage(from: $0) }
        isLoadingCreateDraft = false
    }

    private func clearCreateDraft() {
        deleteDraftImages(named: draftImageFileNames)
        deleteDraftImages(named: collectCreateItemDraftImageFileNames())
        draftImageFileNames.removeAll()
        pendingNewItemImageFileName = nil
        UserDefaults.standard.removeObject(forKey: createDraftKey)
    }

    private func applyInitialCreateFocus() {
        let focusMode = CreateNewItemInputAutofocusMode(rawValue: createNewItemInputAutofocusMode) ?? .yes
        let targetField: CreateFocusedField?

        switch focusMode {
        case .yes:
            targetField = .newItem
        case .no:
            targetField = nil
        case .smart:
            let lastFocusedField = UserDefaultsManager.shared.loadCreateLastFocusedField()

            if lastFocusedField == CreateFocusedField.newItem.rawValue {
                targetField = .newItem
            } else if UserDefaultsManager.shared.loadBoxes().isEmpty {
                targetField = .newLocation
            } else {
                targetField = nil
            }
        }

        // Delay the focus assignment until the view hierarchy has finished its first layout pass.
        DispatchQueue.main.async {
            focusedField = targetField
        }
    }

    private func persistCreateFocusForSmartMode() {
        let storedFocus: String

        if focusedField == .newItem {
            storedFocus = CreateFocusedField.newItem.rawValue
        } else {
            storedFocus = "none"
        }

        UserDefaultsManager.shared.saveCreateLastFocusedField(storedFocus)
    }

    private func deleteDraftImages(named fileNames: [String]) {
        for fileName in fileNames where fileName.hasPrefix(createDraftImagePrefix) || fileName.hasPrefix(createItemDraftImagePrefix) {
            UserDefaultsManager.shared.deleteImage(named: fileName)
        }
    }

    private func collectCreateItemDraftImageFileNames() -> [String] {
        let itemImages = items.flatMap(\.images)
        let pendingImages = [pendingNewItemImageFileName].compactMap { $0 }
        return itemImages
            .filter { $0.hasPrefix(createItemDraftImagePrefix) }
            + pendingImages.filter { $0.hasPrefix(createItemDraftImagePrefix) }
    }

    private func finalizeDraftImages(for items: [Items]) -> [Items] {
        items.map { item in
            guard let imageName = item.images.first else { return item }
            guard imageName.hasPrefix(createItemDraftImagePrefix) else {
                return withSingleImageLimit(item)
            }

            let newFileName = "\(UUID().uuidString).jpg"
            guard let duplicatedURL = UserDefaultsManager.shared.duplicateImage(named: imageName, to: newFileName) else {
                return withSingleImageLimit(item)
            }

            var finalizedItem = withSingleImageLimit(item)
            finalizedItem.images = [duplicatedURL.lastPathComponent]
            UserDefaultsManager.shared.deleteImage(named: imageName)
            return finalizedItem
        }
    }

    private func withSingleImageLimit(_ item: Items) -> Items {
        var limitedItem = item
        limitedItem.images = Array(item.images.prefix(1))
        return limitedItem
    }

    private func firstImage(for item: Items) -> UIImage? {
        guard let imageName = item.images.first else { return nil }
        return UserDefaultsManager.shared.loadImage(from: imageName)
    }

    private func openImagePicker(for target: CreateItemImageTarget) {
        activeItemImageTarget = target
        selectedItemPickerImages.removeAll()

        switch itemImageInputSource {
        case .none:
            activeItemImageTarget = nil
        case .camera:
            showItemCameraPicker = true
        case .gallery:
            showItemImagePicker = true
        }
    }

    private func assignImageToActiveItem(_ image: UIImage) {
        guard let activeItemImageTarget else { return }

        let fileName = "\(createItemDraftImagePrefix)\(UUID().uuidString).jpg"
        guard let compressedImageData = image.compressImage(),
              let fileURL = UserDefaultsManager.shared.saveImage(compressedImageData, withName: fileName) else {
            self.activeItemImageTarget = nil
            return
        }

        switch activeItemImageTarget {
        case .pendingNewItem:
            if let existingFileName = pendingNewItemImageFileName {
                deleteDraftImages(named: [existingFileName])
            }
            pendingNewItemImageFileName = fileURL.lastPathComponent
        case let .existingItem(itemID):
            replaceImage(for: itemID, with: fileURL.lastPathComponent)
        }

        self.activeItemImageTarget = nil
        persistCreateDraftIfEnabled()
    }

    private func replaceImage(for itemID: UUID, with fileName: String) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            deleteDraftImages(named: [fileName])
            return
        }

        if let existingFileName = items[index].images.first {
            deleteDraftImages(named: [existingFileName])
        }

        items[index].images = [fileName]
        refreshTagsForItem(withID: itemID)
    }

    private func removePendingNewItemImage() {
        guard let pendingNewItemImageFileName else { return }
        deleteDraftImages(named: [pendingNewItemImageFileName])
        self.pendingNewItemImageFileName = nil
        persistCreateDraftIfEnabled()
    }

    private func removeImage(from item: Items) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let imageNames = items[index].images
        items[index].images.removeAll()
        items[index].tags = []
        deleteDraftImages(named: imageNames)
        persistCreateDraftIfEnabled()
    }

    private func removeItem(_ item: Items) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let imageNames = items[index].images
        items.remove(at: index)
        deleteDraftImages(named: imageNames)
        persistCreateDraftIfEnabled()
    }

    // Keeps item tags aligned with the single stored item image in the Create draft.
    private func refreshTagsForItem(withID itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        let imagePaths = items[index].images

        guard !imagePaths.isEmpty else {
            items[index].tags = []
            persistCreateDraftIfEnabled()
            return
        }

        generateAutomaticTagsIfEnabled(fromImagePaths: imagePaths) { generatedTags in
            guard let refreshedIndex = items.firstIndex(where: { $0.id == itemID }) else { return }
            items[refreshedIndex].tags = generatedTags
            persistCreateDraftIfEnabled()
        }
    }

    private func refreshRecognizedTextsFromSelectedImages() {
        guard showTags else { return }

        let imagesToProcess = selectedImages
        processImages(imagesToProcess) { recognizedTexts in
            if !selectedImages.isEmpty {
                self.recognizedTexts = recognizedTexts
            } else {
                self.recognizedTexts.removeAll()
            }
            arrowuturnleft_clicked = false
        }
    }

    private func removeSelectedCreateImage(at index: Int) {
        guard selectedImages.indices.contains(index) else {
            recognizedTexts = []
            arrowuturnleft_clicked = false
            return
        }

        selectedImages.remove(at: index)

        if showTags {
            refreshRecognizedTextsFromSelectedImages()
        } else {
            recognizedTexts = []
            arrowuturnleft_clicked = false
        }
    }

    func requestAppReview() {
        // Hole die aktive UIWindowScene
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
    
    private func buildBoxName() -> String {
        let namePart: String = {
            guard showBoxNameSheme else { return "" }
            let scheme = boxNameScheme.isEmpty ? "CreateView.Box" : boxNameScheme
            return NSLocalizedString(scheme, comment: "")
        }()
        let isSchemeEmpty = boxNameSchemeIsEmpty || boxNameScheme.isEmpty
        let spacer = (isSchemeEmpty && showBoxNameSheme && showBoxNumberSheme) ? " " : ""
        let numberPart = showBoxNumberSheme ? generateBoxName() : ""
        return namePart + spacer + numberPart
    }
    // Toggle für isFragile
    private func toggleIsFragile(for item: Items) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isFragile.toggle() // Toggle den Zustand von isFragile
            //UserDefaultsManager.shared.saveItems(items) // Speichere die geänderten Items
        }
    }
    
    // Toggle für isHeavy
    private func toggleIsHeavy(for item: Items) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isHeavy.toggle() // Toggle den Zustand von isFragile
            //UserDefaultsManager.shared.saveItems(items) // Speichere die geänderten Items
        }
    }

    private func bindingForItemName(_ item: Items) -> Binding<String>? {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return nil }
        return Binding(
            get: { items[index].name },
            set: { items[index].name = $0 }
        )
    }

    private func existingItemRow(_ item: Items) -> AnyView {
        AnyView(
            HStack {
                if itemImageInputSource != .none {
                    let itemHasImage = firstImage(for: item) != nil
                    itemImageButton(
                        previewImage: firstImage(for: item),
                        accessibilityLabel: itemHasImage ? "Delete image for \(item.name)" : "Add image for \(item.name)",
                        showsDeleteOverlay: itemHasImage
                    ) {
                        if itemHasImage {
                            removeImage(from: item)
                        } else {
                            openImagePicker(for: .existingItem(item.id))
                        }
                    }
                }

                if let binding = bindingForItemName(item) {
                    TextField("👻", text: binding)
                        .disabled(false)
                } else {
                    Text(item.name)
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

                Menu {
                    Section {
                        Button(action: {
                            toggleIsFragile(for: item)
                        }) {
                            Label(item.isFragile ? "Not fragile" : "Fragile", image: item.isFragile ? "custom.wineglass.slash" : "custom.wineglass")
                        }

                        Button(action: {
                            toggleIsHeavy(for: item)
                        }) {
                            Label(item.isHeavy ? "Not heavy" : "Heavy", image: item.isHeavy ? "custom.figure.strengthtraining.traditional.slash" : "custom.figure.strengthtraining.traditional")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(selectedColor)
                        .scaleEffect(1.2)
                }
            }
            .swipeActions(edge: .leading) {
                Button(action: {
                    toggleIsFragile(for: item)
                }) {
                    Label("", image: item.isFragile ? "custom.wineglass.slash" : "custom.wineglass")
                }
                .tint(Color.blue)

                Button(action: {
                    toggleIsHeavy(for: item)
                }) {
                    Label("", image: item.isHeavy ? "custom.figure.strengthtraining.traditional.slash" : "custom.figure.strengthtraining.traditional")
                }
                .tint(Color.secondary)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive, action: {
                    removeItem(item)
                }) {
                    Label("", systemImage: "trash")
                }
                .tint(.red)
            }
            .frame(maxHeight: 100)
        )
    }

    // Entfernt führende und nachgestellte Leerzeichen in allen Create-Elementen
    // direkt vor "Hinzufügen" und "Speichern".
    private func sanitizeCreateInputBeforeMutation() {
        boxName = boxName.trimmedForCreate()
        notes = notes.trimmedForCreate()
        newCategory = newCategory.trimmedForCreate()
        newItem = newItem.trimmedForCreate()
        newmissingItem = newmissingItem.trimmedForCreate()

        var removedImageNames: [String] = []
        items = items.compactMap { item in
            let trimmedName = item.name.trimmedForCreate()
            guard !trimmedName.isEmpty else {
                removedImageNames.append(contentsOf: item.images)
                return nil
            }
            var updatedItem = item
            updatedItem.name = trimmedName
            updatedItem.images = Array(item.images.prefix(1))
            return updatedItem
        }
        deleteDraftImages(named: removedImageNames)

        missingitems = missingitems
            .map { $0.trimmedForCreate() }
            .filter { !$0.isEmpty }

        recognizedTexts = recognizedTexts
            .map { $0.trimmedForCreate() }
            .filter { !$0.isEmpty }
    }

    @ViewBuilder
    private func itemImageButton(
        previewImage: UIImage?,
        accessibilityLabel: String,
        showsDeleteOverlay: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Group {
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: itemImageInputSource.systemImage)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.systemFill))
                    }
                }
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                if showsDeleteOverlay {
                    Rectangle()
                        .fill(Color.black.opacity(0.45))
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Image(systemName: "trash.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private enum CreateItemImageTarget {
    case pendingNewItem
    case existingItem(UUID)
}

private enum ItemImageInputSource: String {
    case none
    case camera
    case gallery

    var systemImage: String {
        switch self {
        case .none:
            return "eye.slash.fill"
        case .camera:
            return "camera.fill"
        case .gallery:
            return "photo.fill"
        }
    }
}

private extension String {
    func trimmedForCreate() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct CreateImageReorderDropDelegate: DropDelegate {
    @Binding var images: [UIImage]
    @Binding var draggedImage: UIImage?
    let targetImage: UIImage
    
    func dropEntered(info: DropInfo) {
        guard let draggedImage else { return }
        guard let from = images.firstIndex(of: draggedImage),
              let to = images.firstIndex(of: targetImage),
              from != to else { return }
        
        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.84, blendDuration: 0.1)) {
            images.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggedImage = nil
        return true
    }
}

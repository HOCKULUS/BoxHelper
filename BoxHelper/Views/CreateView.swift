import SwiftUI
import TipKit
import PhotosUI
import UIKit
import AVFoundation

struct BoxCreateView: View {
    let isActive: Bool
    let leftModeButton: AnyView
    let rightModeButton: AnyView
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
    // Auch die noch nicht hinzugefügte Zeile reist mit einer stabilen Objekt-ID.
    @State private var pendingNewItemID = UUID()
    @State private var newmissingItem: String = ""
    @State private var locations: [Locations] = []
    @State private var selectedCategory: UUID?
    @State private var newCategory: String = ""
    @State private var categories: [String] = [] // Loaded on activation, not during every view initialization.
    @State private var selectedImages: [UIImage] = []
    // Beim ersten Aufruf aktiv; eine gespeicherte Abschaltung bleibt erhalten.
    @AppStorage(CreateCameraPreferences.boxSmartCameraKey) private var isSmartCameraEnabled = true
    @State private var qrCodeFeedbackID: UUID?
    @State private var qrCodeAction: CreateQRCodeAction?
    @StateObject private var boxAutomation = BoxCameraAutomation()
    @AppStorage("boxCameraFeedEnabled") private var boxCameraFeedEnabled = true
    @AppStorage(CreateCameraPreferences.qrCodeKey) private var qrCodesEnabled = true
    @AppStorage(BoxAutomaticCapturePolicy.locationNamingKey) private var boxLocationDictation = true
    @AppStorage(BoxAutomaticCapturePolicy.voiceNamingKey) private var boxVoiceNaming = true
    @AppStorage(FeedSensitivityLevel.storageKey) private var cameraSensitivity = 0
    @State private var isFormVisible = false
    @State private var isKeyboardVisible = false
    @State private var isPopupCameraActive = false
    @State private var showCameraUnavailable = false
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
    @State private var formBlur: CGFloat = 0
    @State private var showSavedConfirmation = false
    @State private var isSaveAnimationActive = false
    // Nur der lokale Commit sperrt den manuellen Knopf; die Rückmeldung läuft separat.
    @State private var isSaving = false
    @State private var saveFeedbackID = UUID()
    @AppStorage("sliderValue3") private var sliderValue3: Double = 50.0
    @State private var tagRecognitionRevision = UUID()
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
    @State private var loadLastInput: Bool = UserDefaults.standard.object(forKey: "loadLastInput") == nil ? true : UserDefaults.standard.bool(forKey: "loadLastInput")
    @State private var draftImageFileNames: [String] = []
    @State private var cachedDraftImages: [UIImage] = []
    @State private var isLoadingCreateDraft: Bool = false
    @State private var createDraftLoadGeneration = UUID()
    @State private var hasInitializedCreateForm = false
    @State private var hasLoadedCreateDraft = false
    @State private var ignoreNextDraftImageChange = false
    @State private var handoffFormID: UUID?
    @State private var isReceivingHandoff = false
    @State private var skipInitialLocationSuggestion = false
    @State private var receivedQRCodeID: UUID?
    @State private var draggedCreateImage: UIImage?
    @State private var showItemImagePicker = false
    @State private var showItemCameraPicker = false
    @State private var selectedItemPickerImages: [UIImage] = []
    @State private var pendingNewItemImageFileName: String?
    @State private var activeItemImageTarget: CreateItemImageTarget?
    @State private var itemImageInputSource: ItemImageInputSource = .camera
    @AppStorage("createNewItemInputAutofocusMode") private var createNewItemInputAutofocusMode: String = "yes"
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

                    // Neue Entwürfe oben anzeigen; Bearbeitung und Löschen bleiben an die ID gebunden.
                    ForEach(items.sorted { $0.createdAt > $1.createdAt }) { item in
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
                                    // Hintergrund und Klickfläche gehören ins Label, damit auch der Rand reagiert.
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                                        .frame(width: 40, height: 40)
                                        .background(Color(UIColor.systemFill))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("QR Code Settings")
                                .popoverTip(addCustomizableQRCodeTip)

                                Button {
                                    guard let qrCodeImage = currentQRCodeImage else { return }
                                    printQRCode(qrCodeImage, count: QRCodeCopies, perPage: QRCodeNumber)
                                } label: {
                                    // Keep the visual background inside the label so the whole button is tappable.
                                    Label("Print QR Code", systemImage: "printer.fill.and.paper.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                                        .frame(maxWidth: .infinity, minHeight: 40)
                                        .background(Color(UIColor.systemFill))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
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
                    locationPicker
                    HStack {
                        TextField("CreateView.addLocation", text: $newCategory)
                            .focused($focusedField, equals: .newLocation)
                            .frame(maxWidth: .infinity)
                            .disabled(isDisabled)
                            .onSubmit { addCategory() }
                        Button { addCategory() } label: { Image(systemName: "plus") }
                            .disabled(newCategory.isEmpty || isDisabled)
                            .accentColor(selectedColor)
                    }
                    .onChange(of: newCategory) { _, _ in checkIfEmpty() }
                    .onChange(of: selectedCategory) { _, value in
                        // Nil means a new location; do not restore the previous selection here.
                        if value == nil { focusedField = .newLocation }
                        else { newCategory = "" }
                        checkIfEmpty()
                    }
                }
            }
        )
    }

    private var locationPicker: some View {
        CreateObjectPicker(label: "Location",
                           choices: locations.map { CreateChoice(id: $0.id, name: $0.name) },
                           selection: $selectedCategory)
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
                if isSmartCameraEnabled {
                    CreateBoxSmartCamera(automation: boxAutomation, images: selectedImages,
                                         feedEnabled: boxCameraFeedEnabled,
                                         openGallery: { showImagePicker = true }, openCamera: openBoxPopupCamera,
                                         toggleFeed: { boxCameraFeedEnabled.toggle() },
                                         removeImage: removeSelectedCreateImage)
                } else {
                    CreatePhotoStrip(images: selectedImages,
                                     openGallery: { showImagePicker = true },
                                     openCamera: { showCameraPicker = true },
                                     removeImage: removeSelectedCreateImage)
                }
                if showTags && !hideTags {
                    CreateTagStrip(tags: recognizedTexts, hasImages: !selectedImages.isEmpty,
                                   color: selectedColor,
                                   clear: {
                                       tagRecognitionRevision = UUID()
                                       recognizedTexts = []
                                   },
                                   recognize: refreshRecognizedTextsFromSelectedImages,
                                   block: { tag in
                                       tagRecognitionRevision = UUID()
                                       recognizedTexts.removeAll { $0 == tag }
                                       var blocked = UserDefaultsManager.shared.loadBlockedTags()
                                       if !blocked.contains(tag) { blocked.append(tag) }
                                       UserDefaultsManager.shared.saveBlockedTags(blocked)
                                   })
                }
            }
            .sheet(isPresented: $showImagePicker) { ImagePicker(selectedImages: $selectedImages) }
            .sheet(isPresented: $showCameraPicker, onDismiss: { isPopupCameraActive = false }) {
                CameraPicker(images: $selectedImages)
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
                if isSmartCameraEnabled && boxCameraFeedEnabled {
                    Section { Color.clear.frame(height: 84) }.listRowBackground(Color.clear)
                }
            }
            .disabled(isLoadingCreateDraft || boxAutomation.isCompleting)
            .toolbarTitleDisplayMode(.inline)
            .listRowInsets(EdgeInsets())
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
                // Das letzte Foto und die aktuellen Texte bleiben für einen Handoff-
                // Abruf verfügbar, auch wenn der Benutzer das Gerät bereits wechselt.
                cacheCreateHandoffImages()
                persistCreateFocusForSmartMode()
            }
            .task {
                // Cancellation prevents a disappearing form from reopening the keyboard after a switch.
                await Task.yield()
                guard !Task.isCancelled else { return }
                if !hasLoadedCreateDraft {
                    await loadCreateDraftIfNeeded()
                }
                guard !Task.isCancelled else { return }
                applyInitialCreateFocus()
                await typeInitialLocationNameIfNeeded()
            }
            .onAppear {
                loadLastInput = UserDefaults.standard.object(forKey: "loadLastInput") == nil ? true : UserDefaults.standard.bool(forKey: "loadLastInput")
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
            .navigationTitle("")
            .toolbar {
                CreateFormToolbar {
                    CreateFormTitle(placeholder: "CreateView.BoxTitle", text: $boxName, settingsTarget: "box")
                        .disabled(isLoadingCreateDraft || boxAutomation.isCompleting || max(formBlur, boxAutomation.feedbackBlur) > 0)
                        .blur(radius: max(formBlur, boxAutomation.feedbackBlur))
                        .popoverTip(qrCodeFeedbackID == nil ? addIntroduceBoxNaming : nil)
                        .modifier(CreateQRCodeInfo(eventID: qrCodeFeedbackID))
                }
            }
            .listSectionSpacing(16.0)
            .scrollDismissesKeyboard(.immediately)
            .onAppear { initializeCreateFormIfNeeded() }
            .overlay(alignment: .bottom) {
                if isSmartCameraEnabled && boxCameraFeedEnabled && !isKeyboardVisible {
                    CreateBoxCameraControls(automation: boxAutomation,
                                            isBusy: isLoadingCreateDraft || isSaveAnimationActive)
                        .padding(.bottom, 16)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CreateSaveControls(leftButton: leftModeButton, rightButton: rightModeButton,
                                   isDisabled: isLoadingCreateDraft || isDisabled || isEmpty || isSaving || isSaveAnimationActive
                                    || boxAutomation.isCompleting || boxAutomation.camera.isCapturing,
                                   color: selectedColor,
                                   save: saveManuallyFromControls)
            }
    }

    /// Ein unbenutztes Etikett bestimmt nur die ID des Entwurfs, nicht einen vorzeitigen Datenbankeintrag.
    private func adoptMissingQRCodeBox(_ id: UUID, eventID: UUID) {
        guard isActive, !isLoadingCreateDraft, !isSaveAnimationActive,
              !UserDefaultsManager.shared.loadBoxes().contains(where: { $0.id == id }) else { return }
        missingUUID = id
        boxUUID = id
        // Die laufende Eingabe und ihre Handoff-Kopie behalten dieselbe gescannte Etikett-ID.
        pregeneratedUUID = id
        pregeneratedUUIDString = id.uuidString
        if useBoxUUIDasBoxName { boxName = "#" + id.uuidString.prefix(6) }
        qrCodeFeedbackID = eventID
        qrCodeAction = CreateQRCodeAction(id: eventID, boxName: boxName)
        boxAutomation.pauseForQRCode()
    }

    private var shouldRunBoxCamera: Bool {
        isActive && isFormVisible && scenePhase == .active && isSmartCameraEnabled && boxCameraFeedEnabled
            && !showImagePicker && !isPopupCameraActive && !showItemCameraPicker && !showItemImagePicker
    }

    private var shouldScanBoxQRCode: Bool {
        CreateCameraPreferences.shouldScan(cameraRunning: shouldRunBoxCamera, qrEnabled: qrCodesEnabled,
                                           automaticSelected: boxAutomation.automaticSelected,
                                           captureActive: boxAutomation.sessionID != nil,
                                           loading: isLoadingCreateDraft || isSaveAnimationActive || boxAutomation.isCompleting)
    }

    private func acceptBoxQRCode(_ event: FeedBoxQRCodeEvent) {
        guard shouldScanBoxQRCode, !boxAutomation.camera.isCapturing else { return }
        let ids = UserDefaultsManager.shared.loadBoxes().map(\.id)
        guard case .missing(let id) = event.code.target(existingIDs: ids,
            currentID: missingUUID ?? pregeneratedUUID, allowExisting: false) else { return }
        adoptMissingQRCodeBox(id, eventID: event.id)
    }

    private func openBoxPopupCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showCameraUnavailable = true
            return
        }
        isPopupCameraActive = true
        boxAutomation.stopMonitoring()
        Task { @MainActor in
            await boxAutomation.camera.pause()
            guard isFormVisible else { isPopupCameraActive = false; return }
            showCameraPicker = true
        }
    }

    /// Diktat überschreibt das Schema nur bei einem tatsächlich gesprochenen Namen.
    private func saveAutomaticBox(spokenName: String?, location: LocationDictationSelection?) -> Bool {
        guard isActive, !isLoadingCreateDraft, !isSaveAnimationActive,
              let id = missingUUID ?? pregeneratedUUID else { return false }
        var newLocationColor: String?
        // Standortwahl wird erst nach beendetem Diktat auf den Entwurf angewandt.
        switch location {
        case .existing(let locationID):
            guard loadLocations().contains(where: { $0.id == locationID }) else { return false }
            selectedCategory = locationID
            newCategory = ""
        case .new(let name):
            if let existing = loadLocations().first(where: {
                LocationDictationMatcher.normalized($0.name) == LocationDictationMatcher.normalized(name)
            }) {
                selectedCategory = existing.id
                newCategory = ""
            } else {
                selectedCategory = nil
                newCategory = name
                // Die gespeicherte Farbe entspricht der bereits bestätigten Diktatkarte.
                newLocationColor = boxAutomation.locationDictation.newLocationColor
            }
        case nil: break
        }
        boxName = CreateAutomaticName.resolve(spoken: spokenName, fallback: CreateBoxNameGenerator.nextName(id: id))
        checkIfEmpty()
        saveFromControls(newLocationColor: newLocationColor)
        return showSavedConfirmation
    }

    private func saveManuallyFromControls() {
        guard !isLoadingCreateDraft, !isSaving, !isSaveAnimationActive, !isDisabled, !isEmpty,
              !boxAutomation.isCompleting, !boxAutomation.camera.isCapturing else { return }
        // Der Nutzer darf die Kiste auch vor Erreichen des Automatik-Bildziels abschließen.
        // Nur den manuellen Weg stoppen; das automatische Speichern behält seine Sitzung.
        boxAutomation.stopMonitoring()
        saveFromControls()
    }

    private func saveFromControls(newLocationColor: String? = nil) {
        guard !isSaving, !isSaveAnimationActive, !boxName.isEmpty, !isEmpty else { return }
        isSaving = true
        // Alte Ausblend-Timer dürfen die Rückmeldung einer neuen Speicherung nicht verändern.
        saveFeedbackID = UUID()
        showSavedConfirmation = false
        isSaveAnimationActive = true
        isDisabled = true
        defer { isSaving = false; isDisabled = false }
        saveBox(newLocationColor: newLocationColor)
        if showSavedConfirmation { Task { await introduceBoxNaming.saveBoxEvent.donate() } }

        // Ein fehlgeschlagener automatischer Versuch behält Entwurf, Bilder und Etikett-ID.
        if !showSavedConfirmation {
            isSaveAnimationActive = false
            isDisabled = false
        }
    }

    private func presentSavedConfirmation() {
        let feedbackID = saveFeedbackID
        withAnimation(.linear(duration: 0.45)) {
            showSavedConfirmation = true
            // Manuelle und automatische Speicherung blenden denselben Blur weich ein.
            formBlur = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            guard saveFeedbackID == feedbackID else { return }
            withAnimation(.linear(duration: 0.45)) {
                showSavedConfirmation = false
                formBlur = 0
            }
            // Erst nach vollständiger Ausblendung darf erneut gespeichert werden.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                guard saveFeedbackID == feedbackID else { return }
                isSaveAnimationActive = false
            }
        }
    }

    /// Kamera-Lebenszyklus bleibt getrennt von Fehleranzeigen und Entwurfsspeicherung.
    private var cameraFormContent: some View {
        Group {
            // Entwurfszustand behalten, Eingaben und Toolbar nur für das aktive
            // Formular einhängen. CreateView stellt die gemeinsame Navigation bereit.
            if isActive {
                createFormContent
                    .modifier(CreateCameraFeedbackOverlay(blurRadius: max(formBlur, boxAutomation.feedbackBlur)) {
                        CreateBoxCameraFeedback(automation: boxAutomation, isSaved: showSavedConfirmation)
                    })
            }
        }
        .modifier(CreateQRCodeActionFeedback(action: qrCodeAction))
        .overlay {
            if boxAutomation.diagnosticsVisible {
                CreateFeedDiagnosticsWindow(snapshot: boxAutomation.camera.feedDiagnostics) {
                    boxAutomation.diagnosticsVisible = false
                }
            }
        }
        .onAppear {
            isFormVisible = true
            activateHandoffIfVisible()
        }
        .onDisappear {
            publishCreateHandoffForm()
            isFormVisible = false
            InventoryHandoffStore.shared.deactivateForm(kind: "box")
            boxAutomation.synchronizeCamera(running: false)
            boxAutomation.releaseFormCallbacks()
            boxAutomation.camera.setQRCodeScanningEnabled(false)
        }
        .task(id: shouldRunBoxCamera) {
            FeedSensitivityLevel.prepareDefaults()
            boxAutomation.canCapture = {
                isActive && !isLoadingCreateDraft && !isSaveAnimationActive
                    && ((boxLocationDictation && !boxAutomation.dictationMuted) || selectedCategory != nil || !newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            boxAutomation.appendPhoto = { selectedImages.append($0) }
            boxAutomation.saveNamedBox = { saveAutomaticBox(spokenName: $0, location: $1) }
            boxAutomation.selectedLocationID = { selectedCategory }
            let preserveAuthorization = boxAutomation.isStarting && scenePhase == .inactive && isActive
                && isFormVisible && isSmartCameraEnabled && boxCameraFeedEnabled
                && !showImagePicker && !isPopupCameraActive && !showItemCameraPicker && !showItemImagePicker
            boxAutomation.synchronizeCamera(running: shouldRunBoxCamera, preserveAuthorization: preserveAuthorization)
        }
        .task(id: shouldScanBoxQRCode) {
            boxAutomation.camera.setQRCodeScanningEnabled(shouldScanBoxQRCode)
        }
        .onChange(of: boxAutomation.camera.boxQRCodeEvent) { _, event in
            if let event { acceptBoxQRCode(event) }
        }
        .onChange(of: shouldScanBoxQRCode) { _, allowed in
            if allowed, let event = boxAutomation.camera.boxQRCodeEvent { acceptBoxQRCode(event) }
        }
        .onChange(of: boxAutomation.camera.isCapturing) { _, capturing in
            if !capturing, let event = boxAutomation.camera.boxQRCodeEvent { acceptBoxQRCode(event) }
        }
        .onChange(of: cameraSensitivity) { _, _ in boxAutomation.updateConfiguration() }
        .onChange(of: boxLocationDictation) { _, _ in boxAutomation.updateConfiguration() }
        .onChange(of: boxVoiceNaming) { _, _ in boxAutomation.updateConfiguration() }
        .onChange(of: isSaveAnimationActive) { _, saving in
            if !saving { boxAutomation.finishSavedBox() }
        }
        .onChange(of: boxAutomation.diagnosticsVisible) { _, visible in
            boxAutomation.camera.setDiagnosticsEnabled(visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureSession.wasInterruptedNotification,
                                                        object: boxAutomation.camera.session)) { _ in
            boxAutomation.stopMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureSession.runtimeErrorNotification,
                                                        object: boxAutomation.camera.session)) { _ in
            boxAutomation.stopMonitoring()
        }
    }

    private var cameraAlertsContent: some View {
        cameraFormContent
        .alert("Speichern nicht möglich", isPresented: Binding(
            get: { boxAutomation.errorMessage != nil },
            set: { if !$0 { boxAutomation.errorMessage = nil } }
        )) { Button("OK", role: .cancel) { boxAutomation.errorMessage = nil } }
        message: { Text(boxAutomation.errorMessage ?? "") }
        .alert("Kamera nicht verfügbar", isPresented: $showCameraUnavailable) {
            Button("OK", role: .cancel) { }
        } message: { Text("Wähle stattdessen ein Foto aus der Galerie.") }
        .alert("FeedMonitoring.TimeoutTitle", isPresented: $boxAutomation.showTimeout) {
            Button("OK", role: .cancel) { }
        } message: { Text("FeedMonitoring.TimeoutMessage") }
    }

    var body: some View {
        cameraAlertsContent
        .onReceive(NotificationCenter.default.publisher(for: .inventoryHandoffWillResume)
            .merge(with: NotificationCenter.default.publisher(for: .inventoryCloudFormWillResume))) { notification in
            guard notification.object as? String == "box" else { return }
            // Die vollständig empfangene Sitzung wird gleich eingesetzt. Ausstehende
            // Änderungen des bisherigen Formulars dürfen sie nicht überschreiben.
            isReceivingHandoff = true
            isLoadingCreateDraft = true
            hasLoadedCreateDraft = false
            createDraftLoadGeneration = UUID()
            tagRecognitionRevision = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .resumeInventoryHandoff)
            .merge(with: NotificationCenter.default.publisher(for: .resumeInventoryCloudForm))) { notification in
            guard notification.object as? String == "box" else { return }
            hasLoadedCreateDraft = false
            Task { await loadCreateDraftIfNeeded(resumingHandoff: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryDidChange)) { _ in
            // Gegenstände in diesem Formular sind Entwürfe und werden nicht ersetzt.
            let currentLocations = loadLocations()
            if locations != currentLocations { locations = currentLocations }
            let currentCategories = loadCategories()
            if categories != currentCategories { categories = currentCategories }
            if let selectedCategory, InventoryStorageState.shared.readDeletedIDs().locations.contains(selectedCategory) {
                self.selectedCategory = nil
            }
            checkIfEmpty()
        }
        .onChange(of: draftFieldsAutosaveTrigger, initial: false) { _, _ in
            // Formularupdates werden nur im Arbeitsspeicher veröffentlicht. Ein neuer
            // Fortsetzen-Auftrag entwertet bereits vorgemerkte Updates des alten Formulars.
            let generation = createDraftLoadGeneration
            DispatchQueue.main.async {
                guard createDraftLoadGeneration == generation else { return }
                publishCreateHandoffForm()
            }
        }
        .onChange(of: selectedImages, initial: false) { _, _ in
            // Restored files already have saved tags and filenames; do not re-encode them on entry.
            if ignoreNextDraftImageChange { ignoreNextDraftImageChange = false; return }
            let generation = createDraftLoadGeneration
            DispatchQueue.main.async {
                guard createDraftLoadGeneration == generation else { return }
                cacheCreateHandoffImages()
            }
            refreshRecognizedTextsFromSelectedImages()
        }
        .onChange(of: isActive, initial: false) { _, active in
            if active {
                activateHandoffIfVisible()
            } else {
                publishCreateHandoffForm()
                InventoryHandoffStore.shared.deactivateForm(kind: "box")
            }
        }
        .onChange(of: scenePhase, initial: false) { _, phase in
            // Den Wechsel in den Hintergrund verwaltet der Handoff-Koordinator;
            // das sichtbare Formular wird erst beim nächsten aktiven Auftritt aktiviert.
            if phase == .active { activateHandoffIfVisible() }
        }
        .task(id: isActive) {
            if isActive {
                if hasLoadedCreateDraft, !isLoadingCreateDraft, InventoryCloudFormSync.shared.isEnabled {
                    await loadCreateDraftIfNeeded()
                }
                // Other creation forms may have added locations while this draft was hidden.
                locations = loadLocations()
                categories = loadCategories()
                checkIfEmpty()
            } else {
                focusedField = nil
            }
        }
        .onChange(of: missingUUID, initial: false) { oldValue, newValue in
            // Eine übernommene Etikett-ID bringt ihren bereits eingegebenen Namen mit.
            // Nur ein neu lokal gescanntes Etikett wendet die hiesige Namensvorgabe an.
            if let receivedQRCodeID, newValue == receivedQRCodeID {
                self.receivedQRCodeID = nil
                return
            }
            receivedQRCodeID = nil
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
            pendingNewItemID.uuidString,
            pendingNewItemImageFileName ?? "",
            newmissingItem,
            tagsSignature,
            pregeneratedUUID?.uuidString ?? "",
            missingUUID?.uuidString ?? ""
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
    
    // Ein bereits vorhandener Standortname wird ausgewählt statt nochmals angelegt.
    func addCategory(color: String? = nil) {
        sanitizeCreateInputBeforeMutation()
        guard !newCategory.isEmpty else { return }
        locations = loadLocations()
        if let existing = locations.first(where: { $0.name == newCategory }) {
            selectedCategory = existing.id
            newCategory = ""
            return
        }
        let location = Locations(id: UUID(), name: newCategory, color: color ?? colorToString(randomColor()) ?? "")
        var updatedLocations = locations
        updatedLocations.append(location)
        guard UserDefaultsManager.shared.saveLocations(updatedLocations) else { return }
        newLocation = location
        locations = updatedLocations
        selectedCategory = location.id
        newCategory = ""
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
            let newUUID = pendingNewItemID
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
            pendingNewItemID = UUID()
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

    private func refreshSavedItemTags(_ itemsToSave: [Items]) {
        // Die Kiste ist bereits gespeichert; verspätete OCR ergänzt nur deren Gegenstände.
        for item in itemsToSave where !item.images.isEmpty {
            generateAutomaticTagsIfEnabled(fromImagePaths: item.images) { tags in
                var storedItems = UserDefaultsManager.shared.loadItems()
                guard let index = storedItems.firstIndex(where: { $0.id == item.id }),
                      storedItems[index].images == item.images else { return }
                storedItems[index].tags = tags
                UserDefaultsManager.shared.saveItems(storedItems)
            }
        }
    }
    private func saveBox(newLocationColor: String? = nil) {
        sanitizeCreateInputBeforeMutation()
        guard !boxName.isEmpty, selectedCategory != nil || !newCategory.isEmpty,
              let id = missingUUID ?? pregeneratedUUID else { isEmpty = true; return }
        let snapshot: InventorySnapshot
        do {
            snapshot = try InventoryPersistence.selection(boxIDs: [id],
                locationIDs: newCategory.isEmpty ? selectedCategory.map { [$0] } ?? [] : nil)
        } catch {
            InventoryStorageState.shared.report(error)
            boxAutomation.errorMessage = error.localizedDescription
            return
        }
        guard !snapshot.boxes.contains(where: { $0.id == id }) else {
            boxAutomation.errorMessage = String(localized: "CreateCamera.BoxAlreadyExists")
            return
        }
        var updatedLocations = snapshot.locations
        let locationID: UUID
        if !newCategory.isEmpty {
            let location = updatedLocations.first(where: { $0.name == newCategory })
                // Beide Geräte vervollständigen dieselbe Handoff-Kiste mit derselben
                // impliziten Standort-ID, auch wenn dessen Cloud-Import noch aussteht.
                ?? Locations(id: InventoryDraftIdentity.component("box-location", of: id), name: newCategory,
                             color: newLocationColor ?? colorToString(randomColor()) ?? "")
            if !updatedLocations.contains(where: { $0.id == location.id }) { updatedLocations.append(location) }
            locationID = location.id
        } else if let selectedCategory, updatedLocations.contains(where: { $0.id == selectedCategory }) {
            locationID = selectedCategory
        } else {
            boxAutomation.errorMessage = String(localized: "CreateCamera.BoxSelectLocation")
            return
        }

        // Fotos vorbereiten, den Entwurf jedoch erst nach dem erfolgreichen Commit aufräumen.
        var imageNames: [String] = []
        for image in selectedImages {
            guard let data = image.compressImage(),
                  let url = UserDefaultsManager.shared.saveImage(data, withName: "\(UUID().uuidString).jpg") else {
                imageNames.forEach { UserDefaultsManager.shared.deleteImage(named: $0) }
                boxAutomation.errorMessage = String(localized: "FeedMonitoring.PhotoFailed")
                return
            }
            imageNames.append(url.lastPathComponent)
        }
        addItem()
        let draftItemImages = Set(items.flatMap(\.images))
        let finalizedItems: [Items]
        do {
            finalizedItems = try finalizeDraftImages(for: items).map { item in
                var assigned = item
                assigned.box_uuid = id
                return assigned
            }
        } catch {
            imageNames.forEach { UserDefaultsManager.shared.deleteImage(named: $0) }
            boxAutomation.errorMessage = String(localized: "FeedMonitoring.PhotoFailed")
            return
        }
        let newBox = MovingBox(id: id, name: boxName, items: [], images: imageNames,
                               category: "", location_uuid: locationID, color: "", tags: recognizedTexts,
                               notes: notes.isEmpty ? nil : notes)
        do {
            // Nur neue Objekte gehören zu diesem Entwurf. Ein Cloud-Import darf während
            // der Fotovorbereitung keine vorhandenen Datensätze verlieren oder zurückdrehen.
            let existingLocationIDs = Set(snapshot.locations.map(\.id))
            try InventoryPersistence.mergeInventory(boxes: [newBox], items: finalizedItems,
                                                    locations: updatedLocations.filter { !existingLocationIDs.contains($0.id) })
        } catch {
            let newItemImages = finalizedItems.flatMap(\.images).filter { !draftItemImages.contains($0) }
            (imageNames + newItemImages).forEach { UserDefaultsManager.shared.deleteImage(named: $0) }
            InventoryStorageState.shared.report(error)
            boxAutomation.errorMessage = error.localizedDescription
            return
        }
        deleteDraftImages(named: Array(draftItemImages))
        locations = loadLocations()
        selectedCategory = locationID
        newCategory = ""
        refreshSavedItemTags(finalizedItems)
        boxUUID = id
        presentSavedConfirmation()
        generateAutomaticTagsIfEnabled(fromImagePaths: imageNames) { tags in
            var storedBoxes = UserDefaultsManager.shared.loadBoxes()
            guard let index = storedBoxes.firstIndex(where: { $0.id == newBox.id }),
                  storedBoxes[index].images == imageNames else { return }
            storedBoxes[index].tags = tags
            UserDefaultsManager.shared.saveBoxes(storedBoxes)
        }
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "lastBoxID") + 1, forKey: "lastBoxID")
        resetAfterSavedBox(locationID: locationID)
    }

    /// Nur eine bestätigte Speicherung leert den Entwurf und erzeugt die nächste Etikett-ID.
    private func resetAfterSavedBox(locationID: UUID) {
        items = []
        newItem = ""
        pendingNewItemID = UUID()
        missingitems = []
        newmissingItem = ""
        notes = ""
        recognizedTexts = []
        items_uuid = []
        pendingNewItemImageFileName = nil
        missingUUID = nil
        let nextID = UUID()
        pregeneratedUUID = nextID
        pregeneratedUUIDString = nextID.uuidString
        selectedCategory = locationID
        selectedImages = []
        clearCreateDraft()
        categories = loadCategories()
        showBoxNameSheme = UserDefaultsManager.shared.loadShowBoxNameSheme()
        showBoxNumberSheme = UserDefaultsManager.shared.loadShowBoxNumberSheme()
        useBoxUUIDasBoxName = UserDefaultsManager.shared.loadUseBoxUUIDasBoxName()
        boxNameSchemeIsEmpty = UserDefaults.standard.string(forKey: "boxNameScheme")?.isEmpty ?? true
        boxNameScheme = NSLocalizedString(UserDefaults.standard.string(forKey: "boxNameScheme") ?? "CreateView.Box", comment: "")
        boxName = useBoxUUIDasBoxName ? "#" + nextID.uuidString.prefix(6) : buildBoxName()
        isDisabled = false
    }

    /// Beide Einstiege verwenden dieselbe Initialisierung. Ein Handoff an ein noch
    /// verborgenes Formular darf beim späteren Einblenden nicht erneut überschrieben werden.
    private func initializeCreateFormIfNeeded() {
        guard !hasInitializedCreateForm else { return }
        hasInitializedCreateForm = true
        locations = loadLocations()
        categories = loadCategories()
        selectedCategory = loadBoxes().last?.location_uuid ?? locations.last?.id
        QRCodeNumber = UserDefaultsManager.shared.getQRCodeNumber()
        QRCodeCopies = UserDefaultsManager.shared.getQRCodeCopies()
        selectedColor = UserDefaultsManager.loadAccentColor()
        itemImageInputSource = ItemImageInputSource(rawValue: UserDefaultsManager.shared.loadCreateItemImageInputSource()) ?? .camera
        boxNameSchemeIsEmpty = UserDefaults.standard.string(forKey: "boxNameScheme")?.isEmpty ?? true
        boxNameScheme = NSLocalizedString(UserDefaults.standard.string(forKey: "boxNameScheme") ?? "CreateView.Box", comment: "")
        showBoxNameSheme = UserDefaultsManager.shared.loadShowBoxNameSheme()
        useBoxUUIDasBoxName = UserDefaultsManager.shared.loadUseBoxUUIDasBoxName()
        showBoxNumberSheme = UserDefaultsManager.shared.loadShowBoxNumberSheme()
        let id = missingUUID ?? pregeneratedUUID ?? UUID()
        pregeneratedUUID = id
        pregeneratedUUIDString = id.uuidString
        boxUUID = missingUUID
        boxName = useBoxUUIDasBoxName ? "#" + id.uuidString.prefix(6) : buildBoxName()
    }

    private struct CreateHandoffForm: Codable {
        var boxName: String
        var items: [Items]
        var missingitems: [String]
        var newItem: String
        var pendingNewItemID: UUID?
        var pendingNewItemImageFileName: String?
        var newmissingItem: String
        var selectedCategory: UUID?
        var newCategory: String
        var recognizedTexts: [String]
        var notes: String?
        var imageFileNames: [String]
        // Optionale Felder halten das bisherige Formular-JSON lesbar.
        var pregeneratedUUID: UUID?
        var missingUUID: UUID?
    }

    @discardableResult
    private func publishCreateHandoffForm(isInitial: Bool = false) -> Bool {
        guard hasLoadedCreateDraft, !isLoadingCreateDraft, !isReceivingHandoff,
              InventoryHandoffStore.shared.activeFormID(kind: "box") == handoffFormID else { return false }
        let draft = CreateHandoffForm(
            boxName: boxName,
            items: items,
            missingitems: missingitems,
            newItem: newItem,
            pendingNewItemID: pendingNewItemID,
            pendingNewItemImageFileName: pendingNewItemImageFileName,
            newmissingItem: newmissingItem,
            selectedCategory: selectedCategory,
            newCategory: newCategory,
            recognizedTexts: recognizedTexts,
            notes: notes,
            imageFileNames: draftImageFileNames,
            pregeneratedUUID: pregeneratedUUID,
            missingUUID: missingUUID
        )
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
            try InventoryHandoffStore.shared.save(form: encoder.encode(draft), kind: "box", isInitial: isInitial)
            handoffFormID = InventoryHandoffStore.shared.activeFormID(kind: "box")
            return true
        } catch InventoryHandoffError.incomingPending {
            // Der eingehende Stand hat Vorrang. Die bisherigen Cachefotos bleiben
            // bestehen, bis der erfolgreiche Empfänger sie ausdrücklich ersetzt.
            return false
        } catch {
            // Eine nicht übertragbare Handoff-Kopie verhindert keinen normalen
            // Inventar-Save und ist kein Fehler der SwiftData-Datenbank.
            print("Handoff-Formular konnte nicht vorbereitet werden: \(error)")
            return false
        }
    }

    private func cacheCreateHandoffImages() {
        guard hasLoadedCreateDraft, !isLoadingCreateDraft, !isReceivingHandoff,
              InventoryHandoffStore.shared.activeFormID(kind: "box") == handoffFormID else { return }
        guard selectedImages != cachedDraftImages else {
            publishCreateHandoffForm()
            return
        }
        let previousFiles = draftImageFileNames
        var fileNames: [String] = []
        for image in selectedImages {
            let fileName = "\(createDraftImagePrefix)\(UUID().uuidString).jpg"
            if let compressedImageData = image.compressImage(),
               let fileURL = UserDefaultsManager.shared.saveImage(compressedImageData, withName: fileName) {
                fileNames.append(fileURL.lastPathComponent)
            }
        }
        guard fileNames.count == selectedImages.count else {
            deleteDraftImages(named: fileNames)
            InventoryStorageState.shared.report(CreateHandoffError.missingPhoto)
            return
        }
        draftImageFileNames = fileNames
        // Die vorherigen temporären Dateien bleiben bis zur bestätigten In-Memory-Kopie verfügbar.
        if publishCreateHandoffForm() {
            cachedDraftImages = selectedImages
            deleteDraftImages(named: previousFiles)
        } else {
            draftImageFileNames = previousFiles
            deleteDraftImages(named: fileNames)
        }
    }

    @MainActor
    private func loadCreateDraftIfNeeded(resumingHandoff: Bool = false) async {
        guard !Task.isCancelled else { return }
        let request = UUID()
        createDraftLoadGeneration = request
        hasLoadedCreateDraft = false
        isLoadingCreateDraft = true
        initializeCreateFormIfNeeded()
        defer {
            // Ein alter Fotoauftrag entsperrt niemals eine jüngere Handoff-Sitzung.
            if createDraftLoadGeneration == request {
                isLoadingCreateDraft = false
                if Task.isCancelled { hasLoadedCreateDraft = false }
            }
        }
        do {
            // Ein neu aufgerufenes fehlendes Etikett hat Vorrang vor der im Speicher
            // behaltenen Eingabe. Ein ausdrücklicher Handoff-Auftrag lädt seine eigene ID.
            let data = missingUUID != nil && !resumingHandoff
                ? nil : try InventoryHandoffStore.shared.load(kind: "box")
            let formID = InventoryHandoffStore.shared.activeFormID(kind: "box")
            guard let data else {
                handoffFormID = formID
                hasLoadedCreateDraft = true
                isReceivingHandoff = false
                isLoadingCreateDraft = false
                publishCreateHandoffForm(isInitial: true)
                return
            }
            let draft = try JSONDecoder().decode(CreateHandoffForm.self, from: data)
            skipInitialLocationSuggestion = true
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let urls = draft.imageFileNames.compactMap { name -> URL? in
                guard name == URL(fileURLWithPath: name).lastPathComponent else { return nil }
                return directory.appendingPathComponent(name)
            }
            let photos = await CreateDraftImageLoader.load(imageURLs: urls)
            guard !Task.isCancelled, createDraftLoadGeneration == request,
                  InventoryHandoffStore.shared.activeFormID(kind: "box") == formID else { return }
            guard photos.images.count == draft.imageFileNames.count else { throw CreateHandoffError.missingPhoto }

            // Erst vollständig dekodierte Daten und Fotos ersetzen die sichtbare Eingabe.
            // Ausstehende OCR-Antworten der vorherigen Fotos dürfen sie nicht verändern.
            let previousFiles = draftImageFileNames + collectCreateItemDraftImageFileNames()
            tagRecognitionRevision = UUID()
            handoffFormID = formID
            boxName = draft.boxName
            items = draft.items
            items_uuid = draft.items.map(\.id)
            missingitems = draft.missingitems
            newItem = draft.newItem
            // Ältere Formular-JSONs ohne dieses Feld verwenden einen ebenfalls
            // geräteübergreifend stabilen Ersatz aus der gemeinsamen Kisten-ID.
            let creationID = draft.pregeneratedUUID ?? draft.missingUUID ?? formID ?? pregeneratedUUID ?? UUID()
            pendingNewItemID = draft.pendingNewItemID
                ?? InventoryDraftIdentity.component("box-pending-item", of: creationID)
            pendingNewItemImageFileName = draft.pendingNewItemImageFileName
            newmissingItem = draft.newmissingItem
            selectedCategory = draft.selectedCategory
            newCategory = draft.newCategory
            recognizedTexts = draft.recognizedTexts
            notes = draft.notes ?? ""
            receivedQRCodeID = draft.missingUUID
            missingUUID = draft.missingUUID
            boxUUID = draft.missingUUID
            if let id = draft.pregeneratedUUID ?? draft.missingUUID {
                pregeneratedUUID = id
                pregeneratedUUIDString = id.uuidString
            }
            draftImageFileNames = draft.imageFileNames
            ignoreNextDraftImageChange = selectedImages != photos.images
            selectedImages = photos.images
            cachedDraftImages = photos.images
            hasLoadedCreateDraft = true
            isReceivingHandoff = false
            let keptFiles = Set(draftImageFileNames + collectCreateItemDraftImageFileNames())
            deleteDraftImages(named: previousFiles.filter { !keptFiles.contains($0) })
        } catch {
            InventoryStorageState.shared.report(error)
        }
    }

    private func activateHandoffIfVisible() {
        guard isActive, isFormVisible, scenePhase == .active else { return }
        InventoryHandoffStore.shared.activateForm(kind: "box")
        // Ein schon geladenes Formular behält seine Sitzungs-ID. Nur neue Eingaben
        // übernehmen die vom Store vorbereitete ID; eingehende Sitzungen lädt der Handler.
        if !hasLoadedCreateDraft && !isReceivingHandoff {
            handoffFormID = InventoryHandoffStore.shared.activeFormID(kind: "box")
        }
    }

    private func clearCreateDraft() {
        do { try InventoryHandoffStore.shared.clear(kind: "box") }
        catch { InventoryStorageState.shared.report(error); return }
        createDraftLoadGeneration = UUID()
        deleteDraftImages(named: draftImageFileNames)
        deleteDraftImages(named: collectCreateItemDraftImageFileNames())
        draftImageFileNames.removeAll()
        cachedDraftImages = []
        pendingNewItemImageFileName = nil
        handoffFormID = nil
        isReceivingHandoff = false
        if isActive, isFormVisible, scenePhase == .active {
            InventoryHandoffStore.shared.activateForm(kind: "box")
            handoffFormID = InventoryHandoffStore.shared.activeFormID(kind: "box")
        }
    }

    private enum CreateHandoffError: LocalizedError {
        case missingPhoto
        var errorDescription: String? { "Ein Kistenfoto konnte nicht für das laufende Formular vorbereitet werden." }
    }

    @MainActor
    private func typeInitialLocationNameIfNeeded() async {
        // Eine übernommene oder im Speicher behaltene Eingabe erhält keine neue
        // Einführung, die ihre bereits bestätigten Formularwerte verändern würde.
        guard !skipInitialLocationSuggestion else { return }
        let defaults = UserDefaults.standard
        let introductionKey = "hasIntroducedBoxLocationName"
        guard !defaults.bool(forKey: introductionKey) else { return }
        // Nur der erste Besuch bietet die Starthilfe; späteres Löschen aller Daten
        // oder erneutes Öffnen des Formulars soll keine Eingabe auslösen.
        defaults.set(true, forKey: introductionKey)
        guard missingUUID == nil, loadBoxes().isEmpty, loadLocations().isEmpty,
              selectedCategory == nil, newCategory.isEmpty else { return }

        let locationName = String(localized: "Location")
        var typedName = ""
        for character in locationName {
            do { try await Task.sleep(for: .milliseconds(120)) }
            catch { return }
            // Eigene Eingaben, Speichern und Formularwechsel beenden die Animation.
            guard !Task.isCancelled, isActive, !isDisabled,
                  selectedCategory == nil, locations.isEmpty,
                  newCategory == typedName else { return }
            typedName.append(character)
            newCategory = typedName
        }
    }

    private func applyInitialCreateFocus() {
        // The draft stays mounted, but only the active form may request keyboard focus.
        guard isActive else { return }
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

        focusedField = targetField
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

    /// Entwurfsfotos kopieren; Originale bleiben bis zum Datenbank-Commit verfügbar.
    private func finalizeDraftImages(for items: [Items]) throws -> [Items] {
        var createdImages: [String] = []
        do {
            return try items.map { item in
                guard let imageName = item.images.first else { return item }
                guard imageName.hasPrefix(createItemDraftImagePrefix) else {
                    return withSingleImageLimit(item)
                }
                let newFileName = "\(UUID().uuidString).jpg"
                guard let duplicatedURL = UserDefaultsManager.shared.duplicateImage(named: imageName, to: newFileName) else {
                    throw IntentInventoryError.saveFailed
                }
                createdImages.append(duplicatedURL.lastPathComponent)
                var finalizedItem = withSingleImageLimit(item)
                finalizedItem.images = [duplicatedURL.lastPathComponent]
                return finalizedItem
            }
        } catch {
            createdImages.forEach { UserDefaultsManager.shared.deleteImage(named: $0) }
            throw error
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
        publishCreateHandoffForm()
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
        publishCreateHandoffForm()
    }

    private func removeImage(from item: Items) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let imageNames = items[index].images
        items[index].images.removeAll()
        items[index].tags = []
        deleteDraftImages(named: imageNames)
        publishCreateHandoffForm()
    }

    private func removeItem(_ item: Items) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let imageNames = items[index].images
        items.remove(at: index)
        deleteDraftImages(named: imageNames)
        publishCreateHandoffForm()
    }

    // Keeps item tags aligned with the single stored item image in the Create draft.
    private func refreshTagsForItem(withID itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        let imagePaths = items[index].images

        guard !imagePaths.isEmpty else {
            items[index].tags = []
            publishCreateHandoffForm()
            return
        }

        generateAutomaticTagsIfEnabled(fromImagePaths: imagePaths) { generatedTags in
            guard !isReceivingHandoff, let refreshedIndex = items.firstIndex(where: { $0.id == itemID }),
                  items[refreshedIndex].images == imagePaths else { return }
            items[refreshedIndex].tags = generatedTags
            publishCreateHandoffForm()
        }
    }

    private func refreshRecognizedTextsFromSelectedImages() {
        let revision = UUID()
        tagRecognitionRevision = revision
        guard showTags, !selectedImages.isEmpty else {
            recognizedTexts = []
            return
        }
        // OCR runs in the background and never disables the form or Save button.
        generateAutomaticTagsIfEnabled(from: selectedImages) { tags in
            guard tagRecognitionRevision == revision else { return }
            recognizedTexts = tags
            arrowuturnleft_clicked = false
        }
    }

    private func removeSelectedCreateImage(at index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        // The image-change observer schedules OCR once for the updated photo set.
        selectedImages.remove(at: index)
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

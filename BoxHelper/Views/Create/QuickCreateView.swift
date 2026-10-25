import SwiftUI
import UIKit
import AVFoundation
import Speech

/// Item and location workflows share the same box/location selection semantics.
struct QuickCreateView: View {
    let mode: CreateMode
    let isActive: Bool
    let leftModeButton: AnyView
    let rightModeButton: AnyView

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("showTags") private var showTags = true
    @AppStorage("hideTags") private var hideTags = true
    @AppStorage(CreateFormPreferences.locationNameAutofocusKey) private var locationNameAutofocus = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var title = ""
    @State private var transientCreationID = UUID()
    @State private var isKeyboardVisible = false
    @AppStorage("itemCameraFeedEnabled") private var isCameraFeedEnabled = true
    @AppStorage(CreateCameraPreferences.qrCodeKey) private var isQRCodeEnabled = true
    @AppStorage(CreateCameraPreferences.itemSmartCameraKey) private var isSmartCameraEnabled = true
    @State private var handledQRCodeEventID: UUID?
    @State private var qrCodeFeedbackID: UUID?
    @State private var qrCodeAction: CreateQRCodeAction?
    @State private var boxes: [MovingBox] = []
    @State private var locations: [Locations] = []
    @State private var selectedBox: UUID?
    @State private var isCreatingLocation = false
    @State private var selectedLocation: UUID?
    @State private var newBoxName = ""
    @State private var newLocationName = ""
    @State private var pendingBoxes: [String] = []
    @State private var assignedBoxes: Set<UUID> = []
    // Die gewählte Farbe gehört auch zum noch nicht gespeicherten Handoff-Formular.
    @State private var locationColor: Color = randomColor()
    @State private var locationPhoto: UIImage?
    @State private var images: [UIImage] = []
    @State private var tags: [String] = []
    @State private var isFragile = false
    @State private var isHeavy = false
    @State private var imageRevision = UUID()
    @State private var showGallery = false
    @State private var showBoxSelection = false
    @State private var showCameraPicker = false
    @State private var isPopupCameraActive = false
    @State private var showCameraUnavailable = false
    @State private var errorMessage: String?
    @State private var isVisible = false
    @State private var hasInitializedForm = false
    @State private var hasLoadedDraft = false
    @State private var isLoadingDraft = false
    @State private var draftLoadGeneration = UUID()
    // Die Kamera wartet auf ihre Rückmeldung; manuelles Speichern nur auf den lokalen Commit.
    @State private var isSaveFeedbackActive = false
    @State private var isSaving = false
    @State private var saveFeedbackID = UUID()
    @State private var showSavedConfirmation = false
    @State private var formBlur: CGFloat = 0
    @State private var ignoreNextBoxSelectionChange = false
    @State private var ignoreNextImageChange = false
    @State private var ignoreNextLocationPhotoChange = false
    @State private var draftImageFileNames: [String] = []
    @State private var draftLocationImageFileName: String?
    @State private var lastSavedEmptyDraft: QuickCreateDraft?
    @State private var cachedDraftImages: [UIImage] = []
    @State private var cachedDraftLocationPhoto: UIImage?
    private let draftStore = QuickCreateDraftStore()
    @StateObject private var camera = EmbeddedItemCamera()
    @State private var diagnosticsVisible = false
    @StateObject private var automaticSounds = AutomaticCaptureSounds()
    @StateObject private var itemDictation = AutomaticItemDictation()
    @AppStorage(CreateCameraPreferences.itemVoiceNamingKey) private var itemVoiceNamingEnabled = true
    @State private var itemDictationMuted = false
    @AppStorage(FeedSensitivityLevel.modeKey) private var isAutomaticSelected = false
    @AppStorage(FeedSensitivityLevel.storageKey) private var sensitivityValue = 0
    @AppStorage(FeedSensitivityLevel.hintsKey) private var failureHints = true
    @State private var automaticSession: UUID?
    @State private var automaticStartRequestID: UUID?
    @State private var automaticStartAuthorized = false
    @State private var automaticCaptureBatch = AutomaticCaptureBatch(target: 1)
    @State private var automaticCapturePending = false
    @State private var isAutomaticNamingPending = false
    @State private var showAutomaticTimeout = false
    @State private var previousIdleTimerDisabled = false
    @AppStorage("feedMonitoringIntroActivations") private var automaticIntroActivations = 0
    @State private var showAutomaticIntroduction = false
    @State private var isPreparingAutomaticReference = false
    @State private var cameraReferenceFeedback: CameraReferenceFeedbackState = .hidden
    @State private var cameraReferenceFeedbackRevision = UUID()
    @State private var automaticCountdown: Int?
    @State private var automaticEmoji: String?
    @State private var automaticAbortEmoji: String?
    @State private var automaticAbortRevision = UUID()
    @State private var automaticBaseConfiguration = FeedMonitoringConfiguration()
    @State private var automaticThresholdNoticeID: UUID?
    @State private var thresholdNoticeLevel: FeedSensitivityLevel = .automatic
    @State private var thresholdNoticeIsFailure = false

    private var canSave: Bool {
        // Kiste und Standort sind optional; ein Name genügt auch für die Automatik.
        !clean(title).isEmpty
    }

    /// Versteckte Formulare und noch ladende Entwürfe dürfen keine Tastatur anfordern.
    private var shouldFocusLocationName: Bool {
        mode == .location && locationNameAutofocus && isActive && isVisible
            && scenePhase == .active && hasLoadedDraft && !isLoadingDraft
            && !isSaving && !isSaveFeedbackActive && !showBoxSelection
            && !showGallery && !showCameraPicker
    }

    /// Schon das Aufnahme-Emoji startet die Unschärfe; Diktat und Speichern
    /// übernehmen dieselbe Stärke, damit der Hintergrund dabei nicht kurz scharf wird.
    private var feedbackBlur: CGFloat {
        // Ein abgebrochener Countdown zeigt seine Rückmeldung über dem scharfen Formular.
        max(formBlur, automaticEmoji != nil || isAutomaticNamingPending ? 10 : 0)
    }

    private var usesItemDictation: Bool { itemVoiceNamingEnabled && !itemDictationMuted }

    private var sensitivity: FeedSensitivityLevel { FeedSensitivityLevel(rawValue: sensitivityValue) ?? .automatic }

    private var shouldRunCamera: Bool {
        mode == .item && isActive && isVisible && scenePhase == .active
            && isSmartCameraEnabled && isCameraFeedEnabled && !isPopupCameraActive && !showGallery
    }

    private var shouldScanQRCode: Bool {
        CreateCameraPreferences.shouldScan(cameraRunning: shouldRunCamera, qrEnabled: isQRCodeEnabled,
                                           automaticSelected: isAutomaticSelected,
                                           captureActive: automaticSession != nil, loading: isLoadingDraft)
    }

    /// Während einer Aufnahme oder Speicherung bleibt deren Kistenzuordnung fest.
    private var canSelectQRCodeBox: Bool {
        shouldScanQRCode && !isSaveFeedbackActive && !automaticCapturePending && !camera.isCapturing
    }

    // Kleine Modifier-Gruppen halten die Formular-, Kamera- und Speicherlogik getrennt.
    var body: some View {
        monitoringContent
        .onChange(of: usesItemDictation) { _, _ in
            // Auch beim nachträglichen Einschalten vor der nächsten Aufnahme fragen.
            if usesItemDictation, automaticSession != nil, !itemDictation.hasAuthorization {
                stopAutomaticMonitoring()
                startAutomaticMonitoring()
                return
            }
            automaticBaseConfiguration = .load()
            automaticBaseConfiguration.usesDictation = usesItemDictation
            if let session = automaticSession {
                camera.updateMonitoringConfiguration(sensitivity.configuration(basedOn: automaticBaseConfiguration), sessionID: session,
                                                     automaticallyAdjustThresholds: sensitivity == .automatic)
            }
        }
        .onChange(of: sensitivityValue) { _, _ in
            if let session = automaticSession {
                camera.updateMonitoringConfiguration(sensitivity.configuration(basedOn: automaticBaseConfiguration), sessionID: session,
                                                     automaticallyAdjustThresholds: sensitivity == .automatic)
            }
            // Jede Stufenwahl wird ohne Hinweis oder zusätzliche Erfassungspause übernommen.
        }
        .onChange(of: camera.repeatedAbortEvent) { _, event in
            guard let event, event.sessionID == automaticSession, failureHints else { return }
            presentAutomaticNotice(level: sensitivity, isFailure: true)
        }
        .onChange(of: failureHints) { _, enabled in
            if !enabled {
                automaticAbortEmoji = nil
                automaticThresholdNoticeID = nil
                showAutomaticTimeout = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureSession.wasInterruptedNotification, object: camera.session)) { _ in
            stopAutomaticMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureSession.runtimeErrorNotification, object: camera.session)) { _ in
            stopAutomaticMonitoring()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { cancelAutomaticStart() }
            if phase == .active {
                completeAutomaticStart()
                if isActive, isVisible, !isLoadingDraft {
                    InventoryHandoffStore.shared.activateForm(kind: mode.rawValue)
                    persistQuickDraft()
                }
            }
            if phase != .active {
                stopAutomaticMonitoring()
                persistQuickDraft()
                // Die Activity bleibt beim Sperren/Wechseln des Geräts erhalten,
                // damit das Zielgerät weiterhin seine Fotostreams anfordern kann.
            }
        }
    }

    private var draftObservingContent: some View {
        Group {
            if isActive { activeForm }
        }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryHandoffWillResume)
            .merge(with: NotificationCenter.default.publisher(for: .inventoryCloudFormWillResume))) { notification in
            guard notification.object as? String == mode.rawValue else { return }
            // Der neue Stand und seine Fotos sind bereits installiert. Ausgehende
            // Aufgaben dürfen ihn jetzt nicht mehr mit dem alten View-Zustand ersetzen.
            draftLoadGeneration = UUID()
            hasLoadedDraft = false
            isLoadingDraft = true
            cancelAutomaticStart()
            stopAutomaticMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: .resumeInventoryHandoff)
            .merge(with: NotificationCenter.default.publisher(for: .resumeInventoryCloudForm))) { notification in
            guard notification.object as? String == mode.rawValue else { return }
            hasLoadedDraft = false
            Task { await loadQuickDraftIfNeeded() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryDidChange)) { _ in
            // Nur Auswahlmöglichkeiten neu laden: Namen, Fotos und Entwürfe behalten.
            reloadChoices()
        }
        // Den Handoff-Stand erst nach dem SwiftUI-Frame aktualisieren, damit keine
        // ObservableObject-Meldung die laufende Formularauswertung unterbricht.
        .onChange(of: draftSnapshot) { _, _ in
            DispatchQueue.main.async { persistQuickDraft() }
        }
        .onChange(of: images) { _, _ in
            if ignoreNextImageChange { ignoreNextImageChange = false; return }
            recognizeImages()
            DispatchQueue.main.async { persistQuickDraftMedia() }
        }
        .onChange(of: locationPhoto) { _, _ in
            if ignoreNextLocationPhotoChange { ignoreNextLocationPhotoChange = false; return }
            DispatchQueue.main.async { persistQuickDraftMedia() }
        }
        .onChange(of: selectedBox) { _, id in
            if ignoreNextBoxSelectionChange { ignoreNextBoxSelectionChange = false; return }
            guard mode == .item else { return }
            if let box = boxes.first(where: { $0.id == id }) {
                selectedLocation = box.location_uuid
                isCreatingLocation = false
                newLocationName = ""
                newBoxName = ""
            } else if id == nil && clean(newBoxName).isEmpty {
                selectedLocation = nil
                isCreatingLocation = false
                newLocationName = ""
            }
        }
    }

    private var cameraSessionContent: some View {
        draftObservingContent
        // Hide the floating shutter before the keyboard appears, and restore it when editing ends.
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .task(id: shouldRunCamera) {
            guard mode == .item else { return }
            if shouldRunCamera { camera.start() }
            else {
                // Systemdialoge machen die Szene kurz inaktiv. Der ausdrücklich
                // angeforderte Start hält die Kamera dafür bereit; Navigation
                // und Hintergrundwechsel brechen den wartenden Start ab.
                if automaticStartRequestID != nil, scenePhase == .inactive,
                   isActive, isVisible, isSmartCameraEnabled, isCameraFeedEnabled, !isPopupCameraActive, !showGallery { return }
                cancelAutomaticStart()
                stopAutomaticMonitoring()
                camera.stop()
            }
        }
        .task(id: shouldScanQRCode) {
            camera.setQRCodeScanningEnabled(shouldScanQRCode)
            if !shouldScanQRCode { qrCodeFeedbackID = nil; qrCodeAction = nil }
        }
        .onChange(of: camera.boxQRCodeEvent) { _, event in
            if let event { selectQRCodeBox(event) }
        }
        .onChange(of: canSelectQRCodeBox) { _, allowed in
            // Eine während des Speicherns erkannte Kiste danach übernehmen,
            // sofern der Code noch im Kamerabild vorhanden ist.
            if allowed, let event = camera.boxQRCodeEvent { selectQRCodeBox(event) }
        }
    }

    private var monitoringContent: some View {
        cameraSessionContent
        .onChange(of: camera.monitoringEvent) { _, event in
            guard let event, event.sessionID == automaticSession else { return }
            switch event.update {
            case .referenceReady:
                isPreparingAutomaticReference = false
                cameraReferenceFeedback = .hidden
                cameraReferenceFeedbackRevision = UUID()
                automaticThresholdNoticeID = nil
            case .referenceRestarted, .referenceUnstable:
                cameraReferenceFeedback = .retry
                cameraReferenceFeedbackRevision = UUID()
                if event.update == .referenceUnstable, failureHints {
                    presentAutomaticNotice(level: sensitivity, isFailure: true)
                }
            case .countdown(let number):
                guard automaticThresholdNoticeID == nil, automaticAbortEmoji == nil else { return }
                automaticCountdown = number
                automaticSounds.playCountdown(number)
            case .cancelled:
                if automaticCountdown != nil {
                    CreateItemSensitivityTip.countdownAborts += 1
                    // Bewegungsbedingte Countdown-Abbrüche bleiben akustisch still.
                    if failureHints && automaticThresholdNoticeID == nil {
                        automaticAbortEmoji = ["😵", "😵‍💫", "🥴", "👻", "💩", "🫣", "😓", "🧐", "😶‍🌫️", "🫨", "🫠", "😅"].randomElement()
                        automaticAbortRevision = UUID()
                        camera.pauseMonitoringForFeedback(sessionID: event.sessionID, duration: 1.5)
                    }
                }
                automaticCountdown = nil
            case .capture:
                automaticCountdown = nil
                captureAutomaticItem()
            }
        }
        .onChange(of: camera.inactivityEvent) { _, event in
            guard let event, event.sessionID == automaticSession else { return }
            stopAutomaticMonitoring()
            showAutomaticTimeout = failureHints
        }
        .onChange(of: camera.isReady) { _, ready in
            if ready { completeAutomaticStart() }
            else { stopAutomaticMonitoring() }
        }
        .onChange(of: camera.message) { _, message in
            if message != nil, automaticSession != nil || automaticStartRequestID != nil {
                cancelAutomaticStart()
                stopAutomaticMonitoring()
                automaticSounds.playAbort()
                errorMessage = message
            }
        }
        .onChange(of: isSaveFeedbackActive) { _, saving in
            if !saving, automaticCapturePending {
                // Erst erfolgreiches Speichern beendet die Folge der abgebrochenen Versuche.
                automaticCaptureBatch = AutomaticCaptureBatch(target: AutomaticCaptureBatch.itemPhotoCount())
                automaticCapturePending = false
                isAutomaticNamingPending = false
                automaticEmoji = nil
                camera.completeAutomaticCapture()
            }
        }
    }

    private var activeForm: some View {
        // Die Navigation gehört zum Modus-Umschalter; dieses Formular liefert
        // nur seine Inhalte und Toolbar in den dauerhaft bestehenden Container.
        Group {
            Form {
                if mode == .item {
                    imageSection
                    boxSection
                    // Gegenstände beziehen ihren Standort weiterhin über die zugeordnete Kiste.
                    if selectedBox != nil || !clean(newBoxName).isEmpty { locationSection }
                    CreateItemHandlingSection(isHeavy: $isHeavy, isFragile: $isFragile)
                    // Reserve scrollable space so the floating shutter does not cover the last row.
                    if isSmartCameraEnabled && isCameraFeedEnabled {
                        Section { Color.clear.frame(height: 84) }.listRowBackground(Color.clear)
                    }
                } else {
                    CreateLocationPhotoSection(image: $locationPhoto)
                    Section {
                        ColorPicker("Color", selection: $locationColor, supportsOpacity: false)
                    }
                    locationBoxesSection
                }
            }
            .disabled(isLoadingDraft || automaticCapturePending)
            .toolbarTitleDisplayMode(.inline)
            .listRowInsets(EdgeInsets())
            .listSectionSpacing(16)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("")
            .toolbar {
                CreateFormToolbar {
                    CreateFormTitle(placeholder: mode == .item ? "Item Titel" : "Standortname", text: $title,
                                    settingsTarget: mode == .item ? "item" : nil,
                                    autofocusName: shouldFocusLocationName)
                        .disabled(isLoadingDraft || automaticCapturePending || feedbackBlur > 0)
                        .blur(radius: feedbackBlur)
                }
            }
            .overlay(alignment: .bottom) {
                if mode == .item && isSmartCameraEnabled && isCameraFeedEnabled && !isKeyboardVisible {
                    shutterOverlay.padding(.bottom, 16)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CreateSaveControls(leftButton: leftModeButton, rightButton: rightModeButton,
                                   isDisabled: isLoadingDraft || isSaving || isSaveFeedbackActive || !canSave || automaticCapturePending
                                    || isAutomaticNamingPending || (mode == .item && camera.isCapturing),
                                   color: UserDefaultsManager.loadAccentColor(), save: save)
            }
            // Die Rückmeldung umfasst auch die unteren Bedienelemente,
            // bleibt aber innerhalb der Navigation und damit unter deren Aktionen.
            .modifier(CreateCameraFeedbackOverlay(blurRadius: feedbackBlur) { cameraFeedback })
        }
        .overlay(alignment: .center) {
            // Alle Texthinweise teilen dieselbe Position und erscheinen einzeln.
            if let noticeID = automaticThresholdNoticeID {
                CreateAutomaticThresholdNotice(
                    symbol: thresholdNoticeIsFailure ? "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
                        : (thresholdNoticeLevel == .automatic ? "wand.and.sparkles.inverse" : "cellularbars"),
                    variableValue: thresholdNoticeIsFailure || thresholdNoticeLevel == .automatic
                        ? nil : Double(thresholdNoticeLevel.rawValue) / 4,
                    message: thresholdNoticeIsFailure ? "FeedMonitoring.HoldStill"
                                                     : "FeedMonitoring.AdjustingThreshold",
                    isWarning: thresholdNoticeIsFailure)
                    .id(noticeID)
                    .padding(.horizontal, 16)
                    .task {
                        do { try await Task.sleep(for: .milliseconds(3000)) }
                        catch { return }
                        guard automaticThresholdNoticeID == noticeID else { return }
                        withAnimation(.easeInOut(duration: 0.2)) { automaticThresholdNoticeID = nil }
                    }
            }
        }
        .modifier(CreateQRCodeActionFeedback(action: qrCodeAction))
        .overlay {
            if diagnosticsVisible {
                CreateFeedDiagnosticsWindow(snapshot: camera.feedDiagnostics) { diagnosticsVisible = false }
            }
        }
        .onChange(of: isSmartCameraEnabled) { _, enabled in
            if !enabled { diagnosticsVisible = false }
        }
        .onChange(of: diagnosticsVisible) { _, visible in camera.setDiagnosticsEnabled(visible) }
        .task(id: cameraReferenceFeedbackRevision) {
            guard cameraReferenceFeedback == .retry else { return }
            do { try await Task.sleep(for: .milliseconds(350)) }
            catch { return }
            cameraReferenceFeedback = isPreparingAutomaticReference ? .searching : .hidden
        }
        .sheet(isPresented: $showBoxSelection) {
            CreateLocationBoxesSheet(boxes: boxes, locations: locations, targetName: clean(title),
                                     selection: assignedBoxes) { selected in
                assignedBoxes = selected
                showBoxSelection = false
            }
        }
        .sheet(isPresented: $showGallery) { ImagePicker(selectedImages: $images) }
        .sheet(isPresented: $showCameraPicker, onDismiss: { isPopupCameraActive = false }) {
            CameraPicker(images: $images)
        }
        .alert("FeedMonitoring.TimeoutTitle", isPresented: $showAutomaticTimeout) {
            Button("OK", role: .cancel) { }
        } message: { Text("FeedMonitoring.TimeoutMessage") }
        .alert("FeedMonitoring.IntroTitle", isPresented: $showAutomaticIntroduction) {
            Button("FeedMonitoring.Start", action: startAutomaticMonitoring)
            Button("Abbrechen", role: .cancel) { }
        } message: { Text("FeedMonitoring.IntroMessage") }
        .alert(showCameraUnavailable ? "Kamera nicht verfügbar" : "Speichern nicht möglich", isPresented: Binding(
            get: { errorMessage != nil || showCameraUnavailable },
            set: { if !$0 { errorMessage = nil; showCameraUnavailable = false } }
        )) { Button("OK", role: .cancel) { errorMessage = nil; showCameraUnavailable = false } }
        message: { Text(errorMessage ?? (showCameraUnavailable ? "Wähle stattdessen ein Foto aus der Galerie." : "")) }
        .onAppear {
            initializeQuickFormIfNeeded()
            isVisible = true
            if isActive {
                if InventoryCloudFormSync.shared.isEnabled { hasLoadedDraft = false }
                Task {
                    await loadQuickDraftIfNeeded()
                    guard isVisible, isActive else { return }
                    if scenePhase == .active { InventoryHandoffStore.shared.activateForm(kind: mode.rawValue) }
                    persistQuickDraft(isInitial: true)
                }
            }
        }
        .onDisappear {
            persistQuickDraftMedia(force: true)
            persistQuickDraft()
            InventoryHandoffStore.shared.deactivateForm(kind: mode.rawValue)
            isVisible = false
            cancelAutomaticStart()
            stopAutomaticMonitoring()
            diagnosticsVisible = false
            camera.setDiagnosticsEnabled(false)
            if mode == .item { camera.stop() }
        }
    }

    private func openPopupCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showCameraUnavailable = true
            return
        }
        isPopupCameraActive = true
        Task { @MainActor in
            // Release the embedded session before UIImagePickerController claims the camera.
            await camera.pause()
            guard isVisible else { isPopupCameraActive = false; return }
            showCameraPicker = true
        }
    }

    private var imageSection: some View {
        Section {
            if isSmartCameraEnabled {
                CreateItemPhotoPanel(camera: camera, isFeedEnabled: isCameraFeedEnabled,
                                     isAutomaticActive: automaticSession != nil && !isPreparingAutomaticReference,
                                     isAutomaticRunning: automaticSession != nil,
                                     referenceFeedback: cameraReferenceFeedback,
                                     toggleDiagnostics: { diagnosticsVisible.toggle() }, images: images,
                                     openGallery: { showGallery = true }, openCamera: openPopupCamera,
                                     toggleFeed: { isCameraFeedEnabled.toggle() },
                                     rotateFeed: rotateCameraFeed,
                                     removeImage: { images.remove(at: $0) })
            } else {
                CreatePhotoStrip(images: images, openGallery: { showGallery = true },
                                 openCamera: openPopupCamera, removeImage: { images.remove(at: $0) })
            }
            if isSmartCameraEnabled, let message = camera.message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
            if showTags && !hideTags {
                CreateTagStrip(tags: tags, hasImages: !images.isEmpty,
                               color: UserDefaultsManager.loadAccentColor(),
                               clear: {
                                   imageRevision = UUID()
                                   tags = []
                               },
                               recognize: recognizeImages,
                               block: { tag in
                                   imageRevision = UUID()
                                   tags.removeAll { $0 == tag }
                                   var blocked = UserDefaultsManager.shared.loadBlockedTags()
                                   if !blocked.contains(tag) { blocked.append(tag) }
                                   UserDefaultsManager.shared.saveBlockedTags(blocked)
                               })
            }
        }
    }

    private var boxSection: some View {
        CreateChoiceSection(label: "Box", choices: boxes.map { CreateChoice(id: $0.id, name: $0.name) },
                            newEntryLabel: "Neue Kiste", selection: $selectedBox,
                            newName: $newBoxName, add: addBoxChoice, qrCodeEventID: qrCodeFeedbackID)
    }

    private var locationSection: some View {
        CreateChoiceSection(label: "Location", choices: locations.map { CreateChoice(id: $0.id, name: $0.name) },
                            newEntryLabel: "CreateView.addLocation",
                            selection: Binding(
                                get: { selectedLocation },
                                set: { value in
                                    selectedLocation = value
                                    isCreatingLocation = value == nil
                                    if value != nil { newLocationName = "" }
                                }
                            ), newName: $newLocationName, add: addLocationChoice)
    }

    private var locationBoxesSection: some View {
        Group {
            Section {
                HStack {
                    TextField("Neue Kiste", text: $newBoxName).onSubmit(addPendingBox)
                    Button(action: addPendingBox) { Image(systemName: "plus") }
                        .buttonStyle(.borderless)
                        .disabled(clean(newBoxName).isEmpty)
                }
            }
            Section {
                if !boxes.isEmpty {
                Button {
                    reloadChoices()
                    showBoxSelection = true
                } label: {
                    HStack {
                        Label("Kisten auswählen", systemImage: "shippingbox.fill")
                        Spacer()
                        Text("\(assignedBoxes.count)").foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                }
                ForEach(boxes.filter { assignedBoxes.contains($0.id) }) { box in
                    HStack {
                        Text(box.name)
                        Spacer()
                        Button(role: .destructive) { assignedBoxes.remove(box.id) } label: {
                            Image(systemName: "trash")
                        }.buttonStyle(.borderless)
                    }
                }
                ForEach(pendingBoxes.indices, id: \.self) { index in
                    HStack {
                        Text(pendingBoxes[index])
                        Spacer()
                        Button(role: .destructive) { pendingBoxes.remove(at: index) } label: {
                            Image(systemName: "trash")
                        }.buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    /// Die Rückmeldung bleibt außerhalb des unscharfen Formularinhalts.
    private var cameraFeedback: some View {
        Group {
            if automaticThresholdNoticeID != nil {
                // Der mittige Hinweis hat Vorrang vor Countdown und Abbruch-Feedback.
                EmptyView()
            } else if let emoji = automaticAbortEmoji {
                CreateAutomaticCaptureAbortFeedback(emoji: emoji)
                    .id(automaticAbortRevision)
                    .task {
                        // Neue Abbrüche ersetzen die Rückmeldung und brechen den alten Ausblend-Task ab.
                        do { try await Task.sleep(for: .milliseconds(1500)) }
                        catch { return }
                        automaticAbortEmoji = nil
                    }
            } else if let number = automaticCountdown {
                CreateCameraCountdown(number: number)
            } else if itemDictation.isListening {
                CreateAutomaticDictationFeedback(transcript: itemDictation.transcript,
                                                 audioLevel: itemDictation.audioLevel,
                                                 skip: itemDictation.skip,
                                                 question: "CreateCamera.ItemNameQuestion")
            } else if let emoji = automaticEmoji {
                // Bei Diktat erscheint der Haken erst nach dessen Ende und der
                // bestätigten Speicherung, niemals während der Namensaufnahme.
                CreateAutomaticCaptureFeedback(emoji: emoji,
                                               isSaved: showSavedConfirmation && isSaveFeedbackActive && !itemDictation.isListening)
            } else if showSavedConfirmation { CreateSavedConfirmation() }
        }
    }

    private var shutterOverlay: some View {
        CreateCameraControls(isAutomaticSelected: isAutomaticSelected,
                             isAutomaticActive: automaticSession != nil,
                             sensitivity: sensitivity,
                             isDictationSelected: !itemDictationMuted,
                             dynamicFactor: camera.dynamicChangeFactor,
                             
                             changeSensitivity: { sensitivityValue = sensitivity.next.rawValue },
                             toggleDictation: { itemDictationMuted.toggle() },
                             isReady: camera.isReady,
                             isBusy: camera.isCapturing || isSaveFeedbackActive || automaticCapturePending,
                             takePhoto: {
                                 // Ein seitlicher Auslöser wählt zunächst nur seinen Modus aus.
                                 if isAutomaticSelected {
                                     stopAutomaticMonitoring()
                                     isAutomaticSelected = false
                                     return
                                 }
                                 stopAutomaticMonitoring()
                                 camera.capture { images.append($0) }
                             }, toggleAutomatic: toggleAutomaticMonitoring, showsDictation: itemVoiceNamingEnabled)
    }

    private func addLocationChoice() {
        let name = clean(newLocationName)
        guard !name.isEmpty else { return }
        var allLocations = loadLocations()
        let location = allLocations.first { $0.name == name } ?? Locations(id: UUID(), name: name)
        if !allLocations.contains(where: { $0.id == location.id }) { allLocations.append(location) }
        guard UserDefaultsManager.shared.saveLocations(allLocations) else { return }
        locations = allLocations
        selectedLocation = location.id
        isCreatingLocation = false
        newLocationName = ""
    }

    private func addBoxChoice() {
        let name = clean(newBoxName)
        guard !name.isEmpty else { return }
        do {
            let snapshot = try InventoryPersistence.selection(locationIDs: nil)
            var updatedLocations = snapshot.locations
            var locationID = selectedLocation
            let locationName = clean(newLocationName)
            if !locationName.isEmpty {
                let location = updatedLocations.first(where: { $0.name == locationName })
                    ?? Locations(id: UUID(), name: locationName)
                if !updatedLocations.contains(where: { $0.id == location.id }) { updatedLocations.append(location) }
                locationID = location.id
            }
            let box = MovingBox(name: name, items: [], images: [], location_uuid: locationID)
                        // Nur die neue Kiste und ein tatsächlich neu angelegter Standort werden geschrieben.
            let existingLocationIDs = Set(snapshot.locations.map(\.id))
            try InventoryPersistence.mergeInventory(boxes: [box], items: [],
                                                    locations: updatedLocations.filter { !existingLocationIDs.contains($0.id) })
            boxes = loadBoxes()
            locations = updatedLocations
            selectedBox = box.id
            selectedLocation = locationID
            isCreatingLocation = false
            newLocationName = ""
            newBoxName = ""
        } catch {
            InventoryStorageState.shared.report(error)
            errorMessage = error.localizedDescription
        }
    }

    private func selectQRCodeBox(_ event: FeedBoxQRCodeEvent) {
        guard canSelectQRCodeBox, handledQRCodeEventID != event.id else { return }
        handledQRCodeEventID = event.id
        // Immer den aktuellen Bestand lesen: seit dem Öffnen des Formulars
        // können andere Ansichten oder Kurzbefehle Kisten hinzugefügt haben.
        var allBoxes = UserDefaultsManager.shared.loadBoxes()
        let box: MovingBox
        guard let target = event.code.target(existingIDs: allBoxes.map(\.id),
                                            currentID: selectedBox, allowExisting: true) else { return }
        switch target {
        case .existing(let id):
            guard let existing = allBoxes.first(where: { $0.id == id }) else { return }
            box = existing
        case .missing(let id):
            box = MovingBox(id: id, name: FeedBoxQRCode.fallbackName(for: id), items: [], images: [])
            allBoxes.append(box)
            guard UserDefaultsManager.shared.saveBoxes(allBoxes) else { return }
        case .ambiguous:
            // Ein kollidierender Kurzcode ändert die aktuelle Auswahl nicht.
            return
        }
        boxes = allBoxes
        selectedBox = box.id
        selectedLocation = box.location_uuid
        isCreatingLocation = false
        newBoxName = ""
        newLocationName = ""
        qrCodeFeedbackID = event.id
        qrCodeAction = CreateQRCodeAction(id: event.id, boxName: box.name)
        // Nur eine tatsächlich geänderte Zuordnung pausiert die Erfassung kurz.
        if let session = automaticSession {
            automaticCountdown = nil
            camera.pauseMonitoringForFeedback(sessionID: session, duration: 3)
        }
    }

    private func reloadChoices(selectDefaults: Bool = false) {
        // Ein reiner Foto-Abgleich erzeugt keine neuen Auswahl-/Autosave-Ereignisse.
        let currentBoxes = UserDefaultsManager.shared.loadBoxes()
        if boxes != currentBoxes { boxes = currentBoxes }
        let currentLocations = loadLocations()
        if locations != currentLocations { locations = currentLocations }
        // Tombstones können neu eintreffen, obwohl die lebenden Listen unverändert sind.
        let deleted = InventoryStorageState.shared.readDeletedIDs()
        if let selectedBox, deleted.boxes.contains(selectedBox) { self.selectedBox = nil }
        if let selectedLocation, deleted.locations.contains(selectedLocation) { self.selectedLocation = nil }
        // Nur beim ersten Öffnen vorbelegen; eine bewusst leere Auswahl beim Speichern beibehalten.
        if selectDefaults && selectedBox == nil && clean(newBoxName).isEmpty { selectedBox = boxes.last?.id }
        if selectDefaults && selectedLocation == nil && !isCreatingLocation && clean(newLocationName).isEmpty {
            selectedLocation = boxes.first(where: { $0.id == selectedBox })?.location_uuid ?? locations.last?.id
        }
    }

    private func addPendingBox() {
        let name = clean(newBoxName)
        guard !name.isEmpty else { return }
        pendingBoxes.append(name)
        newBoxName = ""
    }

    private func recognizeImages() {
        let revision = UUID()
        imageRevision = revision
        generateAutomaticTagsIfEnabled(from: images) { result in
            // Ignore recognition from an earlier photo set after deleting or adding a photo.
            guard imageRevision == revision else { return }
            tags = result
        }
    }

    private func rotateCameraFeed() {
        stopAutomaticMonitoring()
        camera.rotatePreviewClockwise()
    }

    private func toggleAutomaticMonitoring() {
        if automaticStartRequestID != nil { cancelAutomaticStart(); return }
        if !isAutomaticSelected {
            isAutomaticSelected = true
            return
        }
        if automaticSession != nil { stopAutomaticMonitoring(); return }
        guard shouldRunCamera, camera.isReady, !camera.isCapturing, !isSaveFeedbackActive, !isLoadingDraft else { return }
        // Auch bei abgeschaltetem Namensschema braucht ein automatisch gespeicherter Gegenstand einen Namen.
        if clean(title).isEmpty { title = automaticItemName() }
        guard canSave else {
            errorMessage = String(localized: "FeedMonitoring.SelectDestination")
            return
        }
        if automaticIntroActivations < 2 {
            showAutomaticIntroduction = true
        } else { startAutomaticMonitoring() }
    }

    /// Ein Hinweis ersetzt konkurrierende Rückmeldungen und pausiert die Messung.
    private func presentAutomaticNotice(level: FeedSensitivityLevel, isFailure: Bool = false) {
        qrCodeFeedbackID = nil
        thresholdNoticeLevel = level
        thresholdNoticeIsFailure = isFailure
        automaticCountdown = nil
        automaticAbortEmoji = nil
        if let session = automaticSession {
            camera.pauseMonitoringForFeedback(sessionID: session, duration: 3)
        }
        withAnimation(.easeInOut(duration: 0.2)) { automaticThresholdNoticeID = UUID() }
    }

    private func startAutomaticMonitoring() {
        guard shouldRunCamera, camera.isReady, !camera.isCapturing, !isSaveFeedbackActive, !isLoadingDraft,
              canSave, automaticSession == nil, isAutomaticSelected else { return }

        guard automaticStartRequestID == nil else { return }
        if !usesItemDictation || itemDictation.hasAuthorization {
            beginAutomaticMonitoring()
            return
        }
        let requestID = UUID()
        automaticStartRequestID = requestID
        automaticStartAuthorized = false
        Task { @MainActor in
            let allowed = await itemDictation.requestAuthorization()
            guard automaticStartRequestID == requestID else { return }
            guard allowed || !usesItemDictation else {
                cancelAutomaticStart()
                errorMessage = String(localized: "CreateItem.DictationPermissionsRequired")
                return
            }
            automaticStartAuthorized = true
            completeAutomaticStart()
        }
    }

    /// Kamera und Szene müssen nach dem letzten Systemdialog wieder bereit sein.
    private func completeAutomaticStart() {
        guard automaticStartRequestID != nil, automaticStartAuthorized,
              shouldRunCamera, camera.isReady else { return }
        automaticStartRequestID = nil
        automaticStartAuthorized = false
        beginAutomaticMonitoring()
    }

    private func cancelAutomaticStart() {
        guard automaticStartRequestID != nil else { return }
        automaticStartRequestID = nil
        automaticStartAuthorized = false
        itemDictation.cancel()
    }

    private func beginAutomaticMonitoring() {
        guard shouldRunCamera, camera.isReady, !camera.isCapturing, !isSaveFeedbackActive, !isLoadingDraft,
              canSave, automaticSession == nil, isAutomaticSelected else { return }

        hideKeyboard()
        automaticSounds.prepare()
        let session = UUID()
        automaticSession = session
        automaticCaptureBatch = AutomaticCaptureBatch(target: AutomaticCaptureBatch.itemPhotoCount())
        automaticBaseConfiguration = .load()
        automaticBaseConfiguration.usesDictation = usesItemDictation
        automaticIntroActivations = min(2, automaticIntroActivations + 1)
        isPreparingAutomaticReference = true
        cameraReferenceFeedback = .searching
        cameraReferenceFeedbackRevision = UUID()
        previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        camera.startMonitoring(configuration: sensitivity.configuration(basedOn: automaticBaseConfiguration), sessionID: session,
                               allowsReferenceAdjustment: sensitivity == .automatic,
                               automaticallyAdjustThresholds: sensitivity == .automatic)
    }

    private func stopAutomaticMonitoring() {
        guard automaticSession != nil else { return }
        automaticSession = nil
        automaticCapturePending = false
        isAutomaticNamingPending = false
        isPreparingAutomaticReference = false
        cameraReferenceFeedback = .hidden
        cameraReferenceFeedbackRevision = UUID()
        automaticCountdown = nil
        automaticEmoji = nil
        automaticAbortEmoji = nil
        automaticThresholdNoticeID = nil
        camera.stopMonitoring()
        itemDictation.cancel()
        automaticSounds.stop()
        UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled
    }

    private func automaticItemName() -> String {
        let name = CreateItemNameGenerator.nextName()
        return clean(name).isEmpty ? String(localized: "CreateView.Item") : name
    }

    private func captureAutomaticItem() {
        guard let session = automaticSession, shouldRunCamera, !isSaveFeedbackActive, !camera.isCapturing else {
            camera.completeAutomaticCapture(succeeded: false)
            return
        }
        if clean(title).isEmpty { title = automaticItemName() }
        guard canSave else {
            stopAutomaticMonitoring()
            automaticSounds.playAbort()
            errorMessage = String(localized: "FeedMonitoring.SelectDestination")
            return
        }
        automaticCapturePending = true
        let shouldDictate = usesItemDictation
        isAutomaticNamingPending = false
        camera.capture { photo in
            Task { @MainActor in
                // JPEG-Arbeit außerhalb des UI-Threads erledigen, dann erst den Bestand aktualisieren.
                let prepared = await AutomaticCapturePhoto.prepare(photo)
                guard automaticSession == session, shouldRunCamera else { return }
                guard let prepared else {
                    stopAutomaticMonitoring()
                    automaticSounds.playAbort()
                    errorMessage = String(localized: "FeedMonitoring.PhotoFailed")
                    return
                }
                images.append(prepared.image)
                // Erst das erfolgreich aufgenommene Foto zeigt die Rückmeldung.
                // Vor dem Diktat bleibt sie anschließend eine Sekunde sichtbar.
                automaticEmoji = ["😋", "😜", "🥳", "🥸"].randomElement()
                let dictationDeadline = ContinuousClock.now.advanced(by: .seconds(1))
                let finishesBatch = automaticCaptureBatch.recordPhoto()
                do { try await Task.sleep(until: dictationDeadline, clock: .continuous) }
                catch { return }
                guard automaticSession == session, shouldRunCamera else { return }
                guard finishesBatch else {
                    automaticCapturePending = false
                    automaticEmoji = nil
                    camera.completeAutomaticCapture()
                    return
                }
                isAutomaticNamingPending = shouldDictate
                if shouldDictate {
                    let spokenName = await itemDictation.transcribe()
                    guard automaticSession == session, shouldRunCamera else { return }
                    title = CreateAutomaticName.resolve(spoken: spokenName, fallback: automaticItemName())
                } else {
                    // Auch ohne Diktat frisch aus dem Schema erzeugen; alte Entwurfstitel nicht übernehmen.
                    title = automaticItemName()
                }
                save(preparedPhoto: prepared)
                if !isSaveFeedbackActive {
                    automaticCapturePending = false
                    stopAutomaticMonitoring()
                    automaticSounds.playAbort()
                }
            }
        }
    }

    private func save() {
        guard canSave, !isLoadingDraft, !isSaving, !isSaveFeedbackActive, !automaticCapturePending,
              !isAutomaticNamingPending, !camera.isCapturing else { return }
        // Manuelles Speichern beendet die Überwachung vor jeder Datenänderung.
        // Verspätete Countdown-Ereignisse gehören damit nicht mehr zur aktuellen Sitzung.
        cancelAutomaticStart()
        stopAutomaticMonitoring()
        save(preparedPhoto: nil)
    }

    private func save(preparedPhoto: AutomaticCapturePhoto?) {
        guard canSave, !isLoadingDraft, !isSaving, !isSaveFeedbackActive else { return }
        isSaving = true
        defer { isSaving = false }
        saveFeedbackID = UUID()
        let feedbackID = saveFeedbackID
        showSavedConfirmation = false
        isSaveFeedbackActive = true
        let manager = UserDefaultsManager.shared
        let snapshot: InventorySnapshot
        let creationID: UUID
        // Handoff ist eine Ergänzung zum normalen Speichern. Ein zu großer oder
        // vorübergehend nicht übertragbarer Stand darf den Inventar-Commit nicht sperren.
        do { try draftStore.save(draftSnapshot, for: mode) }
        catch InventoryHandoffError.incomingPending {
            // Diese View besitzt den gerade eingehenden Formularstand noch nicht.
            // Ein alter Auslöser darf dessen UUID nicht mit früheren Eingaben speichern.
            cancelSaveAnimation()
            return
        }
        catch { print("Handoff-Formular ist derzeit nicht übertragbar: \(error)") }
        do {
            let draftID = InventoryHandoffStore.shared.activeFormID(kind: mode.rawValue) ?? transientCreationID
            // Frische Existenzprüfung ausschließlich für die konkrete Formularauswahl.
            snapshot = try InventoryPersistence.selection(
                boxIDs: Array(assignedBoxes) + (selectedBox.map { [$0] } ?? []),
                itemIDs: mode == .item ? [draftID] : [],
                locationIDs: (selectedLocation.map { [$0] } ?? [])
                    + (mode == .location ? [draftID] : []))
            if InventoryDraftIdentity.isCompleted(draftID, kind: mode.rawValue, in: snapshot) {
                errorMessage = "Dieses Formular wurde bereits gespeichert. Die Daten findest du in der Liste."
                cancelSaveAnimation()
                return
            }
            // Dieselbe Sitzungs-UUID reist mit Handoff. Ohne verfügbare Activity
            // bleibt die lokale UUID bis zum erfolgreich gespeicherten Formular stabil.
            creationID = draftID
        } catch {
            InventoryStorageState.shared.report(error)
            errorMessage = error.localizedDescription
            cancelSaveAnimation()
            return
        }
        var allBoxes = snapshot.boxes
        var allLocations = snapshot.locations
        var changedBoxes: [MovingBox] = []
        var createdLocations: [Locations] = []
        var createdImageNames: [String] = []
        var createdItem: Items?
        let locationID: UUID?
        if mode == .location {
            var imagePath = ""
            if let locationPhoto {
                // Persist the photo before changing databases; retain the draft if saving fails.
                guard let data = locationPhoto.compressImage(),
                      let url = manager.saveImage(data, withName: "\(UUID().uuidString).jpg") else {
                    errorMessage = "Das Standortfoto konnte nicht gespeichert werden. Bitte erneut versuchen."
                    cancelSaveAnimation()
                    return
                }
                imagePath = url.lastPathComponent
                createdImageNames.append(imagePath)
            }
            let newLocationID = creationID
            locationID = newLocationID
            let location = Locations(id: newLocationID, name: clean(title),
                                     color: colorToString(locationColor) ?? "0,0.5,1", image: imagePath)
            allLocations.append(location)
            createdLocations.append(location)
            if !clean(newBoxName).isEmpty { addPendingBox() }
            for index in allBoxes.indices where assignedBoxes.contains(allBoxes[index].id)
                && allBoxes[index].location_uuid != locationID {
                allBoxes[index].location_uuid = locationID
                changedBoxes.append(allBoxes[index])
            }
            let newBoxes = pendingBoxes.enumerated().map {
                MovingBox(id: InventoryDraftIdentity.component("box-\($0.offset)", of: creationID),
                          name: $0.element, items: [], images: [], location_uuid: locationID)
            }
            allBoxes += newBoxes
            changedBoxes += newBoxes
        } else {
            if clean(newBoxName).isEmpty, let selectedBox, !allBoxes.contains(where: { $0.id == selectedBox }) {
                errorMessage = "Die gewählte Kiste existiert nicht mehr. Bitte erneut auswählen."
                reloadChoices()
                cancelSaveAnimation()
                return
            }
            let hasBoxAssignment = selectedBox != nil || !clean(newBoxName).isEmpty
            if !hasBoxAssignment {
                locationID = nil
            } else if clean(newLocationName).isEmpty, let selectedLocation {
                guard allLocations.contains(where: { $0.id == selectedLocation }) else {
                    errorMessage = "Bitte einen vorhandenen oder neuen Standort auswählen."
                    cancelSaveAnimation()
                    return
                }
                locationID = selectedLocation
            } else if !clean(newLocationName).isEmpty {
                let newLocationID = InventoryDraftIdentity.component("item-location", of: creationID)
                locationID = newLocationID
                let location = Locations(id: newLocationID, name: clean(newLocationName))
                allLocations.append(location)
                createdLocations.append(location)
            } else {
                locationID = nil
            }
            // Save every photo before changing databases; clean up partial writes on failure.
            var paths: [String] = []
            for (index, image) in images.enumerated() {
                guard let data = index == images.count - 1 ? preparedPhoto?.data ?? image.compressImage() : image.compressImage(),
                      let url = manager.saveImage(data, withName: "\(UUID().uuidString).jpg") else {
                    paths.forEach { manager.deleteImage(named: $0) }
                    errorMessage = "Ein Foto konnte nicht gespeichert werden. Bitte erneut versuchen."
                    cancelSaveAnimation()
                    return
                }
                paths.append(url.lastPathComponent)
            }
            let boxID: UUID?
            if clean(newBoxName).isEmpty, let selectedBox, let index = allBoxes.firstIndex(where: { $0.id == selectedBox }) {
                boxID = selectedBox
                if allBoxes[index].location_uuid != locationID {
                    allBoxes[index].location_uuid = locationID
                    changedBoxes.append(allBoxes[index])
                }
            } else if !clean(newBoxName).isEmpty {
                let newBoxID = InventoryDraftIdentity.component("item-box", of: creationID)
                boxID = newBoxID
                let box = MovingBox(id: newBoxID, name: clean(newBoxName), items: [], images: [], location_uuid: locationID)
                allBoxes.append(box)
                changedBoxes.append(box)
            } else {
                boxID = nil
            }
            let item = Items(id: creationID, name: clean(title), box_uuid: boxID, images: paths,
                             isFragile: isFragile, isHeavy: isHeavy, tags: tags)
            createdItem = item
            createdImageNames += paths
            selectedBox = boxID
        }
        do {
            // Nur tatsächlich erzeugte/geänderte Objekte gehören zu diesem Formular-Commit.
            // Unveränderte Snapshot-Kopien können neue Cloud-Daten weder löschen noch überschreiben.
            try InventoryPersistence.mergeInventory(boxes: changedBoxes,
                                                    items: createdItem.map { [$0] } ?? [], locations: createdLocations)
        } catch {
            createdImageNames.forEach { manager.deleteImage(named: $0) }
            InventoryStorageState.shared.report(error)
            errorMessage = error.localizedDescription
            cancelSaveAnimation()
            return
        }
        if let createdItem {
            // Erst nach dem Commit darf OCR den gespeicherten Gegenstand ergänzen.
            generateAutomaticTagsIfEnabled(from: images) { recognizedTags in
                var storedItems = manager.loadItems()
                guard let index = storedItems.firstIndex(where: { $0.id == createdItem.id }),
                      storedItems[index].images == createdItem.images else { return }
                storedItems[index].tags = recognizedTags
                manager.saveItems(storedItems)
            }
        }
        if mode == .item {
            CreateItemNameGenerator.advanceNumberIfEnabled()
        }
        selectedLocation = locationID
        isCreatingLocation = false
        title = mode == .item ? CreateItemNameGenerator.nextName() : ""
        locationPhoto = nil
        if mode == .location { locationColor = randomColor() }
        images = []
        tags = []
        isFragile = false
        isHeavy = false
        newBoxName = ""
        newLocationName = ""
        pendingBoxes = []
        assignedBoxes = []
        reloadChoices()
        // Nur diese Handoff-Sitzung abschließen; andere Formulare behalten ihre Eingaben.
        draftStore.clear(for: mode)
        transientCreationID = UUID()
        draftImageFileNames = []
        draftLocationImageFileName = nil
        cachedDraftImages = []
        cachedDraftLocationPhoto = nil
        lastSavedEmptyDraft = draftSnapshot
        hideKeyboard()
        withAnimation(.linear(duration: 0.45)) {
            showSavedConfirmation = true
            // Beide Formularmodi blenden den Blur auch beim manuellen Speichern ein.
            formBlur = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            guard saveFeedbackID == feedbackID else { return }
            withAnimation(.linear(duration: 0.45)) {
                showSavedConfirmation = false
                formBlur = 0
            }
            // Die Sperre umfasst auch die weich ausblendende Bestätigung.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                guard saveFeedbackID == feedbackID else { return }
                isSaveFeedbackActive = false
            }
        }
    }

    private func cancelSaveAnimation() {
        withAnimation(.linear(duration: 0.2)) { formBlur = 0 }
        isSaveFeedbackActive = false
    }

    private var draftSnapshot: QuickCreateDraft {
        QuickCreateDraft(title: title, selectedBox: selectedBox, selectedLocation: selectedLocation,
                         isCreatingLocation: isCreatingLocation, newBoxName: newBoxName,
                         newLocationName: newLocationName, pendingBoxes: pendingBoxes,
                         assignedBoxes: assignedBoxes, locationColor: colorToString(locationColor) ?? "0,0.5,1",
                         tags: tags, isFragile: isFragile, isHeavy: isHeavy,
                         imageFileNames: draftImageFileNames, locationImageFileName: draftLocationImageFileName)
    }

    @MainActor
    private func loadQuickDraftIfNeeded() async {
        guard !Task.isCancelled, !hasLoadedDraft else { return }
        initializeQuickFormIfNeeded()
        let request = UUID()
        draftLoadGeneration = request
        hasLoadedDraft = true
        guard let draft = draftStore.load(for: mode) else {
            isLoadingDraft = false
            return
        }
        let draftID = InventoryHandoffStore.shared.activeFormID(kind: mode.rawValue)
        if let draftID { transientCreationID = draftID }
        isLoadingDraft = true
        defer {
            // Die Abschlussmeldung gehört ausschließlich zum aktuellen Ladeauftrag.
            if draftLoadGeneration == request {
                isLoadingDraft = false
                if Task.isCancelled { hasLoadedDraft = false }
            }
        }
        // Die übertragene Kistenauswahl darf den separat übertragenen Standort und
        // neue Namen nicht durch ihren normalen Auswahl-Callback ersetzen.
        ignoreNextBoxSelectionChange = selectedBox != draft.selectedBox
        title = draft.title
        selectedBox = draft.selectedBox
        selectedLocation = draft.selectedLocation
        isCreatingLocation = draft.isCreatingLocation
        newBoxName = draft.newBoxName
        newLocationName = draft.newLocationName
        pendingBoxes = draft.pendingBoxes
        assignedBoxes = draft.assignedBoxes
        locationColor = stringToColor(draft.locationColor) ?? randomColor()
        tags = draft.tags
        isFragile = draft.isFragile ?? false
        isHeavy = draft.isHeavy ?? false
        draftImageFileNames = draft.imageFileNames
        draftLocationImageFileName = draft.locationImageFileName
        let photos = await CreateDraftImageLoader.load(
            imageURLs: draft.imageFileNames.compactMap { draftStore.imageURL(named: $0, for: mode) },
            locationURL: draft.locationImageFileName.flatMap { draftStore.imageURL(named: $0, for: mode) }
        )
        // Während des Dekodierens kann ein anderer Entwurf ausgewählt worden sein.
        // Dessen Namen, Dateireferenzen und Fotos bleiben als zusammengehöriger Stand erhalten.
        guard !Task.isCancelled, draftLoadGeneration == request,
              InventoryHandoffStore.shared.activeFormID(kind: mode.rawValue) == draftID else { return }
        ignoreNextImageChange = images != photos.images
        images = photos.images
        ignoreNextLocationPhotoChange = locationPhoto != photos.locationPhoto
        locationPhoto = photos.locationPhoto
        cachedDraftImages = photos.images
        cachedDraftLocationPhoto = photos.locationPhoto
    }

    /// Auch eine noch unsichtbare erhaltene View kann zuerst einen Handoff empfangen.
    /// Lokale Defaults deshalb einmal vor dem Laden setzen; onAppear überschreibt
    /// anschließend weder einen leeren übertragenen Titel noch dessen Zuordnungen.
    private func initializeQuickFormIfNeeded() {
        guard !hasInitializedForm else { return }
        hasInitializedForm = true
        FeedSensitivityLevel.prepareDefaults()
        if mode == .item, title.isEmpty { title = CreateItemNameGenerator.nextName() }
        reloadChoices(selectDefaults: true)
    }

    private func persistQuickDraft(isInitial: Bool = false) {
        guard isActive, isVisible, hasLoadedDraft, !isLoadingDraft,
              draftSnapshot != lastSavedEmptyDraft else { return }
        do { try draftStore.save(draftSnapshot, for: mode, isInitial: isInitial) }
        catch { print("Handoff-Formular konnte nicht aktualisiert werden: \(error)") }
    }

    private func persistQuickDraftMedia(force: Bool = false) {
        guard (force || (isActive && isVisible)), hasLoadedDraft, !isLoadingDraft else { return }
        // Wiederöffnen oder Schließen darf unveränderte Fotos nicht erneut hochladen.
        guard images != cachedDraftImages || locationPhoto != cachedDraftLocationPhoto else { return }
        if images.isEmpty && locationPhoto == nil && draftSnapshot == lastSavedEmptyDraft { return }
        do {
            let imageData = try images.map { image -> Data in
                guard let data = image.compressImage() else { throw DraftImageError.encodingFailed }
                return data
            }
            var photoData: Data?
            if let locationPhoto {
                guard let data = locationPhoto.compressImage() else { throw DraftImageError.encodingFailed }
                photoData = data
            }
            let saved = try draftStore.replaceMedia(in: draftSnapshot, images: imageData,
                                                    locationImage: photoData, for: mode)
            draftImageFileNames = saved.imageFileNames
            draftLocationImageFileName = saved.locationImageFileName
            lastSavedEmptyDraft = nil
            cachedDraftImages = images
            cachedDraftLocationPhoto = locationPhoto
        } catch {
            print("Handoff-Fotos konnten nicht aktualisiert werden: \(error)")
        }
    }

    private enum DraftImageError: Error { case encodingFailed }

    private func clean(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
}

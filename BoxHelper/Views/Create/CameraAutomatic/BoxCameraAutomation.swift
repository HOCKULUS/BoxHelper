import SwiftUI
import Combine
import UIKit

/// Der Ablauf lebt am Formular statt an der scrollenden Fotozeile. So bleiben
/// Auslöser, Countdown und eine laufende Bildserie beim Scrollen erhalten.
@MainActor
final class BoxCameraAutomation: ObservableObject {
    let camera = EmbeddedItemCamera()
    let dictation = AutomaticItemDictation()
    let locationDictation = AutomaticLocationDictation {
        colorToString(randomColor()) ?? "0.5,0.5,0.5"
    }
    private var captureBatch = AutomaticCaptureBatch(target: BoxAutomaticCapturePolicy.defaultPhotoCount)
    private let sounds = AutomaticCaptureSounds()
    private var subscriptions = Set<AnyCancellable>()
    private var cameraRunning = false
    private var previousIdleTimerDisabled = false
    private var startRequestID: UUID?
    private var startAuthorized = false
    private var referenceFeedbackTask: Task<Void, Never>?

    // Nur die Moduswahl merken; eine Erfassung wird weiterhin ausdrücklich gestartet.
    @Published var automaticSelected = UserDefaults.standard.bool(forKey: CreateCameraPreferences.boxAutomaticModeKey) {
        didSet {
            UserDefaults.standard.set(automaticSelected, forKey: CreateCameraPreferences.boxAutomaticModeKey)
        }
    }
    @Published private(set) var sessionID: UUID?
    @Published private(set) var referenceFeedback: CameraReferenceFeedbackState = .hidden
    @Published private(set) var countdown: Int?
    @Published private(set) var emoji: String?
    @Published private(set) var abortEmoji: String?
    @Published private(set) var abortRevision = UUID()
    @Published private(set) var noticeID: UUID?
    @Published private(set) var isCompleting = false
    @Published private(set) var isSaving = false
    @Published var diagnosticsVisible = false
    @Published var errorMessage: String?
    @Published var showTimeout = false

    // Die Formular-Callbacks lesen die aktuellen SwiftUI-Bindings, auch nach dem Zurücksetzen.
    var canCapture: () -> Bool = { false }
    var appendPhoto: (UIImage) -> Void = { _ in }
    var saveNamedBox: (String?, LocationDictationSelection?) -> Bool = { _, _ in false }
    var selectedLocationID: () -> UUID? = { nil }

    var isStarting: Bool { startRequestID != nil }
    var sensitivity: FeedSensitivityLevel {
        FeedSensitivityLevel(rawValue: UserDefaults.standard.integer(forKey: FeedSensitivityLevel.storageKey)) ?? .automatic
    }
    // Einstellungen bestimmen die erlaubten Diktate; die Hilfstaste pausiert nur den Ton.
    @Published var dictationMuted = false {
        didSet { updateConfiguration() }
    }
    var voiceNamingEnabled: Bool {
        !dictationMuted && (UserDefaults.standard.object(forKey: BoxAutomaticCapturePolicy.voiceNamingKey) as? Bool ?? true)
    }
    var locationNamingEnabled: Bool {
        !dictationMuted && (UserDefaults.standard.object(forKey: BoxAutomaticCapturePolicy.locationNamingKey) as? Bool ?? true)
    }
    private var usesSpeech: Bool { voiceNamingEnabled || locationNamingEnabled }
    private var hintsEnabled: Bool { UserDefaults.standard.object(forKey: FeedSensitivityLevel.hintsKey) as? Bool ?? true }
    // Countdown-Abbrüche verändern die Schärfe des Formulars nicht.
    var feedbackBlur: CGFloat { emoji != nil || isCompleting ? 10 : 0 }

    init() {
        // Auch Änderungen der Kamera und des Diktats aktualisieren die festen Formular-Overlays.
        camera.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &subscriptions)
        locationDictation.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &subscriptions)
        dictation.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &subscriptions)
        camera.$monitoringEvent.sink { [weak self] event in
            if let event { self?.handle(event) }
        }.store(in: &subscriptions)
        camera.$inactivityEvent.sink { [weak self] event in
            guard let self, let event, event.sessionID == self.sessionID else { return }
            self.stopMonitoring()
            self.showTimeout = self.hintsEnabled
        }.store(in: &subscriptions)
        camera.$isReady.sink { [weak self] ready in
            if ready { DispatchQueue.main.async { [weak self] in self?.completeStart() } }
            else { self?.stopMonitoring() }
        }.store(in: &subscriptions)
        camera.$message.sink { [weak self] message in
            guard let self, let message, self.sessionID != nil || self.isStarting else { return }
            self.stopMonitoring()
            self.errorMessage = message
        }.store(in: &subscriptions)
        camera.$repeatedAbortEvent.sink { [weak self] event in
            guard let self, let event, event.sessionID == self.sessionID, self.hintsEnabled else { return }
            self.presentNotice()
        }.store(in: &subscriptions)
    }

    func synchronizeCamera(running: Bool, preserveAuthorization: Bool = false) {
        cameraRunning = running
        if running {
            camera.start()
            completeStart()
        } else if !preserveAuthorization {
            stopMonitoring()
            camera.setDiagnosticsEnabled(false)
            diagnosticsVisible = false
            camera.stop()
        }
    }

    /// Formularkopien in den Callbacks beim Verlassen freigeben, damit kein Besitzzyklus bleibt.
    func releaseFormCallbacks() {
        canCapture = { false }
        appendPhoto = { _ in }
        saveNamedBox = { _, _ in false }
        selectedLocationID = { nil }
    }

    func takePhoto() {
        stopMonitoring()
        if automaticSelected { automaticSelected = false; return }
        guard cameraRunning else { return }
        camera.capture { [weak self] photo in
            guard let self, self.cameraRunning else { return }
            self.appendPhoto(photo)
        }
    }

    func toggleMonitoring() {
        if isStarting || sessionID != nil { stopMonitoring(); return }
        if !automaticSelected { automaticSelected = true; return }
        startMonitoring()
    }

    private func startMonitoring() {
        guard cameraRunning, camera.isReady, !camera.isCapturing, !isCompleting else { return }
        guard canCapture() else {
            errorMessage = String(localized: "CreateCamera.BoxSelectLocation")
            return
        }
        if !usesSpeech || dictation.hasAuthorization { beginMonitoring(); return }
        let request = UUID()
        startRequestID = request
        startAuthorized = false
        Task { [weak self] in
            guard let self else { return }
            let allowed = await self.dictation.requestAuthorization()
            guard self.startRequestID == request else { return }
            guard allowed || !self.usesSpeech else {
                self.stopMonitoring()
                self.errorMessage = String(localized: "CreateItem.DictationPermissionsRequired")
                return
            }
            self.startAuthorized = true
            self.completeStart()
        }
    }

    private func completeStart() {
        guard isStarting, startAuthorized, cameraRunning, camera.isReady else { return }
        startRequestID = nil
        startAuthorized = false
        beginMonitoring()
    }

    private func beginMonitoring() {
        guard cameraRunning, camera.isReady, canCapture(), automaticSelected, sessionID == nil else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        sounds.prepare()
        let session = UUID()
        sessionID = session
        captureBatch = AutomaticCaptureBatch(target: BoxAutomaticCapturePolicy.photoCount())
        previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        referenceFeedback = .searching
        camera.startMonitoring(configuration: configuration(), sessionID: session,
                               allowsReferenceAdjustment: sensitivity == .automatic,
                               automaticallyAdjustThresholds: sensitivity == .automatic)
    }

    func stopMonitoring() {
        referenceFeedbackTask?.cancel()
        referenceFeedbackTask = nil
        startRequestID = nil
        startAuthorized = false
        if sessionID != nil { UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled }
        sessionID = nil
        countdown = nil
        referenceFeedback = .hidden
        emoji = nil
        abortEmoji = nil
        noticeID = nil
        isCompleting = false
        isSaving = false
        camera.stopMonitoring()
        dictation.cancel()
        locationDictation.cancel()
        sounds.stop()
    }

    func updateConfiguration() {
        if usesSpeech, sessionID != nil, !dictation.hasAuthorization {
            stopMonitoring()
            startMonitoring()
            return
        }
        if let sessionID {
            camera.updateMonitoringConfiguration(configuration(), sessionID: sessionID,
                                                 automaticallyAdjustThresholds: sensitivity == .automatic)
        }
    }

    private func configuration() -> FeedMonitoringConfiguration {
        var base = FeedMonitoringConfiguration.load()
        base.usesDictation = usesSpeech
        return sensitivity.configuration(basedOn: base)
    }

    func pauseForQRCode() {
        guard let sessionID else { return }
        countdown = nil
        abortEmoji = nil
        noticeID = nil
        camera.pauseMonitoringForFeedback(sessionID: sessionID, duration: 3)
    }

    func finishSavedBox() {
        guard isSaving else { return }
        isSaving = false
        isCompleting = false
        emoji = nil
        captureBatch = AutomaticCaptureBatch(target: BoxAutomaticCapturePolicy.photoCount())
        camera.completeAutomaticCapture()
    }

    func clearAbortFeedback() { abortEmoji = nil }
    func clearNotice() { noticeID = nil }

    private func presentNotice() {
        guard let sessionID else { return }
        countdown = nil
        abortEmoji = nil
        noticeID = UUID()
        camera.pauseMonitoringForFeedback(sessionID: sessionID, duration: 3)
    }

    private func handle(_ event: FeedMonitoringStatusEvent) {
        guard event.sessionID == sessionID, cameraRunning else { return }
        switch event.update {
        case .referenceReady:
            referenceFeedbackTask?.cancel()
            referenceFeedbackTask = nil
            referenceFeedback = .hidden
        case .referenceRestarted, .referenceUnstable:
            // Wie in der Item-Form kurz rot signalisieren, danach wieder blinken.
            // Jede neue Meldung ersetzt den Timer; eine alte Sitzung darf den
            // Fokuszustand einer späteren Aufnahme nicht verändern.
            referenceFeedbackTask?.cancel()
            referenceFeedback = .retry
            referenceFeedbackTask = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(350)) }
                catch { return }
                guard let self, self.sessionID == event.sessionID,
                      self.referenceFeedback == .retry else { return }
                self.referenceFeedback = .searching
            }
            if event.update == .referenceUnstable, hintsEnabled { presentNotice() }
        case .countdown(let number):
            guard noticeID == nil, abortEmoji == nil else { return }
            countdown = number
            sounds.playCountdown(number)
        case .cancelled:
            if countdown != nil {
                CreateItemSensitivityTip.countdownAborts += 1
                if hintsEnabled {
                    abortEmoji = ["😵", "🥴", "🫣", "🫠"].randomElement()
                    abortRevision = UUID()
                    camera.pauseMonitoringForFeedback(sessionID: event.sessionID, duration: 1.5)
                }
            }
            countdown = nil
        case .capture:
            countdown = nil
            captureAutomatically(session: event.sessionID)
        }
    }

    /// Die Nutzung entspricht der Anzahl gespeicherter Kisten am Standort.
    private func locationChoices() -> [LocationDictationChoice] {
        let boxes = UserDefaultsManager.shared.loadBoxes()
        return loadLocations().map { location in
            LocationDictationChoice(id: location.id, name: location.name, color: location.color,
                                    usageCount: boxes.filter { $0.location_uuid == location.id }.count)
        }
    }

    private func captureAutomatically(session: UUID) {
        guard cameraRunning, sessionID == session, canCapture(), !camera.isCapturing else {
            camera.completeAutomaticCapture(succeeded: false)
            return
        }
        isCompleting = true
        camera.capture { [weak self] photo in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let prepared = await AutomaticCapturePhoto.prepare(photo)
                guard self.sessionID == session, self.cameraRunning else { return }
                guard let prepared else {
                    self.stopMonitoring()
                    self.errorMessage = String(localized: "FeedMonitoring.PhotoFailed")
                    return
                }
                self.appendPhoto(prepared.image)
                // Das Emoji bestätigt erst ein erfolgreich aufgenommenes Foto.
                self.emoji = ["😋", "😜", "🥳", "🥸"].randomElement()
                let feedbackDeadline = ContinuousClock.now.advanced(by: .seconds(1))
                // Nur neue Automatikbilder zählen zur Serie; Entwurfsbilder bleiben erhalten.
                let finishesBatch = self.captureBatch.recordPhoto()
                do { try await Task.sleep(until: feedbackDeadline, clock: .continuous) }
                catch { return }
                guard self.sessionID == session, self.cameraRunning else { return }
                if finishesBatch {
                    // Erst das letzte Foto einer Kiste startet Diktat und Speicherung.
                    let spokenName = self.voiceNamingEnabled ? await self.dictation.transcribe() : nil
                    guard self.sessionID == session, self.cameraRunning else { return }
                    let location = self.locationNamingEnabled
                        ? await self.locationDictation.transcribe(choices: self.locationChoices(),
                                                                 preferredID: self.selectedLocationID()) : nil
                    guard self.sessionID == session, self.cameraRunning else { return }
                    self.isSaving = true
                    guard self.saveNamedBox(spokenName, location) else {
                        self.stopMonitoring()
                        if self.errorMessage == nil { self.errorMessage = String(localized: "CreateCamera.BoxSaveFailed") }
                        return
                    }
                    // Der Formular-Callback beendet erst nach bestätigter Speicherung und Animation.
                } else {
                    self.emoji = nil
                    self.isCompleting = false
                    self.camera.completeAutomaticCapture()
                }
            }
        }
    }
}

import AVFoundation
import CoreImage
import ImageIO
import SwiftUI
import UIKit

/// Capture configuration and frame requests belong to the serial queue; UI state belongs to main.
final class EmbeddedItemCamera: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate,
                                AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    @Published private(set) var isReady = false
    @Published private(set) var isCapturing = false
    @Published private(set) var message: String?
    @Published private(set) var boxQRCodeEvent: FeedBoxQRCodeEvent?
    @Published private(set) var monitoringEvent: FeedMonitoringStatusEvent?
    @Published private(set) var inactivityEvent: FeedMonitoringEvent?
    @Published private(set) var dynamicChangeFactor = 1.0
    @Published private(set) var feedDiagnostics = FeedDiagnosticsSnapshot()
    @Published private(set) var saliencyRegions: [CGRect] = []
    @Published private(set) var repeatedAbortEvent: FeedMonitoringEvent?
    @Published private(set) var thresholdAdjustmentEvent: FeedMonitoringEvent?
    private let coordinator = EmbeddedCameraSessionCoordinator.shared
    private var queue: DispatchQueue { coordinator.queue }
    private lazy var photoOutput = AVCapturePhotoOutput()
    private lazy var frameOutput = AVCaptureVideoDataOutput()
    private lazy var imageContext = CIContext()
    private var currentDetections: [CGRect] = []
    private var objectFinder: FeedObjectFinder?
    private var qrCodeScanner: FeedBoxQRCodeScanner?
    private var currentQRCodeEvent: FeedBoxQRCodeEvent?
    private let usesVideoFrames = ProcessInfo.processInfo.isiOSAppOnMac
    private var configured = false
    private var needsSessionReconfiguration = false
    private lazy var sessionRecovery = EmbeddedCameraSessionRecovery(session: session, queue: queue) { [weak self] event in
        self?.handleSessionEvent(event)
    }
    private var previewRotation = EmbeddedCameraRotation()
    private var previewRotationAngle: CGFloat { previewRotation.angle }
    // Die Vorschau ist ein eigener AVFoundation-Layer. Session und Verbindung
    // werden auf der Capture-Queue verändert; UIView-Geometrie bleibt auf Main.
    private weak var previewConnection: EmbeddedCameraPreviewConnection?
    private var wantsRunning = false
    private var pendingFrameID: UUID?
    private var pendingPhotoID: Int64?
    private var completion: ((UIImage) -> Void)?
    private var detector: FeedChangeDetector?
    private var monitoringSessionID: UUID?
    private var monitoringTimer: DispatchSourceTimer?
    private var monitoringBusy = false
    private var diagnosticsEnabled = false
    private var capturedPhotoCount = 0
    private var diagnosticPhotoWasCaptured = false

    deinit { monitoringTimer?.cancel() }

    func startMonitoring(configuration: FeedMonitoringConfiguration, sessionID: UUID,
                         allowsReferenceAdjustment: Bool = true, automaticallyAdjustThresholds: Bool = false) {
        queue.async { [self] in
            guard self.configured, self.wantsRunning, self.frameOutput.connection(with: .video) != nil else {
                self.setMessage("Die Kameraüberwachung konnte nicht gestartet werden.")
                return
            }
            self.stopMonitoringOnQueue()
            self.monitoringSessionID = sessionID
            self.detector = FeedChangeDetector(configuration: configuration, now: ProcessInfo.processInfo.systemUptime,
                                               allowsReferenceAdjustment: allowsReferenceAdjustment,
                                               automaticallyAdjustThresholds: automaticallyAdjustThresholds)

            self.frameOutput.connection(with: .video)?.isEnabled = true
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(200))
            timer.setEventHandler { [weak self] in
                guard let self, let detector = self.detector else { return }
                let now = ProcessInfo.processInfo.systemUptime
                guard detector.hasTimedOut(at: now) else { return }
                self.stopMonitoringOnQueue()
                let event = FeedMonitoringEvent(sessionID: sessionID)
                DispatchQueue.main.async { self.inactivityEvent = event }
            }
            self.monitoringTimer = timer
            timer.resume()
        }
    }

    func stopMonitoring() { queue.async { self.stopMonitoringOnQueue() } }

    /// Das Formular aktiviert QR-Erkennung ausschließlich für eine laufende Erfassung.
    func setQRCodeScanningEnabled(_ enabled: Bool) {
        queue.async {
            self.qrCodeScanner = enabled ? (self.qrCodeScanner ?? FeedBoxQRCodeScanner()) : nil
            if !enabled { self.publishQRCodeEvent(nil) }
            self.updateFrameAnalysisConnection()
        }
    }

    /// Die Fotoüberwachung darf den weiterhin benötigten QR-Stream nicht abschalten.
    private func updateFrameAnalysisConnection() {
        frameOutput.connection(with: .video)?.isEnabled = usesVideoFrames || detector != nil || qrCodeScanner != nil
    }

    private func publishQRCodeEvent(_ event: FeedBoxQRCodeEvent?) {
        guard currentQRCodeEvent != event else { return }
        currentQRCodeEvent = event
        DispatchQueue.main.async { self.boxQRCodeEvent = event }
    }

    /// Alle Rückmeldungen pausieren dieselbe serielle Erfassung statt nur das UI zu verdecken.
    func pauseMonitoringForFeedback(sessionID: UUID, duration: Double) {
        queue.async {
            guard self.monitoringSessionID == sessionID else { return }
            self.detector?.pauseForFeedback(at: ProcessInfo.processInfo.systemUptime, duration: duration)
        }
    }

    func setDiagnosticsEnabled(_ enabled: Bool) {
        queue.async {
            self.diagnosticsEnabled = enabled
            if enabled { self.publishDiagnostics() }
        }
    }

    /// Die Kamera publiziert nur bereits analysierte Frames, keine zusätzliche Video-Abtastrate.
    private func publishDiagnostics() {
        // Der Level-Bogen ist normales Feedback, unabhängig vom Diagnose-Overlay.
        let factor = detector?.diagnostics.dynamicChangeFactor ?? 1
        DispatchQueue.main.async {
            if self.dynamicChangeFactor != factor { self.dynamicChangeFactor = factor }
        }
        guard diagnosticsEnabled else { return }
        var snapshot = detector?.diagnostics ?? FeedDiagnosticsSnapshot()
        snapshot.capturedPhotos = capturedPhotoCount
        if diagnosticPhotoWasCaptured, snapshot.phase == .capturing { snapshot.phase = .captured }
        DispatchQueue.main.async {
            if self.feedDiagnostics != snapshot { self.feedDiagnostics = snapshot }
        }
    }

    func updateMonitoringConfiguration(_ configuration: FeedMonitoringConfiguration, sessionID: UUID,
                                       automaticallyAdjustThresholds: Bool = false) {
        queue.async {
            guard self.monitoringSessionID == sessionID else { return }
            self.detector?.updateConfiguration(configuration, automaticallyAdjustThresholds: automaticallyAdjustThresholds)
            self.detector?.allowsReferenceAdjustment = automaticallyAdjustThresholds
            if !configuration.usesObjectness {
                self.objectFinder = nil
                self.publishSaliencyRegions([])
            }
        }
    }

    func completeAutomaticCapture(succeeded: Bool = true) {
        queue.async {
            self.monitoringBusy = false
            self.detector?.captureCompleted(at: ProcessInfo.processInfo.systemUptime, succeeded: succeeded)
        }
    }

    private func stopMonitoringOnQueue() {
        monitoringTimer?.cancel()
        monitoringTimer = nil
        detector = nil
        objectFinder = nil
        currentDetections = []
        publishSaliencyRegions([])
        monitoringSessionID = nil
        monitoringBusy = false
        diagnosticPhotoWasCaptured = false
        publishDiagnostics()
        updateFrameAnalysisConnection()
    }

    func start() {
        // Den Start explizit stark halten; der gespeicherte Stop-Callback bleibt
        // schwach, damit der gemeinsame Coordinator die Kamera nicht festhält.
        queue.async { [self] in
            // Der Wunsch zu laufen ist kein Beweis für eine laufende Session.
            // Nach einem Systemfehler muss derselbe Feed erneut startbar bleiben.
            guard !self.wantsRunning || !self.session.isRunning else { return }
            self.coordinator.claim(self) { [weak self] in self?.stopOnQueue() }
            self.sessionRecovery.reset()
            self.wantsRunning = true
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: self.configureAndStart()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    self.queue.async {
                        guard self.wantsRunning else { return }
                        if granted { self.configureAndStart() }
                        else { self.setMessage("Kamerazugriff in den Einstellungen erlauben oder Fotos auswählen.") }
                    }
                }
            default: self.setMessage("Kamerazugriff in den Einstellungen erlauben oder Fotos auswählen.")
            }
        }
    }

    func stop() {
        queue.async { self.stopOnQueue() }
    }

    /// Await the actual stop before presenting another camera controller.
    func pause() async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.stopOnQueue()
                continuation.resume()
            }
        }
    }

    private func stopOnQueue() {
        coordinator.release(self)
        sessionRecovery.reset()
        stopMonitoringOnQueue()
        // Ein neu gestarteter Feed soll auch denselben Code wieder erkennen.
        if qrCodeScanner != nil { qrCodeScanner = FeedBoxQRCodeScanner() }
        publishQRCodeEvent(nil)
        cancelPendingCaptureOnQueue()
        guard wantsRunning else { return }
        wantsRunning = false
        if session.isRunning { session.stopRunning() }
        DispatchQueue.main.async {
            if self.isReady { self.isReady = false }
        }
    }

    @MainActor
    func attachPreview(_ preview: EmbeddedCameraPreviewConnection) {
        // Das Anhängen kann den Session-Graphen umbauen und darf keinen Tap blockieren.
        queue.async {
            if let previous = self.previewConnection, previous !== preview { previous.detach() }
            self.previewConnection = preview
            preview.attach(to: self.session)
            self.updatePreviewRotation()
        }
    }

    @MainActor
    func detachPreview(_ preview: EmbeddedCameraPreviewConnection) {
        // Der Layer bleibt bis zum tatsächlichen Abhängen erhalten. Ein schneller
        // Formularwechsel kann somit keine veraltete Verbindung auf Main abbauen.
        queue.async {
            if self.previewConnection === preview { self.previewConnection = nil }
            preview.detach()
        }
    }

    /// App-Drehungen sind absolut; die Korrektur der manuellen Drehtaste bleibt erhalten.
    func setPreviewOrientation(_ orientation: EmbeddedCameraRotation.Orientation) {
        // iOS-on-Mac besitzt keine drehbare iPad-Kamera; dort gilt weiterhin die manuelle Wahl.
        guard !usesVideoFrames else { return }
        queue.async {
            guard self.previewRotation.orientation != orientation else { return }
            self.previewRotation.orientation = orientation
            self.resetMonitoringAfterRotation()
            self.updatePreviewRotation()
        }
    }

    /// Rotate the live preview and future captures by one clockwise quarter turn.
    func rotatePreviewClockwise() {
        queue.async {
            self.previewRotation.rotateClockwise()
            self.resetMonitoringAfterRotation()
            self.updatePreviewRotation()
        }
    }

    /// Alte Objektpositionen und Countdown-Vergleiche gehören zur vorherigen Ausrichtung.
    private func resetMonitoringAfterRotation() {
        detector?.resetComparison()
        currentDetections = []
        publishSaliencyRegions([])
    }

    private func updatePreviewRotation() {
        dispatchPrecondition(condition: .onQueue(queue))
        let angle = previewRotationAngle
        // Verbindungen gemeinsam mit Start/Stop ändern, damit Rotation und
        // Vorschauwechsel nicht gleichzeitig denselben Session-Graphen sperren.
        applyPreviewRotation(angle)
        let output = usesVideoFrames ? frameOutput : photoOutput
        if let connection = output.connection(with: .video),
           connection.isVideoRotationAngleSupported(angle),
           connection.videoRotationAngle != angle {
            connection.videoRotationAngle = angle
        }
    }

    private func applyPreviewRotation(_ angle: CGFloat) {
        dispatchPrecondition(condition: .onQueue(queue))
        previewConnection?.updateRotation(angle)
    }

    /// Called only on the capture queue, including the permission-result callback.
    private func configureAndStart() {
        guard wantsRunning else { return }
        if needsSessionReconfiguration { rebuildSessionConfiguration() }
        if !configured {
            let device = usesVideoFrames ? AVCaptureDevice.default(for: .video)
                : AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            guard let device, let input = try? AVCaptureDeviceInput(device: device) else {
                setMessage("Keine Kamera verfügbar. Fotos können aus der Mediathek hinzugefügt werden.")
                return
            }
            session.beginConfiguration()
            // Mac camera streams may not support async still capture. Take a full video frame there.
            let preset: AVCaptureSession.Preset = usesVideoFrames ? .high : .photo
            if session.canSetSessionPreset(preset) { session.sessionPreset = preset }
            let output: AVCaptureOutput = usesVideoFrames ? frameOutput : photoOutput
            guard session.canAddInput(input), session.canAddOutput(output) else {
                session.commitConfiguration()
                setMessage("Die Kamera konnte nicht gestartet werden.")
                return
            }
            session.addInput(input)
            session.addOutput(output)
            if !usesVideoFrames, session.canAddOutput(frameOutput) { session.addOutput(frameOutput) }
            frameOutput.alwaysDiscardsLateVideoFrames = true
            frameOutput.setSampleBufferDelegate(self, queue: queue)
            if !usesVideoFrames {
                // Für den Vergleich genügen Preview-Puffer; volle Fotoauflösung bleibt der Fotoausgabe vorbehalten.
                frameOutput.automaticallyConfiguresOutputBufferDimensions = false
                frameOutput.deliversPreviewSizedOutputBuffers = true
            }
            // Native YUV-Helligkeit verwenden, ohne jeden Frame nach BGRA zu konvertieren (Apple TN3121).
            let formats = frameOutput.availableVideoPixelFormatTypes
            if let format = [kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                             kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                             kCVPixelFormatType_32BGRA].first(where: { formats.contains($0) }) {
                frameOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: format]
            }
            session.commitConfiguration()
            updateFrameAnalysisConnection()
            configured = true
        }
        // A preview attached before inputs exist receives its connection only after configuration.
        updatePreviewRotation()
        if !session.isRunning { session.startRunning() }
        let running = session.isRunning
        if running {
            sessionRecovery.reset()
        } else {
            publishSessionState(running: false)
            // Eine Systemunterbrechung endet per Notification. Außerhalb davon
            // kurz auf freie Kameraressourcen warten, bevor ein Fehler sichtbar wird.
            if !session.isInterrupted { recoverSessionOnQueue() }
            return
        }
        publishSessionState(running: true)
    }

    private func publishSessionState(running: Bool, error: String? = nil) {
        DispatchQueue.main.async {
            if self.isReady != running { self.isReady = running }
            if self.message != error { self.message = error }
        }
    }

    /// Auch zurückgesetzte Mediendienste im Hintergrund merken; gestartet wird
    /// erst wieder, wenn das aktive Formular tatsächlich einen Feed benötigt.
    private func handleSessionEvent(_ event: EmbeddedCameraSessionRecovery.Event) {
        switch event {
        case .interrupted:
            stopMonitoringOnQueue()
            cancelPendingCaptureOnQueue()
            publishSessionState(running: false)
        case .interruptionEnded:
            if wantsRunning { configureAndStart() }
        case .runtimeError(let mediaServicesReset):
            needsSessionReconfiguration = needsSessionReconfiguration || mediaServicesReset
            stopMonitoringOnQueue()
            cancelPendingCaptureOnQueue()
            publishSessionState(running: false)
            if wantsRunning, !session.isInterrupted { recoverSessionOnQueue() }
        }
    }

    private func recoverSessionOnQueue() {
        guard wantsRunning else { return }
        let scheduled = sessionRecovery.scheduleRetry { [weak self] attempt in
            guard let self, self.wantsRunning else { return }
            // Falls ein normaler Neustart scheitert, veraltete Inputs und Outputs
            // vollständig ersetzen. Das Session-Objekt der Vorschau bleibt erhalten.
            if attempt == 2 { self.needsSessionReconfiguration = true }
            self.configureAndStart()
        }
        if !scheduled {
            publishSessionState(running: false, error: "Die Kamera konnte nicht gestartet werden.")
        }
    }

    private func rebuildSessionConfiguration() {
        cancelPendingCaptureOnQueue()
        if session.isRunning { session.stopRunning() }
        session.beginConfiguration()
        for input in session.inputs { session.removeInput(input) }
        for output in session.outputs { session.removeOutput(output) }
        session.commitConfiguration()
        frameOutput.setSampleBufferDelegate(nil, queue: nil)
        photoOutput = AVCapturePhotoOutput()
        frameOutput = AVCaptureVideoDataOutput()
        configured = false
        needsSessionReconfiguration = false
    }

    func capture(completion: @escaping (UIImage) -> Void) {
        guard isReady, !isCapturing else { return }
        self.completion = completion
        isCapturing = true
        queue.async {
            guard self.wantsRunning, self.session.isRunning else {
                self.finishCapture(image: nil)
                return
            }
            if self.usesVideoFrames {
                let requestID = UUID()
                self.pendingFrameID = requestID
                // A disconnected camera must not leave the shutter disabled indefinitely.
                self.queue.asyncAfter(deadline: .now() + 3) {
                    guard self.pendingFrameID == requestID else { return }
                    self.pendingFrameID = nil
                    self.finishCapture(image: nil)
                }
            } else {
                let settings = AVCapturePhotoSettings()
                self.pendingPhotoID = settings.uniqueID
                if self.photoOutput.supportedFlashModes.contains(.auto) { settings.flashMode = .auto }
                self.updatePreviewRotation()
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // Bereits eingereihte Frames des verlassenen Formulars oder eines
        // ersetzten Outputs dürfen nach der Hardware-Übergabe keine Analyse starten.
        guard wantsRunning, output === frameOutput else { return }
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if let scanner = qrCodeScanner {
            if let event = scanner.scan(buffer, orientation: analysisOrientation, at: now) {
                publishQRCodeEvent(event)
            } else if scanner.visibleCode == nil {
                publishQRCodeEvent(nil)
            }
            // Ignorierte Etiketten dürfen den Countdown nicht dauerhaft pausieren.
            // Eine akzeptierte Zuordnung pausiert das Formular gezielt selbst.
        }
        if detector?.needsSample(at: now) == true, let values = monitoringSample(from: buffer) {
            processMonitoringSample(values, at: now)
        }
        guard pendingFrameID != nil else { return }
        pendingFrameID = nil
        let image = CIImage(cvPixelBuffer: buffer)
        let photo = imageContext.createCGImage(image, from: image.extent).map { UIImage(cgImage: $0) }
        finishCapture(image: photo)
    }

    /// Beide Quellen benutzen dieselben Sicherheitsprüfungen.
    private func processMonitoringSample(_ values: [UInt8], at now: Double) {
        let adjustmentRevision = detector?.automaticAdjustmentRevision
        let abortRevision = detector?.repeatedAbortRevision
        var noticeInterruptsUpdate = false
        let update = detector?.compare(values, at: now, canCapture: !monitoringBusy,
                                      includeDiagnostics: true, regions: currentDetections)
        // Diagnosewerte bleiben flüchtig und verändern keine Auslöseentscheidung.
        if let detector {

            if detector.automaticAdjustmentRevision != adjustmentRevision, let sessionID = monitoringSessionID {

                let event = FeedMonitoringEvent(sessionID: sessionID)
                DispatchQueue.main.async { self.thresholdAdjustmentEvent = event }
            }
            if detector.repeatedAbortRevision != abortRevision, let sessionID = monitoringSessionID {

                let event = FeedMonitoringEvent(sessionID: sessionID)
                DispatchQueue.main.async { self.repeatedAbortEvent = event }
                noticeInterruptsUpdate = UserDefaults.standard.object(forKey: FeedSensitivityLevel.hintsKey) as? Bool ?? true
            }
        }
        if noticeInterruptsUpdate {
            // Bereits vor dem Main-Queue-Hinweis sperren: kein neuer Countdown im selben Frame.
            detector?.pauseForFeedback(at: now, duration: 3)
        }
        if let update, !noticeInterruptsUpdate,
           let sessionID = monitoringSessionID {
            if update == .capture {
                monitoringBusy = true
                diagnosticPhotoWasCaptured = false
            }
            let event = FeedMonitoringStatusEvent(sessionID: sessionID, update: update)
            DispatchQueue.main.async { self.monitoringEvent = event }
        }
        publishSaliencyRegions(detector?.objectRegions ?? [])
        publishDiagnostics()
    }

    private var analysisOrientation: CGImagePropertyOrientation {
        // Auf dem Mac ist die Videoausgabe bereits rotiert.
        if usesVideoFrames { return .up }
        switch Int(previewRotationAngle.rounded()) % 360 {
        case 90: return .right
        case 180: return .down
        case 270: return .left
        default: return .up
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = error == nil ? photo.fileDataRepresentation().flatMap { UIImage(data: $0) } : nil
        let photoID = photo.resolvedSettings.uniqueID
        queue.async {
            // Ein verspätetes Foto einer abgebrochenen Session darf weder den
            // neuen Entwurf ergänzen noch dessen Auslöser oder Callback verändern.
            guard self.pendingPhotoID == photoID else { return }
            self.pendingPhotoID = nil
            self.finishCapture(image: image)
        }
    }

    private func cancelPendingCaptureOnQueue() {
        pendingFrameID = nil
        pendingPhotoID = nil
        DispatchQueue.main.async {
            self.isCapturing = false
            self.completion = nil
        }
    }

    /// Die gewählte Quelle ist exklusiv. Bei Vision-Fehlern abbrechen statt
    /// unbemerkt Helligkeitsbilder mit Saliency-Referenzen zu vergleichen.
    private func monitoringSample(from buffer: CVPixelBuffer) -> [UInt8]? {
        guard let configuration = detector?.configuration else { return nil }
        currentDetections = []
        do {
            if configuration.usesObjectness {
                let finder = objectFinder ?? FeedObjectFinder()
                objectFinder = finder
                currentDetections = try finder.regions(in: buffer, orientation: analysisOrientation)
            }
            // Beide Quellen werden im Detektor getrennt ausgewertet, nicht zu
            // einem künstlichen Bild vermischt. Objektsuche liefert nur Rechtecke.
            return configuration.usesImageReference ? FeedLuminanceSampler.sample(buffer) : [UInt8](repeating: 0, count: 4096)
        } catch {

            stopMonitoringOnQueue()
            setMessage(String(localized: "FeedObjectness.Unavailable"))
            return nil
        }
    }

    /// FIFO-Zustellung auf Main verhindert alte Rahmen nach Stoppen oder Quellenwechsel.
    private func publishSaliencyRegions(_ regions: [CGRect]) {
        DispatchQueue.main.async {
            if self.saliencyRegions != regions { self.saliencyRegions = regions }
        }
    }

    private func finishCapture(image: UIImage?) {
        // Nur tatsächlich gelieferte Fotos zählen, nicht Countdown-Versuche oder Fehler.
        let captured = image != nil
        queue.async {
            if captured {
                self.capturedPhotoCount += 1
                self.diagnosticPhotoWasCaptured = true
                self.publishDiagnostics()
            }
        }
        DispatchQueue.main.async {
            self.isCapturing = false
            let callback = self.completion
            self.completion = nil
            if let image { callback?(image) }
            else { self.message = "Das Foto konnte nicht aufgenommen werden. Bitte erneut versuchen." }
        }
    }

    private func setMessage(_ value: String) {
        DispatchQueue.main.async {
            if self.message != value { self.message = value }
            if self.isReady { self.isReady = false }
        }
    }
}

import AVFoundation

/// Beobachtung und begrenzte Wiederholungen laufen ausschließlich auf der Capture-Queue.
/// Ein Stop oder erfolgreicher Start entwertet auch bereits geplante Wiederholungen.
final class EmbeddedCameraSessionRecovery: @unchecked Sendable {
    enum Event: Sendable {
        case interrupted
        case interruptionEnded
        case runtimeError(mediaServicesReset: Bool)
    }

    private let queue: DispatchQueue
    private let notifications: NotificationCenter
    private let onEvent: @Sendable (Event) -> Void
    private var observers: [NSObjectProtocol] = []
    private var generation = UUID()
    private var attempts = 0
    private var retryPending = false

    init(session: AVCaptureSession, queue: DispatchQueue,
         notifications: NotificationCenter = .default,
         onEvent: @escaping @Sendable (Event) -> Void) {
        self.queue = queue
        self.notifications = notifications
        self.onEvent = onEvent
        observe(AVCaptureSession.wasInterruptedNotification, session: session) { _ in .interrupted }
        observe(AVCaptureSession.interruptionEndedNotification, session: session) { _ in .interruptionEnded }
        observe(AVCaptureSession.runtimeErrorNotification, session: session) { notification in
            #if os(iOS) || os(tvOS) || os(visionOS)
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError
            return .runtimeError(mediaServicesReset: error?.code == AVError.Code.mediaServicesWereReset.rawValue)
            #else
            // Das native macOS-SDK besitzt diesen iOS-Fehlercode nicht.
            // BoxHelper auf Apple Silicon läuft dagegen als iOS-App und nutzt den oberen Zweig.
            return .runtimeError(mediaServicesReset: false)
            #endif
        }
    }

    deinit {
        for observer in observers { notifications.removeObserver(observer) }
    }

    private func observe(_ name: Notification.Name, session: AVCaptureSession,
                         event: @escaping @Sendable (Notification) -> Event) {
        observers.append(notifications.addObserver(forName: name, object: session, queue: nil) { [weak self] notification in
            // Notification selbst nicht zwischen Queues übertragen; nur den kopierten Fehlerzustand.
            let value = event(notification)
            self?.queue.async { [weak self] in self?.onEvent(value) }
        })
    }

    /// Nur von der Capture-Queue aufrufen. Gleichzeitige Fehlermeldungen teilen einen Versuch.
    @discardableResult
    func scheduleRetry(_ restart: @escaping @Sendable (Int) -> Void) -> Bool {
        if retryPending { return true }
        guard attempts < 2 else { return false }
        attempts += 1
        let attempt = attempts
        let request = generation
        retryPending = true
        queue.asyncAfter(deadline: .now() + .milliseconds(400 * attempt)) { [weak self] in
            guard let self, self.generation == request else { return }
            self.retryPending = false
            restart(attempt)
        }
        return true
    }

    func reset() {
        generation = UUID()
        attempts = 0
        retryPending = false
    }
}

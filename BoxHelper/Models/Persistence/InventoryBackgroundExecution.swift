import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Verhindert neue Wartungszugriffe kurz vor der Suspension. Laufende Arbeit
/// erhält begrenzte Hintergrundzeit; Handoff darf diese direkt im Wake-Callback anfordern.
@MainActor
final class InventoryBackgroundExecution {
    typealias BeginTask = (String, @escaping @MainActor @Sendable () -> Void) -> Int?

    static let shared: InventoryBackgroundExecution = {
#if canImport(UIKit)
        InventoryBackgroundExecution(
            isInBackground: { UIApplication.shared.applicationState == .background },
            beginTask: { name, expiration in
                let identifier = UIApplication.shared.beginBackgroundTask(withName: name, expirationHandler: expiration)
                return identifier == .invalid ? nil : identifier.rawValue
            },
            endTask: { UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: $0)) },
            foregroundNotification: UIApplication.didBecomeActiveNotification)
#else
        // Native macOS-CLI-Prüfungen besitzen keine UIKit-Suspension.
        InventoryBackgroundExecution(isInBackground: { false }, beginTask: { _, _ in 0 }, endTask: { _ in })
#endif
    }()

    private let isInBackground: () -> Bool
    private let beginTask: BeginTask
    private let endTask: (Int) -> Void
    private let notifications: NotificationCenter
    private let foregroundNotification: Notification.Name
    private var activeLeases: Set<UUID> = []
    private var expiredInBackground = false
    private var waiters: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var foregroundObserver: NSObjectProtocol?

    init(isInBackground: @escaping () -> Bool, beginTask: @escaping BeginTask,
         endTask: @escaping (Int) -> Void, notifications: NotificationCenter = .default,
         foregroundNotification: Notification.Name = Notification.Name("inventoryDidBecomeActive")) {
        self.isInBackground = isInBackground
        self.beginTask = beginTask
        self.endTask = endTask
        self.notifications = notifications
        self.foregroundNotification = foregroundNotification
    }

    private var canStartMaintenance: Bool {
        if !isInBackground() {
            expiredInBackground = false
            return true
        }
        return !expiredInBackground && !activeLeases.isEmpty
    }

    /// Für Handoff vor dem ersten Task/Await aufrufen: Nach Verlassen des
    /// System-Callbacks könnte dessen eigene Wake-Assertion bereits beendet sein.
    func begin(name: String, isContinuation: Bool = false) -> InventoryBackgroundLease? {
        guard isContinuation || canStartMaintenance else { return nil }
        let token = UUID()
        let lease = InventoryBackgroundLease()
        guard let identifier = beginTask(name, { [weak self, weak lease] in
            if self?.isInBackground() == true { self?.expiredInBackground = true }
            lease?.expire()
        }) else { return nil }
        activeLeases.insert(token)
        let endTask = self.endTask
        lease.installEnd { [weak self] in
            self?.activeLeases.remove(token)
            endTask(identifier)
        }
        return lease
    }

    func perform<Value: Sendable>(
        name: String, operation: @escaping @MainActor @Sendable () async throws -> Value
    ) async throws -> Value {
        while !canStartMaintenance { try await waitForForeground() }
        try Task.checkCancellation()
        // Ohne gewährte Assertion wird kein Worker und damit kein DB-Zugriff gestartet.
        guard let lease = begin(name: name) else { throw CancellationError() }
        return try await lease.perform(operation)
    }

    private func waitForForeground() async throws {
        let token = UUID()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { continuation in
                waiters[token] = continuation
                if foregroundObserver == nil {
                    foregroundObserver = notifications.addObserver(forName: foregroundNotification, object: nil,
                                                                    queue: .main) { [weak self] _ in
                        // NotificationCenter liefert diesen Callback explizit auf der MainQueue.
                        MainActor.assumeIsolated { self?.resumeForegroundWaiters() }
                    }
                }
                if canStartMaintenance { resumeForegroundWaiters() }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancelWaiter(token) }
        }
    }

    private func resumeForegroundWaiters() {
        guard !isInBackground() else { return }
        expiredInBackground = false
        let pending = Array(waiters.values)
        waiters.removeAll()
        removeObserverIfIdle()
        pending.forEach { $0.resume() }
    }

    private func cancelWaiter(_ token: UUID) {
        waiters.removeValue(forKey: token)?.resume(throwing: CancellationError())
        removeObserverIfIdle()
    }

    private func removeObserverIfIdle() {
        guard waiters.isEmpty, let foregroundObserver else { return }
        notifications.removeObserver(foregroundObserver)
        self.foregroundObserver = nil
    }
}

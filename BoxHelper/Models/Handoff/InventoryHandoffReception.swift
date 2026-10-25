import Combine
import CoreSpotlight
import CryptoKit
import Foundation

/// SceneDelegate und SwiftUI können dieselbe Aktivität liefern. Ein gemeinsamer
/// Empfang verhindert doppelte Stream-Anfragen und behält Anfragen bis zum UI-Aufbau.
@MainActor
final class InventoryHandoffReception: ObservableObject {
    static let shared = InventoryHandoffReception()

    @Published private(set) var isReceiving = false
    @Published private(set) var hasAcceptedActivity = false
    @Published var errorMessage: String?
    @Published private(set) var spotlightActivity: NSUserActivity?
    @Published private(set) var spotlightRequestID: UUID?
    private var task: Task<Void, Never>?
    private var currentRequest: UUID?
    private var inFlightFingerprint: String?
    private var lastAccepted: (fingerprint: String, date: Date)?
    private let store: InventoryHandoffStore
    private let execution: InventoryBackgroundExecution

    init(store: InventoryHandoffStore = .shared, execution: InventoryBackgroundExecution = .shared) {
        self.store = store
        self.execution = execution
    }

    func consumeSpotlightRequest(_ id: UUID?) {
        guard id == spotlightRequestID else { return }
        spotlightActivity = nil
        spotlightRequestID = nil
    }

    @discardableResult
    func continueActivity(_ activity: NSUserActivity) -> Bool {
        guard [InventoryHandoffStore.formActivityType, InventoryHandoffStore.searchActivityType,
               CSSearchableItemActionType].contains(activity.activityType) else { return false }
        let fingerprint = fingerprint(of: activity)
        if inFlightFingerprint == fingerprint { return true }
        if let accepted = lastAccepted, accepted.fingerprint == fingerprint,
           Date().timeIntervalSince(accepted.date) < 2 { return true }
        if activity.activityType == CSSearchableItemActionType {
            task?.cancel()
            task = nil
            currentRequest = UUID()
            inFlightFingerprint = nil
            isReceiving = false
            spotlightActivity = activity
            spotlightRequestID = UUID()
            hasAcceptedActivity = true
            lastAccepted = (fingerprint, Date())
            return true
        }

        // Noch im Scene-/SwiftUI-Callback sichern, nicht erst im asynchronen Empfang.
        // Die Assertion bleibt bis nach Validierung, Foto-Commit und Rollback bestehen.
        guard let lease = execution.begin(name: "Inventory Handoff", isContinuation: true) else {
            errorMessage = "Die Übergabe konnte keine Hintergrundzeit erhalten. Bitte erneut öffnen."
            return true
        }
        task?.cancel()
        let request = UUID()
        currentRequest = request
        inFlightFingerprint = fingerprint
        isReceiving = true
        errorMessage = nil
        task = Task { @MainActor [weak self] in
            defer { lease.finish() }
            guard let self else { return }
            defer {
                if self.currentRequest == request {
                    self.isReceiving = false
                    self.inFlightFingerprint = nil
                    self.task = nil
                }
            }
            do {
                try Task.checkCancellation()
                try await lease.perform { try await self.store.receive(activity: activity) }
                guard self.currentRequest == request else { return }
                self.lastAccepted = (fingerprint, Date())
                self.hasAcceptedActivity = true
            } catch {
                guard self.currentRequest == request, !(error is CancellationError) else { return }
                self.errorMessage = error.localizedDescription
            }
        }
        return true
    }

    private func fingerprint(of activity: NSUserActivity) -> String {
        // Unsere versionierten Metadaten enthalten ausschließlich kleine JSON-Werte.
        // Sortierung macht die Identität unabhängig von der Dictionary-Reihenfolge.
        if let info = activity.userInfo as? [String: Any], JSONSerialization.isValidJSONObject(info),
           let data = try? JSONSerialization.data(withJSONObject: info, options: .sortedKeys) {
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            return activity.activityType + ":" + digest
        }
        return activity.activityType + ":" + String(describing: ObjectIdentifier(activity))
    }
}

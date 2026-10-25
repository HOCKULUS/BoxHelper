import AppIntents
import Combine
import Foundation

/// Wird in App und Erweiterung kompiliert. openAppWhenRun führt perform immer im
/// App-Prozess aus; der beobachtbare Auftrag überlebt dort auch den Launchscreen.
struct OpenRecentBoxIntent: AppIntent {
    static let title: LocalizedStringResource = "Open box"
    static let openAppWhenRun = true
    static let isDiscoverable = false

    @Parameter(title: "Box ID")
    var boxID: String

    init() {}

    init(boxID: UUID) {
        self.boxID = boxID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: boxID) else { throw NavigationError.invalidID }
        RecentBoxWidgetNavigation.shared.open(id)
        return .result()
    }

    private enum NavigationError: Error { case invalidID }
}

@MainActor
final class RecentBoxWidgetNavigation: ObservableObject {
    static let shared = RecentBoxWidgetNavigation()
    private(set) var boxID: UUID?
    @Published private(set) var requestID: UUID?

    func open(_ id: UUID) {
        boxID = id
        // Auch wiederholtes Antippen derselben Kiste erzeugt einen neuen Auftrag.
        requestID = UUID()
    }

    func consume() { boxID = nil }
}

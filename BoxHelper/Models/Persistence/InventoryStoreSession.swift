import Foundation
import SwiftData

/// Besitzt den einzigen dauerhaften Store-Bezug. Der Aufrufer beendet zuvor alle
/// Worker; hier erfolgen Freigabe, Öffnen und gegebenenfalls Rollback.
@MainActor
final class InventoryStoreSession {
    private(set) var store: InventoryStore?
    private(set) var cloudSyncEnabled = false
    private(set) var isReplacing = false
    private weak var retiringContainer: ModelContainer?
    private let makeStore: (Bool) throws -> InventoryStore
    private let recoverStore: (ModelContainer) throws -> InventoryStore

    init(makeStore: @escaping (Bool) throws -> InventoryStore = { enabled in
        try InventoryStore(container: InventoryStore.makeContainer(cloudSyncEnabled: enabled))
    }, recoverStore: @escaping (ModelContainer) throws -> InventoryStore = {
        try InventoryStore(container: $0)
    }) {
        self.makeStore = makeStore
        self.recoverStore = recoverStore
    }

    func open(cloudSyncEnabled: Bool) throws -> InventoryStore {
        if let store { return store }
        let opened = try autoreleasepool { try makeStore(cloudSyncEnabled) }
        store = opened
        self.cloudSyncEnabled = cloudSyncEnabled
        return opened
    }

    func replace(cloudSyncEnabled: Bool, validate: @MainActor () throws -> Void = {}) async throws {
        // Nur den Wertmodus prüfen: Ein optional gebundener alter Store könnte von
        // Swift bis zum Ende dieses Methodenaufrufs stark festgehalten werden.
        guard self.cloudSyncEnabled != cloudSyncEnabled else {
            _ = try open(cloudSyncEnabled: cloudSyncEnabled)
            return
        }
        try validate()
        let previousMode = self.cloudSyncEnabled
        isReplacing = true
        defer { isReplacing = false; retiringContainer = nil }
        retiringContainer = store?.container
        // Die alte CloudKit-Integration muss vor dem Öffnen derselben SQLite-Datei
        // freigegeben sein. Keine zweite aktive Konfiguration neben ihr behalten.
        autoreleasepool { store = nil }
        do {
            // SwiftData kann nach einem Save noch interne Nachbearbeitung besitzen.
            // Eine schwache Prüfung hält den alten Container dabei nicht selbst am Leben.
            let deadline = ContinuousClock.now + .seconds(5)
            while hasRetiringContainer {
                guard ContinuousClock.now < deadline else { throw StoreSwitchError.stillInUse }
                try await Task.sleep(for: .milliseconds(5))
            }
            try Task.checkCancellation()
            try validate()
            _ = try open(cloudSyncEnabled: cloudSyncEnabled)
        } catch {
            // Auch ein fehlgeschlagener Wechsel erhält den bisherigen lokalen Bestand.
            // Falls selbst das Wiederöffnen scheitert, kann prepare später erneut versuchen.
            do {
                if let container = retiringContainer {
                    // Bei Abbruch/Timeout denselben noch lebenden Container weiterverwenden,
                    // statt eine zweite CloudKit-Integration neben ihm anzulegen.
                    store = try recoverStore(container)
                    self.cloudSyncEnabled = previousMode
                } else { _ = try open(cloudSyncEnabled: previousMode) }
            }
            catch let recoveryError {
                throw NSError(domain: "BoxHelper.InventoryStoreSwitch", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Die Datenbank konnte nach der iCloud-Umstellung nicht geöffnet werden. Bitte versuche es erneut.",
                    NSMultipleUnderlyingErrorsKey: [error, recoveryError]
                ])
            }
            throw error
        }
    }

    private var hasRetiringContainer: Bool {
        // Die starke temporäre Kopie endet im Pool vor dem nächsten Await.
        autoreleasepool { retiringContainer != nil }
    }

    private enum StoreSwitchError: LocalizedError {
        case stillInUse
        var errorDescription: String? {
            "Die Datenbank wird noch verwendet. Die bisherige iCloud-Einstellung bleibt aktiv. Bitte versuche es erneut."
        }
    }
}

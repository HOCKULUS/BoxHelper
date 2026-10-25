import Foundation

/// Formularsync ist ein eigener gerätelokaler Opt-in. Die Entwürfe und Foto-Assets
/// liegen im bereits vorhandenen privaten SwiftData-Cloud-Store, niemals in Freigaben.
@MainActor
final class InventoryCloudFormSync: InventoryFormCloudPersistence {
    static let enabledKey = "syncFormsWithICloud"
    static let shared = InventoryCloudFormSync(drafts: .shared)

    private let drafts: InventoryFormDraftStore
    private let defaults: UserDefaults
    private let state: InventoryCloudSyncState
    private var importObserver: NSObjectProtocol?

    init(drafts: InventoryFormDraftStore, defaults: UserDefaults = .standard,
         state: InventoryCloudSyncState = .shared) {
        self.drafts = drafts
        self.defaults = defaults
        self.state = state
    }

    // Der Containerwechsel übernimmt vorhandene Entwürfe in derselben Datei.
    // Nach dem Ausschalten bleibt Handoff unabhängig im Speicher verfügbar.
    var isEnabled: Bool {
        defaults.bool(forKey: Self.enabledKey) && state.isActive
    }

    /// Nur der produktive Adapter hört auf bestätigte SwiftData-Importereignisse.
    func start() {
        guard importObserver == nil else { return }
        importObserver = NotificationCenter.default.addObserver(
            forName: .inventoryCloudFormImportCompleted, object: nil, queue: .main) { _ in
                Task { @MainActor in InventoryHandoffStore.shared.refreshCloudFormsIfUntouched() }
            }
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.enabledKey)
        if !enabled { state.clearFormsError() }
    }

    func load(kind: String) throws -> InventoryCloudFormSnapshot? {
        guard isEnabled else { return nil }
        return try perform {
            guard let latest = try drafts.loadLatest(kind: kind) else { return nil }
            return InventoryCloudFormSnapshot(id: latest.id, data: latest.form, updatedAt: latest.updatedAt)
        }
    }

    func save(form: Data, kind: String, id: UUID) throws -> InventoryCloudFormSnapshot? {
        guard isEnabled else { return nil }
        return try perform {
            let saved = try drafts.save(form: form, kind: kind, preferredID: id)
            return InventoryCloudFormSnapshot(id: saved.id, data: form, updatedAt: saved.updatedAt)
        }
    }

    func clear(kind: String, id: UUID) throws {
        guard isEnabled else { return }
        try perform { try drafts.delete(id: id) }
    }

    private func perform<Value>(_ operation: () throws -> Value) throws -> Value {
        do {
            let value = try operation()
            state.clearFormsError()
            return value
        } catch {
            state.recordFormsError(error)
            throw error
        }
    }
}

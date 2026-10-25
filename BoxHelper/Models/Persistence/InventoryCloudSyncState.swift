import CloudKit
import Combine
import Foundation

extension Notification.Name {
    static let inventoryCloudFormImportCompleted = Notification.Name("inventoryCloudFormImportCompleted")
}

/// Speichert die Wahl erst nach einem erfolgreichen Wechsel des laufenden Stores.
/// Kontoabfrage und Worker-Abbau sperren weitere Änderungen am Schalter.
@MainActor
final class InventoryCloudSyncState: ObservableObject {
    static let shared = InventoryCloudSyncState()

    @Published private(set) var isEnabled: Bool
    @Published private(set) var isActive = false
    @Published private(set) var isChanging = false
    @Published private(set) var isChangingConfiguration = false
    @Published private(set) var accountStatusDescription = "Noch nicht geprüft"
    @Published private(set) var errorMessage: String?
    @Published private var activityDescription = "Warte auf iCloud"
    @Published private(set) var isSynchronizing = false
    @Published private(set) var lastSuccessfulSync: Date?
    @Published private(set) var hasPendingChanges = false
    @Published private(set) var hasCompletedInitialImport = false

    private let defaults: UserDefaults
    private let supportsCloudKit: Bool
    private let accountStatus: @Sendable () async throws -> CKAccountStatus
    typealias ConfigurationChange = @MainActor (Bool, @escaping @MainActor () throws -> Void) async throws -> Void
    private var changeConfiguration: ConfigurationChange
    private var changeWaiters: [CheckedContinuation<Void, Never>] = []
    private var preferenceRevision = 0
    private var accountError: String?
    private var syncError: String?
    private var mediaError: String?
    private var preferencesError: String?
    private var formsError: String?
    private var collaborationError: String?
    private var activeChannels: Set<String> = []
    private var pendingChannels: Set<String> = []

    /// Farben werden durch echte Ereignisse bestimmt, nicht durch eine erfolgreiche Kontoabfrage.
    var indicator: Indicator {
        if isChangingConfiguration { return .changing }
        if errorMessage != nil && (isEnabled || isActive) { return .failed }
        if isEnabled != isActive { return .waiting }
        if !isActive { return .disabled }
        if isSynchronizing { return .syncing }
        if hasPendingChanges { return .waiting }
        return lastSuccessfulSync == nil ? .waiting : .synced
    }
    enum Indicator { case disabled, changing, waiting, syncing, synced, failed }

    func setSynchronizing(_ value: Bool, channel: String = "inventory") {
        if value { activeChannels.insert(channel) } else { activeChannels.remove(channel) }
        let synchronizing = !activeChannels.isEmpty
        if isSynchronizing != synchronizing { isSynchronizing = synchronizing }
    }
    func markSuccessfulSync(at date: Date, uploadedLocalChanges: Bool = true) {
        if lastSuccessfulSync != date { lastSuccessfulSync = date }
        if uploadedLocalChanges { clearPendingChanges(channel: "inventory") }
    }
    func markPendingChanges(channel: String = "inventory") {
        guard isActive else { return }
        pendingChannels.insert(channel)
        if !hasPendingChanges { hasPendingChanges = true }
    }
    func clearPendingChanges(channel: String) {
        pendingChannels.remove(channel)
        let pending = !pendingChannels.isEmpty
        if hasPendingChanges != pending { hasPendingChanges = pending }
    }
    func markInitialImportCompleted() {
        if !hasCompletedInitialImport { hasCompletedInitialImport = true }
    }
    func recordPreferencesError(_ error: Error) { preferencesError = InventoryCloudErrorMessage.describe(error); publishError() }
    func clearPreferencesError() { preferencesError = nil; publishError() }
    func recordFormsError(_ error: Error) { formsError = InventoryCloudErrorMessage.describe(error); publishError() }
    func clearFormsError() { formsError = nil; publishError() }
    func recordCollaborationError(_ error: Error) { collaborationError = InventoryCloudErrorMessage.describe(error); publishError() }
    func clearCollaborationError() { collaborationError = nil; publishError() }

    init(defaults: UserDefaults = .standard,
         supportsCloudKit: Bool = CloudSyncPreferences.supportsCloudKit,
         accountStatus: @escaping @Sendable () async throws -> CKAccountStatus = systemAccountStatus,
         changeConfiguration: @escaping ConfigurationChange = { _, validate in try validate() }) {
        self.defaults = defaults
        self.supportsCloudKit = supportsCloudKit
        self.accountStatus = accountStatus
        self.changeConfiguration = changeConfiguration
        isEnabled = defaults.bool(forKey: CloudSyncPreferences.enabledKey)
    }

    var syncStatusDescription: String {
        if isChangingConfiguration { return "iCloud-Einstellung wird übernommen …" }
        if isActive && hasPendingChanges && !isSynchronizing { return "Lokale Änderungen warten auf iCloud" }
        return isActive ? activityDescription : "Ausgeschaltet"
    }

    func setEnabled(_ enabled: Bool) async throws {
        try await applyPreference(enabled, persist: true)
    }

    /// Die Speicherfassade registriert den Laufzeitwechsel bereits beim ersten Öffnen,
    /// auch wenn ein AppIntent vor der sichtbaren App auf das Inventar zugreift.
    func configureRuntimeChange(_ change: @escaping ConfigurationChange) {
        changeConfiguration = change
    }

    private func applyPreference(_ enabled: Bool, persist: Bool) async throws {
        guard !isChanging else { throw InventoryCloudSyncError.changing }
        guard enabled != isEnabled || enabled != isActive else { return }
        isChanging = true
        isChangingConfiguration = true
        defer { finishChange() }
        let revision = preferenceRevision
        if enabled {
            do {
                guard supportsCloudKit else { throw InventoryCloudSyncError.unsupportedBuild }
                let status = try await accountStatus()
                applyAccountStatus(status)
                try requireAvailableAccount(status)
            } catch {
                accountError = InventoryCloudErrorMessage.describe(error)
                publishError()
                throw error
            }
        }
        // Ein paralleler Einstellungsreset darf nicht von einer verspäteten Antwort
        // überschrieben werden. Ausschalten benötigt dagegen keine Netzwerkabfrage.
        let validate: @MainActor () throws -> Void = {
            try Task.checkCancellation()
            guard revision == self.preferenceRevision else { throw InventoryCloudSyncError.settingsChanged }
        }
        try validate()
        do {
            // Der Handler prüft die Revision nochmals direkt vor dem atomaren Öffnen.
            try await changeConfiguration(enabled, validate)
        } catch {
            syncError = InventoryCloudErrorMessage.describe(error)
            publishError()
            throw error
        }
        // Ein Reset kann auch unmittelbar bei der Rückkehr des Handlers eintreffen.
        // Dann bleibt dessen Wahl maßgeblich und übernimmt danach den neuen Ist-Modus.
        guard revision == preferenceRevision else {
            markActive(enabled)
            throw InventoryCloudSyncError.settingsChanged
        }
        if persist { defaults.set(enabled, forKey: CloudSyncPreferences.enabledKey) }
        isEnabled = enabled
        preferenceRevision += 1
        markActive(enabled)
        accountError = nil
        publishError()
    }

    /// Verhindert doppelte Löschaufträge und Änderungen am Sync-Schalter währenddessen.
    /// Ein aktiver Cloud-Store darf lokale Daten nach der Löschung erneut hochladen.
    func deleteCloudData(using deletion: @MainActor () async throws -> Void) async throws {
        guard !isChanging else { throw InventoryCloudSyncError.changing }
        isChanging = true
        defer { finishChange() }
        try await deletion()
    }

    func refreshAccountStatus() async {
        guard supportsCloudKit else {
            accountStatusDescription = "In diesem Build nicht verfügbar"
            accountError = isEnabled ? InventoryCloudSyncError.unsupportedBuild.localizedDescription : nil
            publishError()
            return
        }
        do { applyAccountStatus(try await accountStatus()) }
        catch {
            accountStatusDescription = "Abfrage fehlgeschlagen"
            accountError = InventoryCloudErrorMessage.describe(error)
            publishError()
        }
    }

    func markActive(_ enabled: Bool) {
        if isActive != enabled {
            // Ein früherer Import bestätigt nicht den ersten Abgleich des neu geöffneten
            // Containers. Persönliche Einstellungen warten wieder auf dessen Import.
            activeChannels.removeAll()
            pendingChannels.removeAll()
            isSynchronizing = false
            hasPendingChanges = false
            hasCompletedInitialImport = false
            lastSuccessfulSync = nil
            syncError = nil
            mediaError = nil
            preferencesError = nil
            formsError = nil
            collaborationError = nil
        }
        isActive = enabled
        activityDescription = "Warte auf iCloud"
        if isEnabled && !supportsCloudKit {
            accountError = InventoryCloudSyncError.unsupportedBuild.localizedDescription
        }
        publishError()
    }

    func resetSettingsPreference() async throws {
        preferenceRevision += 1
        let revision = preferenceRevision
        isEnabled = defaults.bool(forKey: CloudSyncPreferences.enabledKey)
        // Ein verspäteter Login oder ein noch abgebauter Worker darf den Reset nicht
        // überholen. Der laufende Änderungsauftrag prüft dieselbe Revision.
        if isChanging { await withCheckedContinuation { changeWaiters.append($0) } }
        guard revision == preferenceRevision else { return }
        try await applyPreference(isEnabled, persist: false)
    }

    private func finishChange() {
        isChangingConfiguration = false
        isChanging = false
        let pending = changeWaiters
        changeWaiters.removeAll()
        pending.forEach { $0.resume() }
    }

    /// Nur tatsächliche CloudKit-Ereignisse melden einen abgeschlossenen Abgleich.
    func recordSyncStatus(_ description: String) {
        if activityDescription != description { activityDescription = description }
        syncError = nil
        publishError()
    }

    func recordSyncError(_ error: Error) {
        if activityDescription != "Synchronisierung unterbrochen" {
            activityDescription = "Synchronisierung unterbrochen"
        }
        syncError = InventoryCloudErrorMessage.describe(error)
        publishError()
    }

    func recordMediaError(_ error: Error) {
        mediaError = InventoryCloudErrorMessage.describe(error)
        publishError()
    }

    func clearMediaError() {
        guard mediaError != nil else { return }
        mediaError = nil
        publishError()
    }

    nonisolated static func systemAccountStatus() async throws -> CKAccountStatus {
        try await CKContainer(identifier: CloudSyncPreferences.containerIdentifier).accountStatus()
    }

    private func applyAccountStatus(_ status: CKAccountStatus) {
        switch status {
        case .available: accountStatusDescription = "Angemeldet"; accountError = nil
        case .noAccount: accountStatusDescription = "Nicht angemeldet"; accountError = InventoryCloudSyncError.noAccount.localizedDescription
        case .restricted: accountStatusDescription = "Eingeschränkt"; accountError = InventoryCloudSyncError.restricted.localizedDescription
        case .temporarilyUnavailable: accountStatusDescription = "Vorübergehend nicht verfügbar"; accountError = InventoryCloudSyncError.temporarilyUnavailable.localizedDescription
        case .couldNotDetermine: accountStatusDescription = "Unbekannt"; accountError = InventoryCloudSyncError.couldNotDetermine.localizedDescription
        @unknown default: accountStatusDescription = "Unbekannt"; accountError = InventoryCloudSyncError.couldNotDetermine.localizedDescription
        }
        publishError()
    }

    private func requireAvailableAccount(_ status: CKAccountStatus) throws {
        switch status {
        case .available: return
        case .noAccount: throw InventoryCloudSyncError.noAccount
        case .restricted: throw InventoryCloudSyncError.restricted
        case .temporarilyUnavailable: throw InventoryCloudSyncError.temporarilyUnavailable
        case .couldNotDetermine: throw InventoryCloudSyncError.couldNotDetermine
        @unknown default: throw InventoryCloudSyncError.couldNotDetermine
        }
    }

    private func publishError() {
        // Wiederholte identische CloudKit-Ereignisse brauchen keinen neuen Renderdurchlauf.
        let message = syncError ?? mediaError ?? preferencesError ?? formsError ?? collaborationError ?? accountError
        if errorMessage != message { errorMessage = message }
    }
}

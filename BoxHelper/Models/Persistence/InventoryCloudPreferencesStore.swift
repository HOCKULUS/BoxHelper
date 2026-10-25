import Foundation
import SwiftData

extension Notification.Name {
    static let cloudAppPreferencesDidChange = Notification.Name("cloudAppPreferencesDidChange")
}

/// Nur ausdrücklich aufgeführte Anpassungen verlassen das Gerät. Inventar, Entwürfe,
/// Freigaben, Berechtigungen, Laufzeitzustand und die Sync-Schalter sind ausgeschlossen.
@MainActor
final class InventoryCloudPreferencesStore {
    static let enabledKey = "syncAppPreferencesWithICloud"
    static let shared = InventoryCloudPreferencesStore(container: { try InventoryPersistence.prepare().container })
    static let keys: Set<String> = [
        "accentColor", "sliderValue", "sliderValue2", "sliderValue3", "sliderValue4",
        "showImages", "showTags", "hideTags", "blockedTags", "showDetails", "showDetailsLocation",
        "showDetailsItems", "showDetailsItemsCounter", "showDetailsTagCounter", "showDetailsImagesCounter",
        "showDetailsDate1", "showDetailsDate2", "showQRCodeLogo", "showQRCodeLocation", "showQRCodeLocationColor",
        "showQRCodeName", "BoxName", "boxNameScheme", "showBoxNameSheme", "useBoxUUIDasBoxName",
        "showBoxNumberSheme", "itemNameScheme", "showItemNameScheme", "showItemNumberScheme",
        "pressAndHold", "PageOnLauch", "dynamicQRCode", "createItemImageInputSource",
        "createNewItemInputAutofocusMode", "createLocationNameAutofocus", "useShortQRCodeURL", "qrCodeNumber", "qrCodeCopies",
        "defaultCreateForm", "fixedCreateForm", "alwaysShowNavBar", "navBarPosition",
        "enableFirstTabSwipeNavigation", "firstTabSwipeAnimationDuration", "firstTabSwipeAnimationStyle",
        "firstTabSwipeSensitivity", "rememberListSorting", "imagesTabThumbnailSize", "imageSortingOption",
        "itemVoiceNamingEnabled", "itemSmartCameraEnabled", "boxSmartCameraEnabled", "boxCameraAutomaticMode",
        "itemCameraQRCodeEnabled", "boxVoiceNamingEnabled", "boxLocationDictationEnabled",
        "boxCameraFeedEnabled", "itemCameraFeedEnabled", "itemAutomaticPhotoCount", "boxAutomaticPhotoCount",
        "feedMonitoringSensitivityLevel", "itemAutomaticModeSelected", "feedMonitoringFailureHints",
        "feedMonitoringInterval", "feedMonitoringThreshold", "feedMonitoringInactivity", "feedMonitoringCooldown",
        "feedMonitoringStabilityThreshold", "feedMonitoringStabilityInterval", "feedMonitoringImageReference",
        "feedMonitoringObjectness", "feedAdaptationSpeed", "firstTabCustomListLimit", "firstTabAlwaysLoadAll",
        "firstTabShowLoadAllButton",
        "firstTabOnLaunchMode", "firstTabOnLaunchSelection", "tinyQRCode", "horizontalQRCodeLayout",
        "smartZoom", "showLauchscreen5", "deepNavigation", "imageCropType", "loadLastSearch", "numberofsearchSuggestions",
        "searchSuggestions", "searchSuggestionsItems", "searchSuggestionsLocations", "showLocationImageBackground", "suggestions"
    ]

    private typealias Receipt = InventoryCloudPreferencesReconciliation.Receipt
    typealias BackgroundReconciliation = @Sendable (ModelContainer, InventoryCloudPreferencesReconciliation.Input)
        async throws -> InventoryCloudPreferencesReconciliation.Result
    private let container: () throws -> ModelContainer
    private let defaults: UserDefaults
    private let isReady: () -> Bool
    private let backgroundReconciliation: BackgroundReconciliation
    private var receipts: [String: Receipt] = [:]
    private var receiptData: Data?
    private var observer: NSObjectProtocol?
    private var task: Task<Void, Never>?
    private var applying = false
    private var revision: UInt = 0
    private var reconciliationRequested = false
    private var isPaused = false
    private let receiptKey = "privateCloudPreferenceReceiptsV1"

    init(container: @escaping () throws -> ModelContainer, defaults: UserDefaults = .standard,
         isReady: @escaping () -> Bool = {
             InventoryCloudSyncState.shared.isActive && InventoryCloudSyncState.shared.hasCompletedInitialImport
         }, backgroundReconciliation: @escaping BackgroundReconciliation = { container, input in
             try await InventoryCloudPreferencesWorker.reconcile(container: container, input: input)
         }) {
        self.container = container; self.defaults = defaults
        self.isReady = isReady
        self.backgroundReconciliation = backgroundReconciliation
        if let data = defaults.data(forKey: receiptKey) {
            receipts = (try? JSONDecoder().decode([String: Receipt].self, from: data)) ?? [:]
            receiptData = data
        }
    }

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                                          object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in self?.schedule() }
        }
        schedule()
    }

    func setEnabled(_ enabled: Bool) {
        cancelReconciliation()
        defaults.set(enabled, forKey: Self.enabledKey)
        if !enabled {
            receipts = [:]
            receiptData = nil
            defaults.removeObject(forKey: receiptKey)
        }
        schedule()
    }

    func reconcileIfEnabled() {
        schedule()
    }

    /// Ein Inventar-Commit wartet nicht auf das Scannen persönlicher Einstellungen.
    /// Der bestehende Debounce fasst Cloud- und UserDefaults-Ereignisse zusammen.
    func scheduleReconciliation() { schedule() }

    /// Synchrone Variante für isolierte Prüfungen. Produktionsereignisse gehen über
    /// scheduleReconciliation und führen sämtliche Datenbankarbeit außerhalb des UI aus.
    func reconcile() throws {
        guard defaults.bool(forKey: Self.enabledKey), !applying else { return }
        applying = true
        defer { applying = false }
        let input = try captureInput()
        let result = try InventoryCloudPreferencesReconciliation.reconcile(
            context: ModelContext(try container()), input: input)
        try apply(result, input: input)
    }

    /// Während SQLite und Cloud-Importe abgeglichen werden, bleibt der MainActor frei.
    /// Ein Reset oder eine neue lokale Eingabe darf verspätete Ergebnisse nicht anwenden.
    func reconcileInBackground() async {
        guard defaults.bool(forKey: Self.enabledKey), !applying, isReady() else { return }
        applying = true
        let startedRevision = revision
        let startedReceipts = defaults.data(forKey: receiptKey)
        defer {
            applying = false
            if revision != startedRevision, task == nil, reconciliationRequested {
                reconciliationRequested = false
                schedule()
            }
        }
        do {
            let input = try captureInput()
            let result = try await backgroundReconciliation(try container(), input)
            try Task.checkCancellation()
            guard startedRevision == revision, defaults.bool(forKey: Self.enabledKey), isReady() else { return }
            guard startedReceipts == defaults.data(forKey: receiptKey) else {
                reconciliationRequested = true
                return
            }
            try apply(result, input: input)
        } catch is CancellationError {
            // Ausschalten/Reset ist kein Synchronisationsfehler.
        } catch {
            guard startedRevision == revision, defaults.bool(forKey: Self.enabledKey), isReady() else { return }
            InventoryCloudSyncState.shared.recordPreferencesError(error)
        }
    }

    private func captureInput() throws -> InventoryCloudPreferencesReconciliation.Input {
        let savedReceipts = defaults.data(forKey: receiptKey)
        if savedReceipts != receiptData {
            receipts = savedReceipts.flatMap { try? JSONDecoder().decode([String: Receipt].self, from: $0) } ?? [:]
            receiptData = savedReceipts
        }
        var values: [String: InventoryCloudPreferencesReconciliation.Value] = [:]
        for key in Self.keys { values[key] = .init(data: try encodedPreference(key)) }
        return .init(values: values, receipts: receipts)
    }

    private func apply(_ result: InventoryCloudPreferencesReconciliation.Result,
                       input: InventoryCloudPreferencesReconciliation.Input) throws {
        var next = result.receipts
        var changes = result.apply
        var hasConcurrentEdits = false
        for (key, original) in input.values where try encodedPreference(key) != original.data {
            // Auch eine Rücknahme auf den vorherigen Wert gilt als neue Eingabe. Der
            // erfasste Wert bleibt deshalb die Vergleichsbasis des nächsten Uploads.
            next[key] = Receipt(local: original.data, remoteVersion: result.receipts[key]?.remoteVersion)
            changes.removeValue(forKey: key)
            hasConcurrentEdits = true
        }
        let encoded = hasConcurrentEdits
            ? try InventoryCloudPreferencesReconciliation.encodeReceipts(next) : result.encodedReceipts
        if result.hasChanges { InventoryCloudSyncState.shared.markPendingChanges() }
        receipts = next
        receiptData = encoded
        if defaults.data(forKey: receiptKey) != encoded { defaults.set(encoded, forKey: receiptKey) }
        for (key, value) in changes {
            let data = value.data
            if let data,
               let values = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
                defaults.set(values["value"], forKey: key)
            } else { defaults.removeObject(forKey: key) }
        }
        if hasConcurrentEdits { reconciliationRequested = true }
        InventoryCloudSyncState.shared.clearPreferencesError()
        if !changes.isEmpty { NotificationCenter.default.post(name: .cloudAppPreferencesDidChange, object: nil) }
    }

    private func encodedPreference(_ key: String) throws -> Data? {
        guard let value = defaults.object(forKey: key) else { return nil }
        return try PropertyListSerialization.data(fromPropertyList: ["value": value], format: .binary, options: 0)
    }

    private func schedule() {
        guard !isPaused else { return }
        guard defaults.bool(forKey: Self.enabledKey) else {
            cancelReconciliation()
            return
        }
        guard isReady() else { return }
        guard task == nil, !applying else {
            reconciliationRequested = true
            return
        }
        let scheduledRevision = revision
        task = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            guard let self, scheduledRevision == self.revision else { return }
            self.reconciliationRequested = false
            await self.reconcileInBackground()
            guard scheduledRevision == self.revision else { return }
            self.task = nil
            if self.reconciliationRequested {
                self.reconciliationRequested = false
                self.schedule()
            }
        }
    }

    private func cancelReconciliation() {
        revision &+= 1
        task?.cancel()
        task = nil
        reconciliationRequested = false
    }

    func pauseAndWait() async {
        isPaused = true
        let running = task
        cancelReconciliation()
        await running?.value
    }

    func resume() {
        isPaused = false
        schedule()
    }
}

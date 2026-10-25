import Combine
import Foundation

extension Notification.Name {
    static let inventoryHandoffWillResume = Notification.Name("inventoryHandoffWillResume")
    static let resumeInventoryHandoff = Notification.Name("resumeInventoryHandoff")
    static let inventoryCloudFormWillResume = Notification.Name("inventoryCloudFormWillResume")
    static let resumeInventoryCloudForm = Notification.Name("resumeInventoryCloudForm")
}

/// Der Handoff-Store kennt nur Wertkopien; die optionale Cloud-Anbindung bleibt austauschbar.
struct InventoryCloudFormSnapshot: Sendable {
    let id: UUID
    let data: Data
    let updatedAt: Date
}

@MainActor
protocol InventoryFormCloudPersistence: AnyObject {
    var isEnabled: Bool { get }
    func load(kind: String) throws -> InventoryCloudFormSnapshot?
    func save(form: Data, kind: String, id: UUID) throws -> InventoryCloudFormSnapshot?
    func clear(kind: String, id: UUID) throws
}

/// Handoff hält laufende Formulare im Speicher. Nur die ausdrücklich aktivierte
/// Cloud-Anbindung speichert sie zusätzlich dauerhaft im privaten iCloud-Store.
@MainActor
final class InventoryHandoffStore: ObservableObject {
    static let shared = InventoryHandoffStore()
    nonisolated static let formActivityType = "de.hockulus.boxhelper.form"
    nonisolated static let searchActivityType = "de.hockulus.boxhelper.search"

    struct IncomingSearch: Identifiable, Equatable, Sendable {
        let id: UUID
        let query: String
        let tab: String
    }

    @Published private(set) var incomingSearch: IncomingSearch?
    @Published private(set) var pendingFormKind: String?
    @Published private(set) var pendingFormRequestID: UUID?
    @Published private(set) var errorMessage: String?

    private struct Session {
        var id: UUID
        var form: InventoryHandoffPayload.NormalizedForm?
        var revision = UUID()
        var updatedAt = Date.distantPast
        var hasChanges = false
        var isCloudDraft = false
    }

    private struct Registration {
        let activity: NSUserActivity
        let delegate: InventoryHandoffActivityDelegate
        let id: UUID
    }

    private let documents: URL
    private let receiveData: @MainActor (NSUserActivity) async throws -> Data
    private var sessions: [String: Session] = [:]
    private var prepared: [String: InventoryHandoffPayload.Form] = [:]
    private var preparations: [String: Task<Void, Never>] = [:]
    private var registrations: [String: Registration] = [:]
    private var retired: [UUID: Registration] = [:]
    private var activeKind: String?
    private var searchActivity: NSUserActivity?
    private var unclaimedIncoming: Set<String> = []
    private var installingKind: String?
    private var receiveTask: Task<Void, Error>?
    private var receiveID: UUID?
    private var cloudDrafts: (any InventoryFormCloudPersistence)?

    init(documents: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
         receiveData: @escaping @MainActor (NSUserActivity) async throws -> Data = {
             try await InventoryHandoffStreamTransport.receive(activity: $0)
         }, cloudDrafts: (any InventoryFormCloudPersistence)? = nil) {
        self.documents = documents
        self.receiveData = receiveData
        self.cloudDrafts = cloudDrafts
    }

    func configureCloudDrafts(_ persistence: any InventoryFormCloudPersistence) {
        cloudDrafts = persistence
    }

    func save(form: Data, kind: String, isInitial: Bool = false) throws {
        // Eine noch montierte alte View darf den frisch empfangenen Zustand vor der
        // eigentlichen Navigation nicht überschreiben. load übernimmt diese Sitzung.
        guard installingKind != kind, !unclaimedIncoming.contains(kind) else { throw InventoryHandoffError.incomingPending }
        let normalized = try InventoryHandoffPayload.normalize(form, kind: kind, enforceLimits: false)
        var session = sessions[kind] ?? Session(id: UUID())
        if session.form?.data == normalized.data { return }
        if !isInitial, let saved = try cloudDrafts?.save(form: normalized.data, kind: kind, id: session.id) {
            session.id = saved.id
            session.updatedAt = saved.updatedAt
            session.isCloudDraft = true
        } else { session.updatedAt = Date() }
        session.hasChanges = !isInitial
        session.form = normalized
        session.revision = UUID()
        sessions[kind] = session
        preparations[kind]?.cancel()
        errorMessage = nil
        guard normalized.data.count <= InventoryHandoffPayload.maximumFormBytes, normalized.names.count <= InventoryHandoffPayload.maximumPhotoCount else {
            prepared.removeValue(forKey: kind)
            registrations[kind]?.activity.resignCurrent()
            errorMessage = InventoryHandoffError.tooLarge.localizedDescription
            return
        }

        // Formularfotodateien haben unveränderliche UUID-Namen. Textänderungen können
        // die bereits geprüften eigenen Bytes übernehmen und sofort angeboten werden.
        if let old = prepared[kind], old.id == session.id, Set(old.photos.map(\.name)) == normalized.names {
            let updated = InventoryHandoffPayload.Form(id: session.id, kind: kind, data: normalized.data, photos: old.photos)
            prepared[kind] = updated
            publish(updated, title: normalized.title)
            return
        }
        if activeKind == kind { registrations[kind]?.activity.resignCurrent() }
        let documents = self.documents
        let id = session.id
        let revision = session.revision
        preparations[kind] = Task { [weak self] in
            let work = Task.detached(priority: .utility) {
                try InventoryHandoffMedia.capture(normalized, id: id, kind: kind, documents: documents)
            }
            do {
                let packet = try await withTaskCancellationHandler {
                    try await work.value
                } onCancel: { work.cancel() }
                try Task.checkCancellation()
                guard let self, self.sessions[kind]?.revision == revision else { return }
                self.prepared[kind] = packet
                self.publish(packet, title: normalized.title)
                self.preparations[kind] = nil
            } catch is CancellationError {
                // Eine weitere Eingabe ersetzt nur die alte Vorbereitung.
            } catch {
                guard let self, self.sessions[kind]?.revision == revision else { return }
                self.prepared.removeValue(forKey: kind)
                self.registrations[kind]?.activity.resignCurrent()
                self.errorMessage = error.localizedDescription
                self.preparations[kind] = nil
            }
        }
    }

    func load(kind: String) throws -> Data? {
        guard InventoryHandoffPayload.kinds.contains(kind) else { throw InventoryHandoffError.invalidForm }
        // Ein ausdrücklich empfangener Handoff hat Vorrang vor automatischem Cloud-Laden.
        if unclaimedIncoming.remove(kind) != nil { return sessions[kind]?.form?.data }
        if cloudDrafts?.isEnabled == true, installingKind != kind {
            if let stored = try cloudDrafts?.load(kind: kind),
               sessions[kind]?.hasChanges != true || stored.updatedAt > (sessions[kind]?.updatedAt ?? .distantPast) {
                let normalized = try InventoryHandoffPayload.normalize(stored.data, kind: kind, enforceLimits: false)
                preparations.removeValue(forKey: kind)?.cancel()
                prepared.removeValue(forKey: kind)
                if let registration = registrations.removeValue(forKey: kind) { retire(registration) }
                sessions[kind] = Session(id: stored.id, form: normalized, updatedAt: stored.updatedAt, isCloudDraft: true)
            } else if sessions[kind]?.isCloudDraft == true, sessions[kind]?.hasChanges == false {
                // Ein auf einem anderen Gerät abgeschlossener Entwurf bleibt nicht im Formular hängen.
                clearLocalSession(kind: kind)
            }
        }
        return sessions[kind]?.form?.data
    }

    func currentForm(kind: String) -> Data? { sessions[kind]?.form?.data }

    /// Einschalten sichert vorhandene Eingaben, aber keine automatisch erzeugten Leerformulare.
    func saveCurrentFormsToCloud() throws {
        for kind in sessions.keys.sorted() {
            guard var session = sessions[kind], session.hasChanges, let form = session.form,
                  !unclaimedIncoming.contains(kind),
                  let saved = try cloudDrafts?.save(form: form.data, kind: kind, id: session.id) else { continue }
            let previousID = session.id
            session.id = saved.id; session.updatedAt = saved.updatedAt; session.isCloudDraft = true
            sessions[kind] = session
            if let packet = prepared[kind] {
                let updated = InventoryHandoffPayload.Form(id: saved.id, kind: kind, data: form.data, photos: packet.photos)
                prepared[kind] = updated
                publish(updated, title: form.title)
            }
            if previousID != saved.id {
                NotificationCenter.default.post(name: .inventoryCloudFormWillResume, object: kind)
                NotificationCenter.default.post(name: .resumeInventoryCloudForm, object: kind)
            }
        }
    }

    /// Später eintreffende Assets dürfen nur ein seit dem Öffnen unberührtes Formular ersetzen.
    func refreshCloudFormsIfUntouched() {
        guard cloudDrafts?.isEnabled == true else { return }
        for kind in sessions.keys.sorted() where kind == activeKind && sessions[kind]?.hasChanges == false && !unclaimedIncoming.contains(kind) {
            let previousID = sessions[kind]?.id
            let previousData = sessions[kind]?.form?.data
            do {
                _ = try load(kind: kind)
                if sessions[kind]?.form != nil,
                   sessions[kind]?.id != previousID || sessions[kind]?.form?.data != previousData {
                    NotificationCenter.default.post(name: .inventoryCloudFormWillResume, object: kind)
                    NotificationCenter.default.post(name: .resumeInventoryCloudForm, object: kind)
                }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func clear(kind: String) throws {
        guard InventoryHandoffPayload.kinds.contains(kind) else { throw InventoryHandoffError.invalidForm }
        guard installingKind != kind else { throw InventoryHandoffError.incomingPending }
        if let id = sessions[kind]?.id { try cloudDrafts?.clear(kind: kind, id: id) }
        clearLocalSession(kind: kind)
    }

    private func clearLocalSession(kind: String) {
        preparations.removeValue(forKey: kind)?.cancel()
        sessions.removeValue(forKey: kind)
        prepared.removeValue(forKey: kind)
        unclaimedIncoming.remove(kind)
        if let registration = registrations.removeValue(forKey: kind) { retire(registration) }
        if pendingFormKind == kind { consumeFormRequest() }
    }

    func activeFormID(kind: String) -> UUID? { sessions[kind]?.id }

    func activateForm(kind: String) {
        guard InventoryHandoffPayload.kinds.contains(kind) else { return }
        if sessions[kind] == nil { sessions[kind] = Session(id: UUID()) }
        if let previous = activeKind, previous != kind { registrations[previous]?.activity.resignCurrent() }
        deactivateSearch()
        activeKind = kind
        if let packet = prepared[kind], let form = sessions[kind]?.form { publish(packet, title: form.title) }
    }

    func deactivateForm(kind: String) {
        guard activeKind == kind else { return }
        registrations[kind]?.activity.resignCurrent()
        activeKind = nil
    }

    func updateSearch(query: String, tab: String) {
        guard InventoryHandoffPayload.tabs.contains(tab), !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              query.utf8.count <= InventoryHandoffPayload.maximumSearchBytes else { deactivateSearch(); return }
        if let activeKind { registrations[activeKind]?.activity.resignCurrent() }
        activeKind = nil
        let activity = searchActivity ?? NSUserActivity(activityType: Self.searchActivityType)
        activity.title = "Suche: " + String(query.prefix(100))
        activity.userInfo = ["version": InventoryHandoffPayload.version, "query": query, "tab": tab]
        configure(activity)
        activity.supportsContinuationStreams = false
        activity.requiredUserInfoKeys = ["version", "query", "tab"]
        searchActivity = activity
        activity.needsSave = true
        activity.becomeCurrent()
    }

    func deactivateSearch() { searchActivity?.resignCurrent() }

    func consumeFormRequest(_ id: UUID? = nil) {
        guard id == nil || id == pendingFormRequestID else { return }
        pendingFormKind = nil
        pendingFormRequestID = nil
    }

    func consumeSearchRequest(_ id: UUID? = nil) {
        guard id == nil || id == incomingSearch?.id else { return }
        incomingSearch = nil
    }

    func receive(activity: NSUserActivity) async throws {
        try Task.checkCancellation()
        receiveTask?.cancel()
        let token = UUID()
        receiveID = token
        let info = try descriptor(activity)
        if activity.activityType == Self.searchActivityType {
            guard let query = info["query"] as? String, let tab = info["tab"] as? String,
                  InventoryHandoffPayload.tabs.contains(tab), query.utf8.count <= InventoryHandoffPayload.maximumSearchBytes else {
                throw InventoryHandoffError.invalidForm
            }
            consumeFormRequest()
            incomingSearch = IncomingSearch(id: token, query: query, tab: tab)
            return
        }
        guard activity.activityType == Self.formActivityType, activity.supportsContinuationStreams,
              let kind = info["kind"] as? String, InventoryHandoffPayload.kinds.contains(kind),
              let rawID = info["formID"] as? String, let id = UUID(uuidString: rawID) else {
            throw InventoryHandoffError.unavailable
        }
        let read = self.receiveData
        let operation = Task { [weak self] in
            let data = try await read(activity)
            let validation = Task.detached(priority: .utility) {
                guard data.count <= InventoryHandoffPayload.maximumFrameBytes else { throw InventoryHandoffError.tooLarge }
                let packet = try JSONDecoder().decode(InventoryHandoffPayload.Form.self, from: data)
                guard packet.kind == kind, packet.id == id else { throw InventoryHandoffError.invalidForm }
                let normalized = try packet.validate()
                return (packet, normalized)
            }
            let (packet, normalized) = try await withTaskCancellationHandler {
                try await validation.value
            } onCancel: { validation.cancel() }
            try Task.checkCancellation()
            guard let self, self.receiveID == token else { throw CancellationError() }
            try await InventoryHandoffMedia.materialize(packet, documents: self.documents) {
                // Fotodateien und Sitzung werden bestätigt, solange das Rollback noch
                // bereitliegt. Danach darf ein neuer Empfang dieses Paar ablösen.
                try Task.checkCancellation()
                guard self.receiveID == token else { throw CancellationError() }
                self.install(packet, normalized: normalized, requestID: token)
            }
        }
        receiveTask = operation
        defer { if receiveID == token { receiveTask = nil } }
        try await withTaskCancellationHandler {
            try await operation.value
        } onCancel: { operation.cancel() }
    }

    private func install(_ packet: InventoryHandoffPayload.Form, normalized: InventoryHandoffPayload.NormalizedForm,
                         requestID: UUID) {
        installingKind = packet.kind
        defer { installingKind = nil }
        // Sämtliche Fotodateien wurden bestätigt, bevor Views einfrieren oder ihre
        // Feldwerte ersetzen. Ein fehlgeschlagener Stream verändert kein Formular.
        NotificationCenter.default.post(name: .inventoryHandoffWillResume, object: packet.kind)
        preparations.removeValue(forKey: packet.kind)?.cancel()
        if let registration = registrations.removeValue(forKey: packet.kind) { retire(registration) }
        sessions[packet.kind] = Session(id: packet.id, form: normalized)
        prepared[packet.kind] = packet
        unclaimedIncoming.insert(packet.kind)
        incomingSearch = nil
        pendingFormKind = packet.kind
        pendingFormRequestID = requestID
        errorMessage = nil
        NotificationCenter.default.post(name: .resumeInventoryHandoff, object: packet.kind)
    }

    private func publish(_ packet: InventoryHandoffPayload.Form, title: String) {
        let caption = "Formular: " + String(title.prefix(100))
        if let registration = registrations[packet.kind], registration.id == packet.id {
            registration.delegate.update(snapshot: packet, title: caption)
            registration.activity.title = caption
            registration.activity.userInfo = InventoryHandoffActivityDelegate.descriptor(id: packet.id, kind: packet.kind, revision: packet.revision)
            registration.activity.needsSave = true
            if activeKind == packet.kind { registration.activity.becomeCurrent() }
            return
        }
        if let old = registrations.removeValue(forKey: packet.kind) { retire(old) }
        let activity = NSUserActivity(activityType: Self.formActivityType)
        let delegate = InventoryHandoffActivityDelegate(snapshot: packet, title: caption) { [weak self] message in
            Task { @MainActor in self?.errorMessage = message }
        }
        activity.title = caption
        activity.userInfo = InventoryHandoffActivityDelegate.descriptor(id: packet.id, kind: packet.kind, revision: packet.revision)
        activity.delegate = delegate
        activity.supportsContinuationStreams = true
        activity.requiredUserInfoKeys = ["version", "formID", "kind", "revision"]
        configure(activity)
        registrations[packet.kind] = Registration(activity: activity, delegate: delegate, id: packet.id)
        if activeKind == packet.kind { activity.becomeCurrent() }
    }

    private func retire(_ registration: Registration) {
        registration.activity.resignCurrent()
        let token = UUID()
        retired[token] = registration
        // Ein gerade vom System angeforderter Delegate behält seine eigenen Bytes,
        // auch wenn das lokale Formular unmittelbar danach gespeichert/geleert wird.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(InventoryHandoffStreamTransport.timeout + 5))
            self?.retired.removeValue(forKey: token)
        }
    }

    private func configure(_ activity: NSUserActivity) {
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false
        activity.isEligibleForPublicIndexing = false
        #if os(iOS) || os(watchOS)
        activity.isEligibleForPrediction = false
        #endif
    }

    private func descriptor(_ activity: NSUserActivity) throws -> [AnyHashable: Any] {
        guard let info = activity.userInfo,
              let version = info["version"] as? Int, version == InventoryHandoffPayload.version else {
            throw InventoryHandoffError.unsupportedVersion
        }
        let size = try PropertyListSerialization.data(fromPropertyList: info, format: .binary, options: 0).count
        guard size < 3_072 else { throw InventoryHandoffError.tooLarge }
        return info
    }
}

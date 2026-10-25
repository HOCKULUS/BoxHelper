import Foundation
import Combine

/// Verbindet die Suchregeln mit einem zweiten Diktat. Manuelle Auswahl beendet
/// auch einen noch startenden oder bereits ausgefallenen Speech-Vorgang sofort.
/// Die bestätigte Karte bleibt vor der Rückgabe kurz mittig sichtbar.
@MainActor
final class AutomaticLocationDictation: ObservableObject {
    let speech = AutomaticItemDictation()
    @Published private(set) var isActive = false
    @Published private var hasFinishedSpeech = false
    @Published private(set) var choices: [LocationDictationChoice] = []
    @Published private(set) var preferredID: UUID?
    @Published private(set) var selectedChoice: LocationDictationSelection?
    @Published private(set) var newLocationColor = ""
    private let makeNewLocationColor: () -> String
    private var skipped = false
    private var operationID: UUID?
    private var selectionWait: Task<Void, Never>?
    private var subscription: AnyCancellable?

    init(makeNewLocationColor: @escaping () -> String) {
        self.makeNewLocationColor = makeNewLocationColor
        subscription = speech.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
    }

    /// Wie beim Namensdiktat erst nach dem Audio-Start zum Standort wechseln.
    /// Nach einem Ausfall bleiben die manuelle Auswahl und ihre Bestätigung sichtbar.
    var showsFeedback: Bool {
        isActive && (speech.isListening || hasFinishedSpeech || selectedChoice != nil)
    }

    var results: [LocationDictationChoice] {
        // Während der Bestätigung steht nur die gewählte Karte in der Mitte.
        if let selectedChoice {
            guard case .existing(let id) = selectedChoice else { return [] }
            return choices.filter { $0.id == id }
        }
        return LocationDictationMatcher.matches(choices, query: speech.transcript, preferredID: preferredID)
    }

    var highlightedID: UUID? {
        if case .existing(let id) = selectedChoice { return id }
        return LocationDictationMatcher.selectedID(in: choices, query: speech.transcript, preferredID: preferredID)
    }

    var newLocationName: String? {
        if let selectedChoice {
            guard case .new(let name) = selectedChoice else { return nil }
            return name
        }
        guard case .new(let name) = LocationDictationMatcher.resolve(query: speech.transcript, choices: choices) else {
            return nil
        }
        return name
    }

    /// Teiltreffer bleiben während des Diktats allein sichtbar. Erst nach dessen
    /// Abschluss oder ganz ohne Treffer ist der neue Standort eindeutig.
    var showsNewLocation: Bool {
        newLocationName != nil && (selectedChoice != nil || results.isEmpty)
    }

    /// Sobald die neue Karte den Namen zeigt, entfällt der doppelte Text darüber.
    var standaloneTranscript: String {
        showsNewLocation ? "" : speech.transcript
    }

    func transcribe(choices: [LocationDictationChoice], preferredID: UUID? = nil) async -> LocationDictationSelection? {
        let id = UUID()
        operationID = id
        self.choices = choices
        self.preferredID = preferredID
        selectedChoice = nil
        // Eine Farbe pro Runde: Weitere Wörter und die Bestätigung ändern sie nicht.
        newLocationColor = makeNewLocationColor()
        skipped = false
        speech.resetTranscript()
        hasFinishedSpeech = false
        isActive = true
        let initialWait = LocationDictationMatcher.silenceSeconds(for: "", choices: choices)
        let deadline = ContinuousClock.now.advanced(by: .seconds(initialWait))
        let spoken = await speech.transcribe(initialTimeout: initialWait) { text in
            LocationDictationMatcher.silenceSeconds(for: text, choices: choices)
        }
        guard operationID == id else { return nil }
        hasFinishedSpeech = true
        // Bei fehlender Spracherkennung bleibt die Liste für die vorgesehene Frist bedienbar.
        if spoken == nil, selectedChoice == nil, !skipped, ContinuousClock.now < deadline {
            let wait = Task {
                do { try await Task.sleep(until: deadline, clock: .continuous) }
                catch { return }
            }
            selectionWait = wait
            await wait.value
            selectionWait = nil
        }
        guard operationID == id else { return nil }
        let result = selectedChoice
            ?? (skipped ? nil : spoken.flatMap { LocationDictationMatcher.resolve(query: $0, choices: choices) })
        if let result {
            selectedChoice = result
            // Auch automatisch aufgelöste neue Namen zeigen zunächst ihre Standortkarte.
            // Der Abbruch bleibt während dieser kurzen Bestätigung bedienbar.
            let confirmation = Task {
                do { try await Task.sleep(for: .milliseconds(1500)) }
                catch { return }
            }
            selectionWait = confirmation
            await confirmation.value
            guard operationID == id else { return nil }
            selectionWait = nil
        }
        isActive = false
        operationID = nil
        return skipped ? nil : result
    }

    func choose(_ id: UUID) {
        guard isActive, selectedChoice == nil, choices.contains(where: { $0.id == id }) else { return }
        completeSelection(.existing(id))
    }

    /// Die Pluskarte bestätigt den bereits diktierten Namen, ohne einen leeren Standort zu speichern.
    func chooseNewLocation() {
        guard isActive, selectedChoice == nil, showsNewLocation, let name = newLocationName else { return }
        completeSelection(.new(name))
    }

    private func completeSelection(_ selection: LocationDictationSelection) {
        selectedChoice = selection
        speech.cancel()
        selectionWait?.cancel()
    }

    func skip() {
        guard isActive else { return }
        skipped = true
        speech.cancel()
        selectionWait?.cancel()
    }

    func cancel() {
        operationID = nil
        isActive = false
        hasFinishedSpeech = false
        speech.cancel()
        selectionWait?.cancel()
        selectionWait = nil
    }
}

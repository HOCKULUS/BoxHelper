import AVFoundation
import Combine
import Speech

/// Gemeinsame lokale Spracherkennung für Namen und die einstellbare Standort-Suche.
@MainActor
final class AutomaticItemDictation: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""
    @Published private(set) var audioLevel = 0.0

    private let audioInput = AutomaticDictationAudioInput()
    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?
    private var timeoutTask: Task<Void, Never>?
    private var settlingTask: Task<Void, Never>?
    private var continuation: CheckedContinuation<String?, Never>?
    private var activeID: UUID?
    private var silenceDelay: (String) -> Double = { _ in 2 }

    var hasAuthorization: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
            && AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    /// Vor dem Start der Automatik freigeben, ohne Mikrofon oder AudioEngine zu starten.
    /// Abbrechen verhindert auch hier eine zweite Abfrage oder verspätete Fortsetzung.
    func requestAuthorization() async -> Bool {
        guard activeID == nil else { return false }
        let operationID = UUID()
        activeID = operationID
        defer { if activeID == operationID { activeID = nil } }
        let speechAllowed = await requestSpeechAuthorization()
        guard activeID == operationID, !Task.isCancelled, speechAllowed else { return false }
        let microphoneAllowed = await requestMicrophoneAuthorization()
        return activeID == operationID && !Task.isCancelled && microphoneAllowed
    }

    func transcribe(initialTimeout: Double = 5,
                    silenceDelay: @escaping (String) -> Double = { _ in 2 }) async -> String? {
        // Während einer Aufnahme erscheinen keine nachträglichen Systemdialoge.
        guard activeID == nil, hasAuthorization else { return nil }
        self.silenceDelay = silenceDelay
        resetTranscript()
        let operationID = UUID()
        activeID = operationID
        let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            finish(id: operationID)
            return nil
        }
        self.recognizer = recognizer

        do {
            let request = AutomaticDictationRequest()
            try await audioInput.start(request: request, id: operationID) { [weak self] level in
                Task { @MainActor [weak self] in
                    guard let self, self.activeID == operationID, self.isListening else { return }
                    // Schneller Anstieg, weicher Abfall: Sprache reagiert direkt, Pausen flackern nicht.
                    let smoothing = level > self.audioLevel ? 0.65 : 0.22
                    self.audioLevel += (level - self.audioLevel) * smoothing
                }
            }
            guard activeID == operationID else {
                audioInput.stop(id: operationID)
                return nil
            }
            // Erst nach erfolgreichem Hardware-Start erscheinen Mikrofon und Ton.
            // Die fünf Sekunden beginnen ebenfalls erst bei aufnahmebereiter Session.
            isListening = true
            audioInput.announceStart(id: operationID)

            return await withCheckedContinuation { continuation in
                self.continuation = continuation
                // Speech darf den Callback außerhalb des Main Actors ausführen.
                // Nur kopierten Text an die UI übergeben; SDK-Objekte bleiben hier.
                task = recognizer.recognitionTask(with: request.value) { @Sendable [weak self] result, error in
                    guard let result else {
                        if error != nil {
                            Task { @MainActor [weak self] in
                                guard let self, self.activeID == operationID else { return }
                                // Bereits angezeigte Suchtreffer behalten ihre Auswahlfrist,
                                // auch wenn Speech nach dem letzten Ergebnis abschließt.
                                if self.settlingTask == nil { self.finish(id: operationID) }
                            }
                        }
                        return
                    }
                    let recognizedText = result.bestTranscription.formattedString
                    Task { @MainActor [weak self] in
                        guard let self, self.activeID == operationID else { return }
                        self.transcript = recognizedText
                        if !recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            self.scheduleSilenceFinish(id: operationID)
                        }
                    }
                }
                // Namen warten fünf Sekunden auf erste Worte; die Standort-Suche wählt ihre eigene Frist.
                timeoutTask = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(initialTimeout)) }
                    catch { return }
                    guard let self, self.activeID == operationID else { return }
                    if self.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.finish(id: operationID)
                    }
                }
            }
        } catch {
            finish(id: operationID)
            return nil
        }
    }

    func cancel() {
        finish(id: activeID, cancelled: true)
    }

    /// Die nächste Standortsuche beginnt ohne Text aus der vorherigen Runde,
    /// auch wenn keine Speech-Freigabe vorliegt oder der Audio-Start fehlschlägt.
    func resetTranscript() {
        guard activeID == nil else { return }
        transcript = ""
        audioLevel = 0
    }

    /// Setzt den wartenden Speichervorgang sofort fort. Bereits erkannter Text bleibt nutzbar,
    /// ohne Text verwendet der Aufrufer wie bisher den automatisch erzeugten Namen.
    func skip() {
        guard isListening else { return }
        finish(id: activeID, cancelled: true)
    }

    private func scheduleSilenceFinish(id: UUID) {
        settlingTask?.cancel()
        let delay = silenceDelay(transcript)
        settlingTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) }
            catch { return }
            self?.finish(id: id)
        }
    }

    private func finish(id: UUID?, cancelled: Bool = false) {
        if let id, activeID != id { return }
        timeoutTask?.cancel()
        settlingTask?.cancel()
        timeoutTask = nil
        settlingTask = nil
        let result = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if let id {
            // Stoppen und Abschlusston laufen geordnet auf derselben Audio-Queue.
            // Ein bewusster Abbruch des Modus erzeugt keinen nachträglichen Ton.
            let outcome: AutomaticDictationSounds.Outcome? = cancelled ? nil : (result.isEmpty ? .noSpeech : .completed)
            audioInput.stop(id: id, outcome: outcome)
        }
        task?.cancel()
        task = nil
        activeID = nil
        silenceDelay = { _ in 2 }
        isListening = false
        audioLevel = 0
        continuation?.resume(returning: result.isEmpty ? nil : result)
        continuation = nil
    }

    private func requestSpeechAuthorization() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                // Ohne @Sendable erbt der Callback den MainActor dieser Klasse.
                // iOS antwortet auf einer beliebigen Queue: Swift 6 würde dann
                // bereits beim Callback-Eintritt mit einer Actor-Prüfung abbrechen.
                SFSpeechRecognizer.requestAuthorization { @Sendable status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        default: return false
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { @Sendable granted in
                    continuation.resume(returning: granted)
                }
            }
        default: return false
        }
    }
}

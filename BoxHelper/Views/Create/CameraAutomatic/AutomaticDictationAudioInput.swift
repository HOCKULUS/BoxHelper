import AVFoundation
import Speech

/// Speech erwartet Puffer aus dem Audio-Callback, annotiert seinen Request aber
/// noch nicht als Sendable. Nach der Initialisierung ändern wir keine Optionen;
/// append/endAudio laufen über den Audioeingang, die Erkennung nutzt denselben Request.
struct AutomaticDictationRequest: @unchecked Sendable {
    let value: SFSpeechAudioBufferRecognitionRequest

    init() {
        value = SFSpeechAudioBufferRecognitionRequest()
        value.shouldReportPartialResults = true
        value.requiresOnDeviceRecognition = true
    }
}

/// AudioEngine und Session bleiben auf derselben Queue wie die Signaltöne.
/// Alle veränderlichen Felder sind queuegebunden; die UI erhält nur das asynchrone Start-Ergebnis.
final class AutomaticDictationAudioInput: @unchecked Sendable {
    private let audio = AutomaticCaptureAudioQueue.shared
    private lazy var engine = AVAudioEngine()
    private var activeID: UUID?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var hasInputTap = false
    private var previousSystemSoundsDuringRecording = false

    private enum InputError: Error { case unavailable }

    func start(request transfer: AutomaticDictationRequest, id: UUID,
               onLevel: @escaping @Sendable (Double) -> Void) async throws {
        try await audio.perform { [self] in
            let session = AVAudioSession.sharedInstance()
            // setCategory, setActive und Engine-Start können blockieren. Auch auf
            // älteren iOS-Versionen laufen sie deshalb niemals auf dem UI-Thread.
            audio.stopPlayback?()
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            activeID = id
            audio.recordingID = id
            self.request = transfer.value
            do {
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers])
                // iOS unterdrückt Systemtöne bei Mikrofonaufnahmen standardmäßig.
                // Nur für dieses kurze Diktat zulassen und beim Beenden wiederherstellen.
                previousSystemSoundsDuringRecording = session.allowHapticsAndSystemSoundsDuringRecording
                try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
                try session.setActive(true)
                let input = engine.inputNode
                let format = input.outputFormat(forBus: 0)
                guard format.sampleRate > 0, format.channelCount > 0 else { throw InputError.unavailable }
                let meter = AutomaticDictationLevelMeter(sampleRate: format.sampleRate)
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                    transfer.value.append(buffer)
                    if let level = meter.consume(buffer) { onLevel(level) }
                }
                hasInputTap = true
                engine.prepare()
                try engine.start()
            } catch {
                stopOnQueue(id: id)
                throw error
            }
        }
    }

    func announceStart(id: UUID) {
        audio.queue.async { [self] in
            guard activeID == id, engine.isRunning else { return }
            AutomaticDictationSounds.playStarted()
        }
    }

    func stop(id: UUID, outcome: AutomaticDictationSounds.Outcome? = nil) {
        // Vor dem Fortsetzen des Diktat-Aufrufers einreihen: Der Abschlusston
        // darf erst nach dem Freigeben des Mikrofons die Session umstellen.
        audio.queue.async { [self] in stopOnQueue(id: id, outcome: outcome) }
    }

    private func stopOnQueue(id: UUID, outcome: AutomaticDictationSounds.Outcome? = nil) {
        guard activeID == id else { return }
        if engine.isRunning { engine.stop() }
        if hasInputTap {
            engine.inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }
        request?.endAudio()
        request = nil
        activeID = nil
        guard audio.recordingID == id else { return }
        audio.recordingID = nil
        let session = AVAudioSession.sharedInstance()
        try? session.setAllowHapticsAndSystemSoundsDuringRecording(previousSystemSoundsDuringRecording)
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        try? session.setCategory(.ambient, mode: .default)
        // System sounds otherwise inherit playAndRecord and bypass the mute switch.
        // Reactivate Ambient before issuing the completion sound, on this audio queue.
        if let outcome {
            do {
                try session.setActive(true)
                AutomaticDictationSounds.playFinished(outcome)
            } catch { /* Feedback must never block saving. */ }
        }
    }
}

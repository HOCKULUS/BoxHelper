import AVFoundation
import Combine

/// Kurze Rückmeldungen zur Automatik; die Ambient-Kategorie respektiert den Stummmodus.
// Player und Zeitstempel werden ausschließlich auf der gemeinsamen Audio-Queue verwendet.
final class AutomaticCaptureSounds: ObservableObject, @unchecked Sendable {
    private enum Tone: CaseIterable {
        case countdown, finalCountdown, abort

        var frequencies: (start: Double, end: Double) {
            switch self {
            case .countdown: return (660, 660)
            case .finalCountdown: return (880, 880)
            case .abort: return (330, 180)
            }
        }

        var duration: Double {
            switch self {
            case .countdown: return 0.13
            // Die letzte Ziffer akustisch durch einen etwas längeren Ton hervorheben.
            case .finalCountdown: return 0.25
            case .abort: return 0.24
            }
        }
    }

    private var players: [Tone: AVAudioPlayer] = [:]
    private var lastAbortTime: TimeInterval?
    private let audio = AutomaticCaptureAudioQueue.shared

    /// Einmal vorbereiten, damit die ersten Countdown-Ziffern nicht auf die Tonerzeugung warten.
    func prepare() {
        audio.queue.async { [self] in prepareOnQueue() }
    }

    private func prepareOnQueue() {
        // prepareToPlay kann die Session implizit aktivieren und gehört ebenfalls von der UI weg.
        guard audio.recordingID == nil else { return }
        audio.stopPlayback = { [weak self] in self?.stopOnQueue() }
        guard players.isEmpty else { return }
        for tone in Tone.allCases {
            guard let player = try? AVAudioPlayer(data: Self.waveData(for: tone)) else { continue }
            player.prepareToPlay()
            players[tone] = player
        }
    }

    func playCountdown(_ number: Int) {
        guard (1...3).contains(number) else { return }
        audio.queue.async { [self] in play(number == 1 ? .finalCountdown : .countdown) }
    }

    func playAbort() {
        audio.queue.async { [self] in playAbortOnQueue() }
    }

    private func playAbortOnQueue() {
        // Die monotone Uhr und ein sitzungsübergreifender Zeitstempel verhindern Tonfolgen bei vielen Abbrüchen.
        let now = ProcessInfo.processInfo.systemUptime
        guard lastAbortTime.map({ now - $0 >= 2 }) ?? true else { return }
        if play(.abort) { lastAbortTime = now }
    }

    func stop() {
        audio.queue.async { [self] in stopOnQueue() }
    }

    private func stopOnQueue() {
        for player in players.values { player.stop() }
    }

    @discardableResult
    private func play(_ tone: Tone) -> Bool {
        // Ein verspäteter Ton darf die laufende Mikrofonaufnahme nicht auf Ambient umschalten.
        guard audio.recordingID == nil else { return false }
        prepareOnQueue()
        guard let player = players[tone] else { return false }
        do {
            // Ambient mischt mit vorhandener Musik und lässt iOS den Stummschalter berücksichtigen.
            let session = AVAudioSession.sharedInstance()
            if session.category != .ambient || session.mode != .default {
                try session.setCategory(.ambient, mode: .default)
            }
            try session.setActive(true)
            stopOnQueue()
            player.currentTime = 0
            return player.play()
        } catch {
            // Ton ist ergänzendes Feedback: Ein Audioproblem darf die Aufnahme niemals abbrechen.
            return false
        }
    }

    /// Kleine PCM-WAV-Dateien im Speicher, mit weichem Ein-/Ausblenden gegen Knackgeräusche.
    private static func waveData(for tone: Tone) -> Data {
        let sampleRate = 22_050
        let sampleCount = Int(Double(sampleRate) * tone.duration)
        let byteCount = sampleCount * 2
        var data = Data()
        func appendInteger<T: FixedWidthInteger>(_ value: T) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: "RIFF".utf8)
        appendInteger(UInt32(36 + byteCount))
        data.append(contentsOf: "WAVEfmt ".utf8)
        appendInteger(UInt32(16))
        appendInteger(UInt16(1)) // PCM, ein Kanal, 16 Bit.
        appendInteger(UInt16(1))
        appendInteger(UInt32(sampleRate))
        appendInteger(UInt32(sampleRate * 2))
        appendInteger(UInt16(2))
        appendInteger(UInt16(16))
        data.append(contentsOf: "data".utf8)
        appendInteger(UInt32(byteCount))
        let frequencies = tone.frequencies
        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let envelope = min(1, min(time / 0.012, (tone.duration - time) / 0.025))
            let phase = 2 * Double.pi * (frequencies.start * time
                + (frequencies.end - frequencies.start) * time * time / (2 * tone.duration))
            appendInteger(Int16(sin(phase) * envelope * 0.3 * Double(Int16.max)))
        }
        return data
    }
}

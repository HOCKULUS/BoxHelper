import AudioToolbox
import AVFoundation

/// Originale iOS-Aufnahmetöne (1113, 1114, 1116). Alle Aufrufe erfolgen auf
/// AutomaticCaptureAudioQueue. Abschlusstöne nutzen Ambient statt SystemSound,
/// damit die zuvor aktive Mikrofon-Session den Stummschalter nicht umgehen kann.
enum AutomaticDictationSounds {
    enum Outcome: Sendable { case completed, noSpeech }
    nonisolated(unsafe) private static var finishPlayer: AVAudioPlayer?

    static func playStarted() { AudioServicesPlaySystemSound(1113) }

    static func playFinished(_ outcome: Outcome) {
        guard AVAudioSession.sharedInstance().category == .ambient else { return }
        let file = outcome == .completed ? "end_record" : "jbl_no_match"
        let url = URL(fileURLWithPath: "/System/Library/Audio/UISounds/\(file).caf")
        // Falls ein System diesen Ton nicht bereitstellt, bleibt das optionale
        // Feedback still; kein Fallback, der den Stummschalter übergehen könnte.
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        finishPlayer?.stop()
        finishPlayer = player
        player.play()
    }
}

import AVFoundation

/// Alle Audio-Hardwarezugriffe laufen seriell außerhalb des Main Actors.
/// @unchecked Sendable ist hier durch die Queue abgesichert: recordingID wird ausschließlich dort gelesen/geändert.
final class AutomaticCaptureAudioQueue: @unchecked Sendable {
    static let shared = AutomaticCaptureAudioQueue()
    let queue = DispatchQueue(label: "BoxHelper.automaticCapture.audio", qos: .userInitiated)
    var recordingID: UUID?
    var stopPlayback: (@Sendable () -> Void)?

    private init() {}

    func perform<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try operation()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}

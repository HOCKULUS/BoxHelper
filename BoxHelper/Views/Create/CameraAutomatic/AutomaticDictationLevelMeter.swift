import Accelerate
import AVFoundation

/// Ausschließlich vom seriellen Audio-Tap verwendet. Es werden nur Pegel übertragen,
/// keine zusätzlichen Audiopuffer gespeichert oder an den UI-Thread weitergereicht.
final class AutomaticDictationLevelMeter: @unchecked Sendable {
    private let framesPerUpdate: Int
    private var accumulatedFrames = 0
    private var squaredAmplitude = 0.0

    init(sampleRate: Double) {
        framesPerUpdate = max(1, Int(sampleRate / 20))
    }

    func consume(_ buffer: AVAudioPCMBuffer) -> Double? {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return nil }
        let frames = Int(buffer.frameLength)
        var meanSquare: Float = 0
        vDSP_measqv(channel, vDSP_Stride(buffer.stride), &meanSquare, vDSP_Length(frames))
        squaredAmplitude += Double(meanSquare) * Double(frames)
        accumulatedFrames += frames
        guard accumulatedFrames >= framesPerUpdate else { return nil }

        // Logarithmische Sprachskala: leises Grundrauschen bleibt klein, normale Sprache wächst sichtbar.
        let decibels = 10 * log10(max(squaredAmplitude / Double(accumulatedFrames), 1e-10))
        squaredAmplitude = 0
        accumulatedFrames = 0
        return min(1, max(0, (decibels + 55) / 40))
    }
}

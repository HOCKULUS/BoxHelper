import Vision
import CoreVideo
import ImageIO

/// Läuft ausschließlich auf der Kameraqueue und prüft höchstens drei Frames
/// pro Sekunde. Fotoaufnahme und QR-Erkennung teilen denselben Videostream.
final class FeedBoxQRCodeScanner {
    private let request = VNDetectBarcodesRequest()
    private var lastSampleAt = -Double.infinity
    private var presence = FeedBoxQRCodePresence()
    var visibleCode: FeedBoxQRCode? { presence.visibleCode }

    init() { request.symbologies = [.qr] }

    func scan(_ buffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
              at now: Double) -> FeedBoxQRCodeEvent? {
        guard now - lastSampleAt >= 0.35 else { return nil }
        lastSampleAt = now
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: orientation)
        do {
            try handler.perform([request])
            let codes = (request.results ?? []).compactMap { observation in
                observation.payloadStringValue.flatMap { FeedBoxQRCode(payload: $0) }
            }
            guard presence.update(codes: codes, at: now), let code = presence.visibleCode else { return nil }
            return FeedBoxQRCodeEvent(code: code)
        } catch {
            // Ein fehlgeschlagener QR-Frame darf weder Fotoaufnahme noch
            // die bestehende Überwachung mit einem Kamerafehler beenden.
            _ = presence.update(codes: [], at: now)
            return nil
        }
    }
}

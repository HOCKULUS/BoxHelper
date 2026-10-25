import AVFoundation
import QuartzCore

/// Kapselt den nicht-Sendable AVFoundation-Layer mit festen Zuständigkeiten.
/// Einbettung und Geometrie gehören Main; Session und Verbindung ausschließlich
/// der gemeinsamen Capture-Queue. Der rohe Layer verlässt diese Klasse nicht.
/// Diese manuell geprüfte Aufteilung begründet die Sendable-Konformität.
final class EmbeddedCameraPreviewConnection: @unchecked Sendable {
    private let layer: AVCaptureVideoPreviewLayer
    private let queue: DispatchQueue

    @MainActor
    init(queue: DispatchQueue) {
        self.queue = queue
        layer = AVCaptureVideoPreviewLayer()
        layer.videoGravity = .resizeAspectFill
    }

    @MainActor
    func install(in parent: CALayer) {
        parent.addSublayer(layer)
    }

    @MainActor
    func updateFrame(_ frame: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = frame
        CATransaction.commit()
    }

    /// Nur die Capture-Queue darf den Session-Graphen umbauen.
    func attach(to session: AVCaptureSession) {
        dispatchPrecondition(condition: .onQueue(queue))
        layer.session = session
    }

    func detach() {
        dispatchPrecondition(condition: .onQueue(queue))
        layer.session = nil
    }

    func updateRotation(_ angle: CGFloat) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let connection = layer.connection,
              connection.isVideoRotationAngleSupported(angle),
              connection.videoRotationAngle != angle else { return }
        connection.videoRotationAngle = angle
    }
}

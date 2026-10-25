import AVFoundation
import SwiftUI

struct EmbeddedCameraPreview: UIViewControllerRepresentable {
    let camera: EmbeddedItemCamera

    func makeCoordinator() -> EmbeddedItemCamera { camera }

    func makeUIViewController(context: Context) -> CameraPreviewController {
        let controller = CameraPreviewController(camera: camera)
        // UIKit baut die Oberfläche auf Main auf; AVFoundation hängt sie asynchron an.
        camera.attachPreview(controller.surface.preview)
        return controller
    }

    func updateUIViewController(_ controller: CameraPreviewController, context: Context) {
        controller.updateOrientation()
    }

    static func dismantleUIViewController(_ controller: CameraPreviewController, coordinator: EmbeddedItemCamera) {
        coordinator.detachPreview(controller.surface.preview)
    }
}

/// UIKit verwaltet die Vorschau-Geometrie; AVFoundation-Verbindungen gehören zur Capture-Queue.
final class CameraPreviewSurface: UIView {
    // Kein UIView-Backing-Layer: Capture-Verbindungen dürfen auf ihrer Queue
    // konfiguriert werden, ohne UIKit während eines Formularwechsels zu blockieren.
    let preview = EmbeddedCameraPreviewConnection(queue: EmbeddedCameraSessionCoordinator.shared.queue)

    override init(frame: CGRect) {
        super.init(frame: frame)
        preview.install(in: layer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Größe und Einbettung gehören weiterhin ausschließlich zum UI-Thread.
        preview.updateFrame(bounds)
    }
}

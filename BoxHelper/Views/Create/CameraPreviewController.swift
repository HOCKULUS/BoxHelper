import UIKit

/// Der Controller erhält auch eine 180°-Drehung, bei der die quadratische Vorschau gleich groß bleibt.
final class CameraPreviewController: UIViewController {
    let surface = CameraPreviewSurface()
    private let camera: EmbeddedItemCamera
    private var lastOrientation: UIInterfaceOrientation?

    init(camera: EmbeddedItemCamera) {
        self.camera = camera
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() { view = surface }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateOrientation()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateOrientation()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Die WindowScene kennt während/nach dem Übergang die neue App-Ausrichtung.
        // Der Abschluss deckt auch Übergänge ohne erneutes SwiftUI-Layout ab.
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.updateOrientation()
        }, completion: { [weak self] _ in
            self?.updateOrientation()
        })
    }

    func updateOrientation() {
        // Die eigene Scene verwenden: andere iPad-Fenster dürfen den Feed nicht drehen.
        guard let orientation = viewIfLoaded?.window?.windowScene?.interfaceOrientation,
              orientation != lastOrientation else { return }
        let cameraOrientation: EmbeddedCameraRotation.Orientation
        switch orientation {
        case .portrait: cameraOrientation = .portrait
        case .landscapeLeft: cameraOrientation = .landscapeLeft
        case .landscapeRight: cameraOrientation = .landscapeRight
        case .portraitUpsideDown: cameraOrientation = .portraitUpsideDown
        default: return // Bei unbekannter Ausrichtung die letzte gültige Drehung behalten.
        }
        lastOrientation = orientation
        camera.setPreviewOrientation(cameraOrientation)
    }
}

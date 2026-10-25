import Foundation

/// App-Ausrichtung und manuelle Korrektur bleiben getrennt, damit Drehen nichts aufsummiert.
struct EmbeddedCameraRotation: Sendable {
    /// Winkel relativ zum ungedrehten Sensorbild; Hochformat benötigt bereits 90°.
    enum Orientation: Int, Sendable {
        case portrait = 90
        case landscapeLeft = 180
        case landscapeRight = 0
        case portraitUpsideDown = 270
    }

    var orientation: Orientation = .portrait
    private var manualAngle = 0

    var angle: CGFloat { CGFloat((orientation.rawValue + manualAngle) % 360) }

    mutating func rotateClockwise() {
        manualAngle = (manualAngle + 90) % 360
    }
}

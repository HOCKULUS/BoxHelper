import Foundation

/// Beide Formulare verwenden denselben QR-Schalter, aber getrennte Kameraoptionen.
enum CreateCameraPreferences {
    static let itemVoiceNamingKey = "itemVoiceNamingEnabled"
    static let itemSmartCameraKey = "itemSmartCameraEnabled"
    static let boxSmartCameraKey = "boxSmartCameraEnabled"
    static let boxAutomaticModeKey = "boxCameraAutomaticMode"
    // Den bisherigen Schlüssel beibehalten, damit eine bewusste Abschaltung erhalten bleibt.
    static let qrCodeKey = "itemCameraQRCodeEnabled"

    /// Ein offener Feed oder die bloße Auswahl der Automatik startet noch keinen Scan.
    static func shouldScan(cameraRunning: Bool, qrEnabled: Bool,
                           automaticSelected: Bool, captureActive: Bool, loading: Bool) -> Bool {
        cameraRunning && qrEnabled && automaticSelected && captureActive && !loading
    }
}

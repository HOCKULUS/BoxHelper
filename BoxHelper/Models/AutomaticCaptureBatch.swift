import Foundation

/// Eine Serie zählt ausschließlich neue Automatikfotos. Bereits im Entwurf
/// vorhandene Bilder begrenzen weder den Start noch die Länge der neuen Serie.
struct AutomaticCaptureBatch {
    static let photoCountRange = 1...50
    static let itemPhotoCountKey = "itemAutomaticPhotoCount"
    private(set) var capturedCount = 0
    private(set) var target: Int

    init(target: Int) {
        self.target = min(Self.photoCountRange.upperBound, max(Self.photoCountRange.lowerBound, target))
    }

    mutating func recordPhoto() -> Bool {
        capturedCount += 1
        return capturedCount >= target
    }

    static func itemPhotoCount(in defaults: UserDefaults = .standard) -> Int {
        let count = defaults.object(forKey: itemPhotoCountKey) as? Int ?? 1
        return min(photoCountRange.upperBound, max(photoCountRange.lowerBound, count))
    }
}

import Foundation
import CoreGraphics

/// Alle Fragen behalten dieselbe vertikale Reihenfolge. Nur der obere Inhalt
/// darf bei extrem geringer Höhe scrollen; der Skip-Button bleibt am Modusplatz.
struct CreateDictationFeedbackLayout {
    static let locationHeight: CGFloat = 48
    static let locationSpacing: CGFloat = 8
    static let skipSize: CGFloat = 68

    let contentHeight: CGFloat
    let viewportHeight: CGFloat
    let textScale: CGFloat
    let microphoneFrame: CGRect
    let questionFrame: CGRect
    let transcriptFrame: CGRect
    let questionRise: CGFloat
    let skipFrame: CGRect
    let locationFrame: CGRect

    init(size: CGSize, skipCenterY: CGFloat? = nil) {
        let width = size.width
        let centerY = max(Self.skipSize / 2,
                          min(skipCenterY ?? size.height - Self.skipSize / 2 - 16,
                              max(Self.skipSize / 2, size.height - Self.skipSize / 2)))
        skipFrame = CGRect(x: (width - Self.skipSize) / 2, y: centerY - Self.skipSize / 2,
                           width: Self.skipSize, height: Self.skipSize)
        // Mehr Luft zur Ortszeile bei ausreichender Höhe; kleine Fenster
        // behalten den kompakten Abstand und damit Platz für das große Mikrofon.
        let listToSkipGap = 16 + min(32, max(0, (skipFrame.minY - 260) * 0.3))
        viewportHeight = max(0, skipFrame.minY - listToSkipGap)
        // Mikrofon, Frage/Text und die reservierte Ortszeile bleiben untereinander.
        contentHeight = max(164, viewportHeight)
        textScale = min(1, max(0.8, viewportHeight / 260))
        questionRise = 26 * textScale
        locationFrame = CGRect(x: 0, y: contentHeight - Self.locationHeight,
                               width: width, height: Self.locationHeight)
        // Engere Textabstände geben dem Mikrofon gerade in kleinen Fenstern
        // mehr Platz. Die Standortzeile und der feste Skip bleiben unverändert.
        transcriptFrame = CGRect(x: 24, y: locationFrame.minY - 44 * textScale,
                                 width: max(0, width - 48), height: 32 * textScale)
        let microphoneBottom = transcriptFrame.minY - questionRise - 4 * textScale
        let diameter = max(0, min(280, microphoneBottom, width - 32))
        // Die Frage bleibt direkt unter dem Mikrofon, auch auf hohen Displays.
        microphoneFrame = CGRect(x: (width - diameter) / 2, y: microphoneBottom - diameter,
                                 width: diameter, height: diameter)
        questionFrame = CGRect(x: transcriptFrame.minX, y: microphoneFrame.maxY + 8 * textScale,
                               width: transcriptFrame.width, height: transcriptFrame.height)
    }
}

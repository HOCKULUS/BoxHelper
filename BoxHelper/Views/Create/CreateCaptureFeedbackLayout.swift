import CoreGraphics

/// Aufnahme und Abbruch übernehmen Mittelpunkt und Skalierung des Mikrofons.
/// Emoji und Ergebniszeichen behalten dabei ihr gemeinsames Größenverhältnis.
struct CreateCaptureFeedbackLayout {
    let scale: CGFloat
    let emojiFrame: CGRect
    let resultFrame: CGRect

    init(available: CGRect, shutterCenterY: CGFloat? = nil) {
        let dictation = CreateDictationFeedbackLayout(size: available.size,
                                                      skipCenterY: shutterCenterY.map { $0 - available.minY })
        scale = max(0, min(dictation.microphoneFrame.width / 280,
                           (available.width - 32) / 180, available.height / 300))
        let emojiSize = 180 * scale
        let resultSize = 110 * scale
        let gap = 10 * scale
        let minEmojiY = available.minY + emojiSize / 2
        let maxEmojiY = available.maxY - emojiSize / 2 - gap - resultSize
        // Bei extrem geringer Höhe berücksichtigt der Mittelpunkt auch den
        // Scrollversatz des Diktats. Die letzte Begrenzung schützt die Navigation.
        let scrollOffset = max(0, dictation.contentHeight - dictation.viewportHeight)
        let microphoneY = available.minY + dictation.microphoneFrame.midY - scrollOffset
        let emojiY = max(minEmojiY, min(microphoneY, maxEmojiY))
        emojiFrame = CGRect(x: available.midX - emojiSize / 2, y: emojiY - emojiSize / 2,
                            width: emojiSize, height: emojiSize)
        resultFrame = CGRect(x: available.midX - resultSize / 2, y: emojiFrame.maxY + gap,
                             width: resultSize, height: resultSize)
    }
}

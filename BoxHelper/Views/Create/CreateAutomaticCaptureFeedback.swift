import SwiftUI

/// Erst nach der bestätigten Speicherung wird der grüne Haken unter dem Emoji gezeichnet.
struct CreateAutomaticCaptureFeedback: View {
    let emoji: String
    let isSaved: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var checkmarkProgress: CGFloat = 0

    var body: some View {
        CreateCaptureFeedbackPresentation(emoji: emoji) { scale in
            AutomaticCaptureCheckmark()
                .trim(from: 0, to: checkmarkProgress)
                // Kräftige Striche passend zum schweren roten X; der Pfad
                // bleibt für die Zeichenanimation zusammenhängend.
                .stroke(.green, style: StrokeStyle(lineWidth: 18 * scale, lineCap: .round, lineJoin: .round))
                .frame(width: 90 * scale, height: 90 * scale)
                // Auch der runde Anfangspunkt bleibt bis zur Speicherung unsichtbar.
                .opacity(isSaved ? 1 : 0)
                .accessibilityHidden(true)
        }
        .task(id: isSaved) {
            // Bei reduzierter Bewegung erscheint der vollständige Haken unmittelbar.
            if reduceMotion || !isSaved {
                checkmarkProgress = isSaved ? 1 : 0
            } else {
                withAnimation(.easeInOut(duration: 0.65)) {
                    checkmarkProgress = 1
                }
            }
        }
    }
}

/// Der zusammenhängende Pfad zeichnet zuerst den kurzen, dann den langen Strich des Hakens.
private struct AutomaticCaptureCheckmark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.minY + rect.height * 0.5))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.8))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.9, y: rect.minY + rect.height * 0.18))
        return path
    }
}

/// Kurze Rückmeldung zu einem abgebrochenen Countdown, während die erneute Prüfung kurz pausiert.
struct CreateAutomaticCaptureAbortFeedback: View {
    let emoji: String

    var body: some View {
        CreateCaptureFeedbackPresentation(emoji: emoji) { scale in
            Image(systemName: "xmark")
                .font(.system(size: 100 * scale, weight: .heavy))
                .foregroundStyle(.red)
                .accessibilityHidden(true)
        }
    }
}

/// Beide Ergebnisse reservieren denselben Platz unter dem Emoji. Der Haken
/// verschiebt beim Einblenden nichts und das X nutzt dieselben sicheren Grenzen.
private struct CreateCaptureFeedbackPresentation<Result: View>: View {
    let emoji: String
    @ViewBuilder let result: (CGFloat) -> Result
    @Environment(\.createDictationAvailableRect) private var availableRect
    @Environment(\.createCameraShutterFrame) private var shutterFrame

    var body: some View {
        GeometryReader { geometry in
            let fallback = CGRect(x: 0, y: geometry.safeAreaInsets.top, width: geometry.size.width,
                                  height: max(0, geometry.size.height - geometry.safeAreaInsets.top
                                              - geometry.safeAreaInsets.bottom))
            let available = availableRect ?? fallback
            let layout = CreateCaptureFeedbackLayout(available: available,
                                                     shutterCenterY: shutterFrame?.midY)
            ZStack(alignment: .topLeading) {
                Text(emoji)
                    .font(.system(size: 150 * layout.scale))
                    .frame(width: layout.emojiFrame.width, height: layout.emojiFrame.height)
                    .position(x: layout.emojiFrame.midX - available.minX,
                              y: layout.emojiFrame.midY - available.minY)
                result(layout.scale)
                    .frame(width: layout.resultFrame.width, height: layout.resultFrame.height)
                    .position(x: layout.resultFrame.midX - available.minX,
                              y: layout.resultFrame.midY - available.minY)
            }
            // Die Rückmeldung bleibt auch bei extrem kleinen Fenstern im Bereich unter der Navigation.
            .frame(width: available.width, height: available.height, alignment: .topLeading)
            .clipped()
            .position(x: available.midX, y: available.midY)
        }
        .allowsHitTesting(false)
    }
}

/// Derselbe dezente Dialog-Stil wie beim manuellen Speichern, während die Erfassung pausiert.
struct CreateAutomaticThresholdNotice: View {
    var symbol = "wand.and.sparkles.inverse"
    var variableValue: Double? = nil
    var message: LocalizedStringKey = "FeedMonitoring.AdjustingThreshold"
    var detail: String? = nil
    var isWarning = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol, variableValue: variableValue)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(isWarning ? Color.red : Color.primary)
            VStack(alignment: .leading, spacing: 3) {
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let detail { Text(detail).font(.subheadline).lineLimit(2) }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .allowsHitTesting(false)
    }
}

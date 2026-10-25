import SwiftUI

/// Der Countdown übernimmt dieselbe Position und Skalierung wie Mikrofon und Emojis.
struct CreateCameraCountdown: View {
    let number: Int
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
                Text("\(number)")
                    .font(.system(size: 200 * layout.scale, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .foregroundStyle(number == 3 ? Color.red : (number == 2 ? Color.yellow : Color.green))
                    .shadow(color: .black.opacity(0.2), radius: 3 * layout.scale)
                    .frame(width: 280 * layout.scale, height: 280 * layout.scale)
                    .position(x: layout.emojiFrame.midX - available.minX,
                              y: layout.emojiFrame.midY - available.minY)
                    .accessibilityLabel(Text("\(number)"))
            }
            // Große Ziffern bleiben unterhalb der Navigation, auch bei wenig Höhe.
            .frame(width: available.width, height: available.height, alignment: .topLeading)
            .clipped()
            .position(x: available.midX, y: available.midY)
        }
        .allowsHitTesting(false)
    }
}

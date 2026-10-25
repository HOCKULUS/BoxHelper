import SwiftUI

/// Farb- und Unschärfeverlauf zwischen Wolkenfeld und den scharfen Vordergrundelementen.
struct LaunchSkyOverlay: View {
    let backgroundColor: Color

    var body: some View {
        ZStack {
            // Die Verlaufsmaske lässt den Hintergrundblur von oben nach unten
            // auslaufen; am unteren Rand ist das ursprüngliche Wolkenfeld sichtbar.
            LaunchCloudBackdropBlur(intensity: 0.65)
                .mask {
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            LinearGradient(
                colors: [backgroundColor.opacity(0.3), backgroundColor.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

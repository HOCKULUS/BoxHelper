import SwiftUI

/// Der Auslöseranker hält den Skip-Button exakt am bisherigen Modusplatz.
struct CreateCameraFeedbackBounds {
    var shutter: Anchor<CGRect>?
}

struct CreateCameraFeedbackBoundsKey: PreferenceKey {
    static var defaultValue: CreateCameraFeedbackBounds { CreateCameraFeedbackBounds() }

    static func reduce(value: inout CreateCameraFeedbackBounds, nextValue: () -> CreateCameraFeedbackBounds) {
        let next = nextValue()
        value.shutter = next.shutter ?? value.shutter
    }
}

private struct CreateDictationAvailableRectKey: EnvironmentKey {
    static let defaultValue: CGRect? = nil
}

private struct CreateCameraShutterFrameKey: EnvironmentKey {
    static let defaultValue: CGRect? = nil
}

extension EnvironmentValues {
    var createDictationAvailableRect: CGRect? {
        get { self[CreateDictationAvailableRectKey.self] }
        set { self[CreateDictationAvailableRectKey.self] = newValue }
    }
    var createCameraShutterFrame: CGRect? {
        get { self[CreateCameraShutterFrameKey.self] }
        set { self[CreateCameraShutterFrameKey.self] = newValue }
    }
}

/// Innerhalb der Navigation liegt die Rückmeldung über dem ganzen Formular,
/// einschließlich Footer und Auslöser. Nur die Navigation bleibt davor bedienbar.
struct CreateCameraFeedbackOverlay<Feedback: View>: ViewModifier {
    var blurRadius: CGFloat = 0
    @ViewBuilder let feedback: () -> Feedback
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .blur(radius: blurRadius)
            .overlay {
                // Die Abdunklung gehört nur zum unscharfen Hintergrund;
                // Rückmeldung und Navigationsaktionen bleiben unverändert hell.
                if colorScheme == .dark && blurRadius > 0 {
                    Color.black.opacity(0.2).allowsHitTesting(false)
                }
            }
            .animation(.linear(duration: 0.45), value: blurRadius)
            .allowsHitTesting(blurRadius == 0)
            .accessibilityHidden(blurRadius > 0)
            .overlayPreferenceValue(CreateCameraFeedbackBoundsKey.self) { bounds in
                GeometryReader { geometry in
                    // Die Navigation hat ihren Bereich bereits vom Inhalt abgezogen.
                    // Ihre Safe-Area-Inset hier erneut abzuziehen würde kleine Fenster
                    // unnötig verengen und das Mikrofon aus dem sichtbaren Bereich schieben.
                    let top: CGFloat = 12
                    let bottom = geometry.size.height - 12
                    let available = CGRect(x: 0, y: top, width: geometry.size.width,
                                           height: max(0, bottom - top))
                    let shutter = bounds.shutter.map { geometry[$0] }
                    feedback()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .environment(\.createDictationAvailableRect, available)
                        .environment(\.createCameraShutterFrame, shutter)
                }
            }
    }
}

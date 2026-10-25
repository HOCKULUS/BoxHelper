import SwiftUI
import UIKit

/// Einstellbarer Hintergrundblur ohne Glass-Reflexe oder Glasränder.
struct LaunchCloudBackdropBlur: UIViewRepresentable {
    let intensity: Double

    final class Coordinator {
        var animator: UIViewPropertyAnimator?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView()
        view.isUserInteractionEnabled = false

        // Eine pausierte Effektanimation erlaubt die Blur-Stärke stufenlos
        // einzustellen, ohne private Filter oder eine laufende UIKit-Animation.
        let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [weak view] in
            view?.effect = UIBlurEffect(style: .light)
        }
        context.coordinator.animator = animator
        animator.startAnimation()
        animator.pauseAnimation()
        animator.fractionComplete = CGFloat(min(1, max(0, intensity)))
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        context.coordinator.animator?.fractionComplete = CGFloat(min(1, max(0, intensity)))
    }

    static func dismantleUIView(_ view: UIVisualEffectView, coordinator: Coordinator) {
        // Beim Verlassen oder beim Erzeugen eines neuen Wolkenfeldes freigeben.
        coordinator.animator?.stopAnimation(true)
        coordinator.animator = nil
    }
}

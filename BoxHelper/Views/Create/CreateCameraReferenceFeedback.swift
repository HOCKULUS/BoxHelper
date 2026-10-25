import SwiftUI

enum CameraReferenceFeedbackState: Equatable {
    case hidden, searching, retry

    var symbol: String {
        switch self {
        case .hidden, .searching: return "viewfinder"
        case .retry: return "xmark.viewfinder"
        }
    }

    var color: Color {
        switch self {
        case .hidden, .searching: return .white
        case .retry: return .red
        }
    }
}

/// Die zeitgesteuerte Darstellung blinkt ohne Änderungen am Kamerastream oder dessen Layout.
struct CreateCameraReferenceFeedback: View {
    let state: CameraReferenceFeedbackState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Ein ruhiger Blinkzyklus während der verkürzten ersten Referenzaufnahme.
        TimelineView(.animation(minimumInterval: 0.75, paused: state != .searching || reduceMotion)) { context in
            let bright = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.5) < 0.75
            Image(systemName: state.symbol)
                // Beide Forms nutzen dieselbe 1,5-fache Größe und ein um zwei
                // Schriftgewichtsstufen dünneres Symbol (medium → regular → light).
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(state.color)
                .opacity(state == .searching && !reduceMotion && !bright ? 0.25 : 1)
                .shadow(color: .black.opacity(0.6), radius: 2)
        }
        .allowsHitTesting(false)
    }
}

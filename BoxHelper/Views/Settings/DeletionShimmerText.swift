import SwiftUI

/// Ein heller Streifen läuft wie beim früheren iOS-Entsperrtext durch die Buchstaben.
struct DeletionShimmerText: View {
    let title: LocalizedStringKey
    var isPaused = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isPaused)) { context in
            Text(title)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .overlay {
                    if !isPaused {
                        GeometryReader { geometry in
                            let width = geometry.size.width
                            let band = max(40, width * 0.3)
                            let phase = context.date.timeIntervalSinceReferenceDate
                                .truncatingRemainder(dividingBy: 2.4) / 2.4
                            LinearGradient(colors: [.clear, .white.opacity(0.95), .clear],
                                           startPoint: .leading, endPoint: .trailing)
                                .frame(width: band)
                                .offset(x: -band + (width + band) * phase)
                        }
                        .mask {
                            Text(title).font(.body).multilineTextAlignment(.center)
                        }
                    }
                }
        }
    }
}

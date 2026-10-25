import SwiftUI

/// Weiße Wolken gleiten nach unten und vermitteln dadurch einen stetigen Aufstieg.
struct LaunchLoopingBackground: View {
    let isVisible: Bool
    let isStopping: Bool
    let isExiting: Bool
    let revealDuration: TimeInterval

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var cloudField = LaunchCloudField()
    @State private var lastUpdateDate: Date?

    private var isPaused: Bool {
        !isVisible || reduceMotion || scenePhase != .active || cloudField.hasStopped
    }

    var body: some View {
        GeometryReader { geometry in
            // Feste Ränder halten auch große, unscharfe Wolken beim Loop-Wechsel
            // vollständig außerhalb des Bildes, sodass kein Sprung sichtbar ist.
            let referenceWidth = min(geometry.size.width, geometry.size.height, 900)
            let margin = referenceWidth * 0.4 + 24
            let travelHeight = geometry.size.height + margin * 2

            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: isPaused)) { timeline in
                ZStack {
                    ForEach(cloudField.clouds) { cloud in
                        let width = referenceWidth * cloud.renderedRelativeWidth

                        LaunchCloudView(width: width, backdropBlurIntensity: cloud.backdropBlurIntensity)
                            .blur(radius: cloud.blurRadius)
                            .opacity(cloud.opacity)
                            .position(
                                x: geometry.size.width * cloud.renderedHorizontalPosition,
                                y: -margin + cloud.progress * travelHeight
                            )
                            // Transparente, kleine Wolken liegen auch beim Überlappen hinten.
                            .zIndex(cloud.opacity)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .onChange(of: timeline.date) { _, date in
                    updateClouds(at: date)
                }
            }
        }
        .clipped()
        // Gleiche Einblenddauer wie beim Logo; die Wolken bewegen sich bereits dabei.
        .opacity(isVisible && !isExiting ? 1 : 0)
        .animation(.easeInOut(duration: revealDuration), value: isVisible)
        .animation(.easeInOut(duration: revealDuration), value: isExiting)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            cloudField = LaunchCloudField()
            lastUpdateDate = nil
        }
        .onChange(of: isPaused) { _, _ in
            // Nach App-Unterbrechungen keinen Zeitsprung in die Flugbahn übernehmen.
            lastUpdateDate = nil
        }
    }

    private func updateClouds(at date: Date) {
        guard !isPaused else {
            lastUpdateDate = nil
            return
        }
        defer { lastUpdateDate = date }
        guard let previousDate = lastUpdateDate else { return }
        cloudField.advance(by: date.timeIntervalSince(previousDate), isStopping: isStopping)
    }
}

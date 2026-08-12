/*

//
//  LauchScreen.swift
//  BoxHelper
//
//  Created by HOCKULUS on 14.03.25.
//

import SwiftUI

struct LaunchScreen: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var showLogo = false
    @State private var showUpdateText = false
    @State private var showContinueButton = false
    @State private var isExiting = false
    @State private var contentOffsetY: CGFloat = 0
    @State private var contentOpacity = 1.0
    @State private var layerOpacity = 0.0
    @State private var didTapWeiter = false
    @State private var headerLift: CGFloat = 0
    @State private var backgroundMotionProgress = 0.0
    @State private var backgroundWobbleIntensity = 0.0
    @State private var backgroundExitProgress = 0.0
    @Binding var isActive : Bool

    var body: some View {
        ZStack {
            HStack {
                VStack {
                    Spacer()
                }
                Spacer()
            }
            .background(colorScheme == .dark ? Color.black : Color.black.opacity(0.8))
            LaunchLoopingBackground(
                isVisible: true,
                motion: backgroundMotionProgress,
                wobble: backgroundWobbleIntensity,
                layerVisibility: layerOpacity,
                exitProgress: backgroundExitProgress
            )

            HStack {
                VStack {
                    Spacer()
                }
                Spacer()
            }
            .background(colorScheme == .dark ? Color.black : Color.white)
            .opacity(0.10)

            VStack {
                Spacer()
                VStack(spacing: 14) {
                    ZStack {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.white)
                            .scaleEffect(showLogo ? 1.1 : 0.88)
                            .opacity(showLogo ? 1 : 0)
                            .animation(.easeInOut(duration: 0.75), value: showLogo)
                            .padding(.bottom, 170)
                    }
                    .frame(height: 240)
                    .offset(y: headerLift)

                    Text("BoxHelper")
                        .font(.system(size: 65, weight: .bold))
                        .opacity(showLogo ? 1 : 0)
                        .animation(.easeInOut(duration: 0.65), value: showLogo)
                        .offset(y: headerLift)

                    Text("Update abgeschlossen")
                        .font(.title3.weight(.semibold))
                        .opacity(showUpdateText ? 1 : 0)
                        .animation(.easeInOut(duration: 0.45), value: showUpdateText)
                        .frame(height: 28)
                }

                Spacer()

                Button(didTapWeiter ? "Fortfahren" : "Weiter") {
                    if didTapWeiter {
                        startExitFlow()
                    } else {
                        didTapWeiter = true
                        withAnimation(.easeInOut(duration: 0.9)) {
                            headerLift = -85
                            backgroundMotionProgress = 0.72
                            backgroundWobbleIntensity = 0.75
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.easeOut(duration: 1.2)) {
                                backgroundWobbleIntensity = 0.35
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.top, 20)
                .padding(.bottom, 40)
                .opacity(showContinueButton ? 1 : 0)
                .animation(.easeInOut(duration: 0.45), value: showContinueButton)
                .disabled(!showContinueButton || isExiting)
            }
            .offset(y: contentOffsetY)
            .opacity(contentOpacity)
            .frame(alignment: .center)
            .ignoresSafeArea(.all)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(alignment: .center)
        .ignoresSafeArea(.all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Always restart in step 1 when the launch screen appears again.
            showLogo = false
            showUpdateText = false
            showContinueButton = false
            didTapWeiter = false
            isExiting = false
            headerLift = 0
            contentOffsetY = 0
            contentOpacity = 1.0
            layerOpacity = 0.0
            backgroundMotionProgress = 0.0
            backgroundWobbleIntensity = 0.0
            backgroundExitProgress = 0.0

            // Step 1: logo + layers fade in together.
            withAnimation(.easeInOut(duration: 0.8)) {
                showLogo = true
                layerOpacity = 1.0
                backgroundWobbleIntensity = 0.55
            }
            withAnimation(.easeInOut(duration: 1.2)) {
                backgroundMotionProgress = 0.35
            }

            // Step 2: show update text under app name, then bottom button.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                withAnimation(.easeInOut(duration: 0.45)) {
                    showUpdateText = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                withAnimation(.easeInOut(duration: 0.45)) {
                    showContinueButton = true
                }
            }
        }
    }

    private func startExitFlow() {
        guard !isExiting else { return }
        isExiting = true

        // Content swipes upward and fades out.
        withAnimation(.easeInOut(duration: 0.8)) {
            contentOffsetY = -520
            contentOpacity = 0.0
            showContinueButton = false
        }

        // Background: one last gentle spin + push forward + fade out.
        withAnimation(.easeInOut(duration: 1.25)) {
            backgroundWobbleIntensity = 1.0
            backgroundMotionProgress = 1.15
            backgroundExitProgress = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            withAnimation {
                isActive = false
            }
        }
    }
}

private struct LaunchLoopingBackground: View {
    let isVisible: Bool
    let motion: Double
    let wobble: Double
    let layerVisibility: Double
    let exitProgress: Double
    // Shared loop time for consistent per-layer phase wrapping.
    private let loopDuration: TimeInterval = 24
    private let layerOffsets: [Double] = [0.00,0.18,0.36, 0.54, 0.67]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let progress = (t.truncatingRemainder(dividingBy: loopDuration)) / loopDuration

            ZStack {
                ForEach(Array(layerOffsets.enumerated()), id: \.offset) { index, offset in
                    // Layers stay calm until motion rises, then perform one near-pass and settle softly.
                    let phaseTravel = motion * 0.95
                    let p = (phaseTravel + offset).truncatingRemainder(dividingBy: 1.0)
                    let eased = p * p
                    let zoomBoost = 0.35 + motion * 0.85
                    let scale = (2.9 + eased * 6.2 * zoomBoost) + exitProgress * 1.8
                    let blur = (8.0 + eased * 32.0 * zoomBoost) + exitProgress * 14.0
                    let baseOpacity = (0.52 - eased * 0.28) + Double(index) * 0.02
                    let fadeIn = min(1.0, max(0.0, p / 0.22))
                    let fadeOut = min(1.0, max(0.0, (1.0 - p) / 0.28))
                    let opacity = baseOpacity * fadeIn * (fadeOut * fadeOut) * layerVisibility * (1.0 - exitProgress)
                    let sway = sin((progress + Double(index) * 0.09) * .pi * 2.0)
                    let rotation = (Double(index) * 14.0) + sway * (36.0 * wobble) + eased * (3.0 * wobble)
                    let hue = (Double(index) * 42.0) + eased * 145.0 + motion * 20.0 - 10.0

                    Image("Background")
                        .resizable()
                        .scaledToFit()
                        .edgesIgnoringSafeArea(.all)
                        .blur(radius: blur)
                        .opacity(isVisible ? max(0.0, min(0.66, opacity)) : 0)
                        .rotationEffect(.degrees(rotation))
                        .scaleEffect(scale)
                        .hueRotation(.degrees(hue))
                }
            }
            .animation(.easeInOut(duration: 1.0), value: isVisible)
        }
    }
}

 /*
struct LaunchScreen_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreen()
    }
}
*/

#Preview {
    LaunchScreen(isActive: Binding(get: { true }, set: { _ in }))
}

*/

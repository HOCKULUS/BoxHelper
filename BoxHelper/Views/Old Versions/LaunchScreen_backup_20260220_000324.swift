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

    // Human readable app version shown in the update stage.
    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (\(build))"
    }

    // Static curated update list provided by product requirements.
    private let updates = [
        NSLocalizedString("🛡️ Nothing is lost. Any input you make while creating content is preserved across app restarts until you explicitly save it. You can continue exactly where you left off.", comment: ""),
        NSLocalizedString("📄 New CSV import and export give you more flexibility. You can now bring in existing data from other apps and tools.", comment: ""),
        NSLocalizedString("✏️ Made a typo? No issue. Items created while setting up a new box can now be edited permanently.", comment: ""),
        NSLocalizedString("🔢 The box naming scheme now supports custom numbering. If you work together with others, you can simply start with a higher number.", comment: ""),
        NSLocalizedString("🏷️ QR codes are now more customizable. You can print location colors or reduce the QR code size to make room for other content. The relevant settings are now linked directly in the create tab for quick access.", comment: ""),
        NSLocalizedString("🖼️ A new images tab gives you a fast overview of all your content. Images from boxes and items are shown together so searching is easier.", comment: ""),
        NSLocalizedString("👉 Switch faster and more intuitively between tabs in the first screen using horizontal swipes.", comment: ""),
        NSLocalizedString("🗑️ Items and locations can now be deleted directly from their lists, just like boxes. Locations that still contain boxes are protected.", comment: ""),
        NSLocalizedString("🧭 Deep navigation has been added. Locations and items can now be opened and edited directly from within a box.", comment: ""),
        NSLocalizedString("🔁 The image viewer has been redesigned. You can swipe between images, reorder them via drag and drop, delete them, and view additional image details.", comment: ""),
        NSLocalizedString("📦 Boxes can now be moved in bulk to a new location. Simply open the current location to get started.", comment: ""),
        NSLocalizedString("⚙️ Settings have been reworked again and grouped into clearer categories to make everything easier to find.", comment: ""),
        NSLocalizedString("🚀 Overall app performance has been improved.", comment: "")
    ]

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

            VStack(spacing: 0) {
                Spacer(minLength: 48)

                VStack(spacing: 10) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 82, height: 82)
                        .scaleEffect(showLogo ? 1.0 : 0.88)
                        .opacity(showLogo ? 1 : 0)
                        .animation(.easeInOut(duration: 0.75), value: showLogo)

                    Text("BoxHelper")
                        .font(.system(size: 56, weight: .bold))
                        .opacity(showLogo ? 1 : 0)
                        .animation(.easeInOut(duration: 0.65), value: showLogo)
                }
                .offset(y: headerLift)

                Text("Update abgeschlossen")
                    .font(.title3.weight(.semibold))
                    .opacity(showUpdateText ? 1 : 0)
                    .animation(.easeInOut(duration: 0.45), value: showUpdateText)
                    .frame(height: 28)
                    .padding(.top, 12)

                if didTapWeiter {
                    VStack(spacing: 10) {
                        Text(appVersionText)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(updates.enumerated()), id: \.offset) { _, update in
                                    updateSection(text: update)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(maxHeight: 220)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()

                Button(didTapWeiter ? "Fortfahren" : "Weiter") {
                    if didTapWeiter {
                        startExitFlow()
                    } else {
                        withAnimation(.easeInOut(duration: 0.8)) {
                            didTapWeiter = true
                            headerLift = -80
                            backgroundMotionProgress = 0.72
                            backgroundWobbleIntensity = 0.75
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                            withAnimation(.easeOut(duration: 1.1)) {
                                backgroundWobbleIntensity = 0.35
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .frame(height: 88)
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

    @ViewBuilder
    private func updateSection(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(.blue)
                .padding(.top, 2)
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(10)
        .modifier(LaunchUpdateCardStyle())
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

private struct LaunchUpdateCardStyle: ViewModifier {
    // On iOS 26 we prefer liquid glass, otherwise we use material fallback.
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.clear)
                .background(.ultraThinMaterial.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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

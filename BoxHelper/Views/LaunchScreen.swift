
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
    @State private var showAutoAdvanceProgress = false
    @State private var isExiting = false
    @State private var contentOffsetY: CGFloat = 0
    @State private var contentOpacity = 1.0
    @State private var layerOpacity = 0.0
    @State private var didTapWeiter = false
    @State private var headerLift: CGFloat = 0
    @State private var backgroundMotionProgress = 0.0
    @State private var backgroundWobbleIntensity = 0.0
    @State private var backgroundExitProgress = 0.0
    @State private var showIntroVisuals = false
    @State private var isScreenSaverVisible = false
    @State private var inactivityWorkItem: DispatchWorkItem?
    @State private var autoAdvanceWorkItem: DispatchWorkItem?
    @State private var autoAdvanceProgress = 0.0
    @Binding var isActive : Bool
    private let inactivityTimeout: TimeInterval = 60
    private let introRevealDuration: TimeInterval = 1.2
    private let introBackgroundDuration: TimeInterval = 1.7
    private let introTextFadeDuration: TimeInterval = 0.95
    private let stageTransitionDuration: TimeInterval = 1.15
    private let exitDuration: TimeInterval = 1.0

    // Human readable app version shown in the update stage.
    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        //let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(version)"
    }

    // Static update list shown in the launch changelog section.
    let updates = [
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
                isVisible: showIntroVisuals,
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

            // Phase 1/2: Logo-Layer (zentriert im Intro, später nach oben versetzt nach "Weiter").
            VStack {
                if !didTapWeiter {
                    Spacer()
                }
                
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .scaleEffect(showLogo ? 1.1 : 0.0)
                    .opacity(showLogo ? 1 : 0)
                    .animation(.easeInOut(duration: introRevealDuration), value: showLogo)
                    .padding(.bottom, 170)
                Spacer()
            }
            //.frame(height: didTapWeiter ? 65 : nil)
            .padding(.top, didTapWeiter ? 67 : nil)
            .padding(.bottom, !didTapWeiter ? 16 : nil)
            .ignoresSafeArea(.all)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: isExiting ? -500 : 0)
            .opacity(isExiting ? 0 : 1)
            .animation(.easeInOut(duration: exitDuration), value: isExiting)

            // Phase 1/2: App-Name-Layer (gleiche Phase wie Logo).
            VStack {
                if !didTapWeiter {
                    Spacer()
                }
                VStack {
                    Text("BoxHelper")
                        .font(.system(size: 65, weight: .bold))
                        //.opacity(showLogo ? 1 : 0)
                        .animation(.easeInOut(duration: introRevealDuration), value: showLogo)
                }
                Spacer()
            }
            .padding(.top, didTapWeiter ? 155 : nil)
            .padding(.bottom, !didTapWeiter ? 16 : nil)
            .ignoresSafeArea(.all)
            //.frame(height: didTapWeiter ? 80 : nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: isExiting ? -500 : 0)
            .opacity(isExiting ? 0 : 1)
            .animation(.easeInOut(duration: exitDuration), value: isExiting)

            // Phase 2/3: Changelog + CTA-Bereich.
            VStack {
                // Phase 2: Nach "Weiter" werden Version + Updates eingeblendet.
                if didTapWeiter {
                    VStack {
                        Text(appVersionText)
                            .foregroundStyle(.secondary)
                        ScrollView(showsIndicators: false) {
                            ForEach(updates, id: \.self) { update in
                                if #available(iOS 26.0, *) {
                                    HStack {
                                        HStack {
                                            Text(update)
                                                .multilineTextAlignment(.leading)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                    }
                                    .frame(maxWidth: 800)
                                    .glassEffect(in: .rect(cornerRadius: 10.0))
                                    //.glassEffect()
                                } else {
                                    HStack {
                                        HStack {
                                            Text(update)
                                                .multilineTextAlignment(.leading)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                    }
                                    .background(.ultraThinMaterial)
                                    .frame(maxWidth: 800)
                                    .cornerRadius(10.0)
                                }
                            }
                        }
                        .cornerRadius(10)
                        .padding(.horizontal, 5)
                    }
                    .padding(.top, 250)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .offset(y: isExiting ? -500 : 0)
                    .opacity(isExiting ? 0 : 1)
                    .animation(.easeInOut(duration: exitDuration), value: isExiting)

                }
                else {
                    Spacer()
                }

                Group {
                    if showUpdateText && !didTapWeiter {
                        Text("Update abgeschlossen")
                            .font(.title3.weight(.semibold))
                    } else if showAutoAdvanceProgress && !didTapWeiter {
                        introProgressBar
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 30)
                .padding(.top, 20)
                .offset(y: isExiting ? 500 : 0)
                .animation(.easeInOut(duration: exitDuration), value: isExiting)
                .opacity(isExiting ? 0 : 1)

                Button(didTapWeiter ? "Fortfahren" : "Weiter") {
                    if didTapWeiter {
                        withAnimation(.easeInOut(duration: stageTransitionDuration)) {
                            backgroundMotionProgress = 0.102
                            backgroundWobbleIntensity = 0.75
                        }
                        startExitFlow()
                    } else {
                        advanceToUpdateStage()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.top, 20)
                .padding(.bottom, 40)
                .opacity(showContinueButton ? 1 : 0)
                .animation(.easeInOut(duration: introTextFadeDuration), value: showContinueButton)
                .disabled(!showContinueButton || isExiting)
                .offset(y: isExiting ? 500 : 0)
                .animation(.easeInOut(duration: exitDuration), value: isExiting)
                .opacity(isExiting ? 0 : 1)
            }

            if isScreenSaverVisible {
                LaunchScreensaverOverlay {
                    registerUserInteraction()
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .frame(alignment: .center)
        .ignoresSafeArea(.all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Jede Berührung setzt den Inaktivitäts-Timer zurück und beendet den Screensaver.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    registerUserInteraction()
                }
        )
        .onAppear {
            // Reset: Beim erneuten Anzeigen immer wieder bei Phase 1 starten.
            showLogo = false
            showUpdateText = false
            showContinueButton = false
            showAutoAdvanceProgress = false
            showIntroVisuals = false
            didTapWeiter = false
            isExiting = false
            headerLift = 0
            contentOffsetY = 0
            contentOpacity = 1.0
            layerOpacity = 0.0
            backgroundMotionProgress = 0.0
            backgroundWobbleIntensity = 0.0
            backgroundExitProgress = 0.0
            autoAdvanceProgress = 0.0

            // Phase 1: Ruhiger Einstieg nur mit Ladebalken.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: introTextFadeDuration)) {
                    showAutoAdvanceProgress = true
                }
                startAutoAdvance()
            }

            scheduleInactivityTimer()
        }
        .onDisappear {
            inactivityWorkItem?.cancel()
            autoAdvanceWorkItem?.cancel()
        }
    }

    private var introProgressBar: some View {
        ProgressView(value: autoAdvanceProgress, total: 1.0)
            .progressViewStyle(.linear)
            .tint(.white)
            .frame(width: 220)
    }

    private func startAutoAdvance() {
        autoAdvanceWorkItem?.cancel()
        autoAdvanceProgress = 0.0
        scheduleNextProgressStep()
    }

    private func scheduleNextProgressStep() {
        guard !didTapWeiter, !isExiting else { return }

        let remainingProgress = max(0.0, 1.0 - autoAdvanceProgress)
        guard remainingProgress > 0 else {
            finishProgressAndRevealVisuals()
            return
        }

        let progressStep = min(remainingProgress, Double.random(in: 0.14 ... 0.33))
        let progressDelay = Double.random(in: 0.25 ... 0.7)
        let progressAnimationDuration = Double.random(in: 0.18 ... 0.45)

        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: progressAnimationDuration)) {
                autoAdvanceProgress += progressStep
            }

            if autoAdvanceProgress >= 0.999 {
                autoAdvanceProgress = 1.0
                finishProgressAndRevealVisuals()
            } else {
                scheduleNextProgressStep()
            }
        }

        autoAdvanceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + progressDelay, execute: workItem)
    }

    private func finishProgressAndRevealVisuals() {
        guard !didTapWeiter, !isExiting else { return }
        autoAdvanceWorkItem?.cancel()

        showAutoAdvanceProgress = false
        showUpdateText = true

        withAnimation(.easeInOut(duration: stageTransitionDuration)) {
            showIntroVisuals = true
            showLogo = true
            layerOpacity = 1.0
            showContinueButton = true
            backgroundMotionProgress = 0.35
            backgroundWobbleIntensity = 0.55
        }
    }

    private func advanceToUpdateStage() {
        guard !didTapWeiter, !isExiting else { return }
        didTapWeiter = true
        withAnimation(.easeInOut(duration: stageTransitionDuration)) {
            // Keep the stage change subtle: a little extra zoom and some rotation only.
            showContinueButton = true
            backgroundMotionProgress = 0.58
            backgroundWobbleIntensity = 0.30
        }
        withAnimation(.easeOut(duration: stageTransitionDuration)) {
            backgroundWobbleIntensity = 0.22
        }
    }

    private func startExitFlow() {
        guard !isExiting else { return }
        isExiting = true
        inactivityWorkItem?.cancel()
        autoAdvanceWorkItem?.cancel()

        // Phase 3: Content fährt nach oben und blendet aus.
        withAnimation(.easeInOut(duration: exitDuration)) {
            contentOffsetY = -520
            contentOpacity = 0.0
            showContinueButton = false
        }

        // Phase 3: Hintergrund bekommt finalen Impuls und blendet aus.
        withAnimation(.easeInOut(duration: 1.5)) {
            backgroundWobbleIntensity = 1.0
            backgroundMotionProgress = 1.15
            backgroundExitProgress = 1.0
            isActive = false
        }
    }

    private func registerUserInteraction() {
        if isScreenSaverVisible {
            withAnimation(.easeInOut(duration: 0.2)) {
                isScreenSaverVisible = false
            }
        }
        scheduleInactivityTimer()
    }

    private func scheduleInactivityTimer() {
        inactivityWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.3)) {
                isScreenSaverVisible = true
            }
        }
        inactivityWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + inactivityTimeout, execute: workItem)
    }
}

private struct LaunchScreensaverOverlay: View {
    let onInteraction: () -> Void
    @State private var logoPosition = CGPoint.zero
    @State private var velocity = CGSize(width: 175, height: 140)
    @State private var lastUpdateDate: Date?
    @State private var hasInitialized = false
    @State private var movingContentSize = CGSize(width: 220, height: 120)

    private let minHorizontalSpeed: CGFloat = 120
    private let minVerticalSpeed: CGFloat = 90

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()

                HStack(spacing: 12) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Text("BoxHelper")
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 7)
                // Ermittelt die tatsächliche Größe des bewegten Elements für präzise Kollisionen.
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ScreensaverContentSizePreferenceKey.self, value: geo.size)
                    }
                )
                .offset(x: logoPosition.x, y: logoPosition.y)
            }
            .onPreferenceChange(ScreensaverContentSizePreferenceKey.self) { newSize in
                guard newSize.width > 0, newSize.height > 0 else { return }
                movingContentSize = newSize
                clampPosition(in: proxy.size)
            }
            // TimelineView liefert kontinuierliche Animationstakte für den Bounce.
            .overlay {
                TimelineView(.animation) { timeline in
                    Color.clear
                        .onAppear {
                            initializeIfNeeded(in: proxy.size)
                        }
                        .onChange(of: proxy.size, initial: false) { _, newSize in
                            initializeIfNeeded(in: newSize)
                            clampPosition(in: newSize)
                        }
                        .onChange(of: timeline.date, initial: false) { _, newDate in
                            updatePosition(at: newDate, in: proxy.size)
                        }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onInteraction()
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        onInteraction()
                    }
            )
        }
    }

    private func initializeIfNeeded(in size: CGSize) {
        guard !hasInitialized else { return }
        hasInitialized = true

        // Startpunkt und Richtung werden zufällig gesetzt, damit die Laufbahn variiert.
        let maxX = max(0, size.width - movingContentSize.width)
        let maxY = max(0, size.height - movingContentSize.height)
        logoPosition = CGPoint(
            x: CGFloat.random(in: 0...maxX),
            y: CGFloat.random(in: 0...maxY)
        )

        let directionX: CGFloat = Bool.random() ? 1 : -1
        let directionY: CGFloat = Bool.random() ? 1 : -1
        velocity = CGSize(
            width: directionX * CGFloat.random(in: minHorizontalSpeed...230),
            height: directionY * CGFloat.random(in: minVerticalSpeed...190)
        )
        lastUpdateDate = nil
    }

    private func updatePosition(at date: Date, in size: CGSize) {
        guard hasInitialized else {
            initializeIfNeeded(in: size)
            return
        }

        guard let previous = lastUpdateDate else {
            lastUpdateDate = date
            return
        }
        lastUpdateDate = date

        let dt = max(0.0, min(0.045, date.timeIntervalSince(previous)))
        guard dt > 0 else { return }

        let maxX = max(0, size.width - movingContentSize.width)
        let maxY = max(0, size.height - movingContentSize.height)

        logoPosition.x += velocity.width * dt
        logoPosition.y += velocity.height * dt

        if logoPosition.x <= 0 || logoPosition.x >= maxX {
            logoPosition.x = min(max(logoPosition.x, 0), maxX)
            velocity.width = -velocity.width
            randomizeTrajectory()
        }

        if logoPosition.y <= 0 || logoPosition.y >= maxY {
            logoPosition.y = min(max(logoPosition.y, 0), maxY)
            velocity.height = -velocity.height
            randomizeTrajectory()
        }
    }

    private func randomizeTrajectory() {
        // Kleine Zufallsänderungen erzeugen das gewünschte "zufällige Abprallen".
        velocity.width += CGFloat.random(in: -20...20)
        velocity.height += CGFloat.random(in: -20...20)

        if abs(velocity.width) < minHorizontalSpeed {
            velocity.width = minHorizontalSpeed * (velocity.width < 0 ? -1 : 1)
        }
        if abs(velocity.height) < minVerticalSpeed {
            velocity.height = minVerticalSpeed * (velocity.height < 0 ? -1 : 1)
        }
    }

    private func clampPosition(in size: CGSize) {
        let maxX = max(0, size.width - movingContentSize.width)
        let maxY = max(0, size.height - movingContentSize.height)
        logoPosition.x = min(max(logoPosition.x, 0), maxX)
        logoPosition.y = min(max(logoPosition.y, 0), maxY)
    }
}

private struct ScreensaverContentSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
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
    private let layerOffsets: [Double] = [0.00,0.18,0.36]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let progress = (t.truncatingRemainder(dividingBy: loopDuration)) / loopDuration

            ZStack {
                ForEach(Array(layerOffsets.enumerated()), id: \.offset) { index, offset in
                    // Layers stay calm until motion rises, then perform one near-pass and settle softly.
                    let phaseTravel = motion * 0.95 // Gesamtfortschritt der Layer im Loop (wird von "motion" getrieben).
                    let p = (phaseTravel + offset).truncatingRemainder(dividingBy: 1.0) // Normierte Phase 0...1 pro Layer inkl. Startversatz.
                    let eased = p * p // Einfaches Ease-In: frühe Phase langsamer, spätere schneller.
                    let zoomBoost = 0.35 + motion * 0.85 // Verstärkt Zoomdynamik, je weiter die Animation fortgeschritten ist.
                    let scale = (2.9 + eased * 6.2 * zoomBoost) + exitProgress * 1.8 // Tatsächlicher Zoomfaktor inkl. zusätzlichem Exit-Push.
                    let blur = (8.0 + eased * 12.0 * zoomBoost) + exitProgress * 14.0 // Unschärfe nimmt beim "nach vorn kommen" und beim Exit zu.
                    let baseOpacity = (0.52 - eased * 0.28) + Double(index) * 0.02 // Grundsichtbarkeit pro Layer (mit leichter Layer-Staffelung).
                    let fadeIn = min(1.0, max(0.0, p / 0.22)) // Sanftes Einblenden am Anfang des Layer-Zyklus.
                    let fadeOut = min(1.0, max(0.0, (1.0 - p) / 0.28)) // Sanftes Ausblenden gegen Ende des Layer-Zyklus.
                    let opacity = baseOpacity * fadeIn * (fadeOut * fadeOut) * layerVisibility * (1.0 - exitProgress) // Finale Opazität inkl. globaler Sichtbarkeit und Exit-Fade.
                    let sway = sin((progress + Double(index) * 0.9) * .pi * 2.0) // Seitliches/rotatorisches "Taumeln" je Layer.
                    let rotation = (Double(index) * 14.0) + sway * (16.0 * wobble) + eased * (3.0 * wobble) // Endrotation: Basiswinkel + Taumeln + leichter Vorwärtsdrall.
                    let hue = (Double(index) * 42.0) + eased * 105.0 + motion * 20.0 - 10.0 // Farbverschiebung pro Layer über Zeit/Phase.

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

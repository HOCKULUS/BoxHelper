
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
    @State private var showIntroVisuals = false
    @State private var isScreenSaverVisible = false
    @State private var inactivityWorkItem: DispatchWorkItem?
    @Binding var isActive : Bool
    private let inactivityTimeout: TimeInterval = 60
    private let introRevealDuration: TimeInterval = 1.5
    private let introTextFadeDuration: TimeInterval = 1.5
    private let stageTransitionDuration: TimeInterval = 1.5
    private let exitDuration: TimeInterval = 1.5

    // Human readable app version shown in the update stage.
    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        //let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(version)"
    }

    // Ziel des Repository-Buttons in der Open-Source-Ankündigung.
    private let repositoryURL = URL(string: "https://github.com/HOCKULUS/BoxHelper")!

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
            .animation(.easeInOut(duration: introTextFadeDuration), value: didTapWeiter)

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
            .padding(.top, didTapWeiter ?  155 : nil)
            .padding(.bottom, !didTapWeiter ? 16 : nil)
            .ignoresSafeArea(.all)
            //.frame(height: didTapWeiter ? 80 : nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: isExiting ? -500 : 0)
            .opacity(isExiting ? 0 : 1)
            .animation(.easeInOut(duration: exitDuration), value: isExiting)
            .animation(.easeInOut(duration: introTextFadeDuration), value: didTapWeiter)

            // Phase 2/3: Changelog + CTA-Bereich.
            VStack {
                // Phase 2: Nach "Weiter" werden Version + Updates eingeblendet.
                VStack {
                    Text(appVersionText)
                        .foregroundStyle(.secondary)
                        .opacity(didTapWeiter ? 1 : 0)
                        .offset(y: didTapWeiter ? 0 : 100)
                        .animation(.easeInOut(duration: introTextFadeDuration), value: didTapWeiter)
                    ScrollView(showsIndicators: false) {
                        LaunchOpenSourceAnnouncement(repositoryURL: repositoryURL)
                    }
                    .cornerRadius(10)
                    .padding(.horizontal, 8)
                    .opacity(didTapWeiter ? 1 : 0)
                    .offset(y: didTapWeiter ? 0 : 100)
                    .animation(.easeInOut(duration: introTextFadeDuration), value: didTapWeiter)
                }
                .padding(.top, 250)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .offset(y: isExiting ? -500 : 0)
                .opacity(isExiting ? 0 : 1)
                .opacity(didTapWeiter ? 1 : 0)
                .animation(.easeInOut(duration: exitDuration), value: isExiting)
                .animation(.easeInOut(duration: introTextFadeDuration), value: didTapWeiter)
                if didTapWeiter {

                }
                else {
                    Spacer()
                }
                /*
                    Group {
                        if showUpdateText && !didTapWeiter {
                            Text("Update abgeschlossen")
                                .font(.title3.weight(.semibold))
                        } else {
                            Color.clear
                        }
                    }
                    .frame(height: 30)
                    .padding(.top, 20)
                    .offset(y: isExiting ? 500 : 0)
                    .animation(.easeInOut(duration: exitDuration), value: isExiting)
                    .opacity(isExiting ? 0 : 1)
                */
                Button(didTapWeiter ? "Fortfahren" : "Weiter") {
                    if didTapWeiter {
                        withAnimation(.easeInOut(duration: stageTransitionDuration)) {
                            backgroundMotionProgress = 1.102
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
                .animation(.easeInOut(duration: introTextFadeDuration), value: didTapWeiter)
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

            revealIntroContent()

            scheduleInactivityTimer()
        }
        .onDisappear {
            inactivityWorkItem?.cancel()
        }
    }

    private func revealIntroContent() {
        guard !didTapWeiter, !isExiting else { return }

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
            backgroundMotionProgress = 0.04
            backgroundWobbleIntensity = 0.70
        }
        withAnimation(.easeOut(duration: stageTransitionDuration)) {
            backgroundWobbleIntensity = 0.22
        }
    }

    private func startExitFlow() {
        guard !isExiting else { return }
        isExiting = true
        inactivityWorkItem?.cancel()

        // Phase 3: Content fährt nach oben und blendet aus.
        withAnimation(.easeInOut(duration: exitDuration)) {
            contentOffsetY = -520
            contentOpacity = 0.0
            showContinueButton = false
        }

        // Phase 3: Hintergrund bekommt finalen Impuls und blendet aus.
        withAnimation(.easeInOut(duration: 1.5)) {
            backgroundWobbleIntensity = 1.0
            backgroundMotionProgress = 1.8
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

private struct LaunchOpenSourceAnnouncement: View {
    let repositoryURL: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("BoxHelper ist jetzt Open Source!")
                    .font(.title2.weight(.bold))

                Text("Der Code ist unter der GNU AGPLv3 auf GitHub veröffentlicht.")
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                Text("Dir fehlt eine Funktion? Erstelle ein Issue auf GitHub oder entwickle die Funktionen selbst und trage so zur Entwicklung der App bei. Du bestimmst die Zukunft von BoxHelper.❤️")
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.secondary)
            }

            Link(destination: repositoryURL) {
                HStack(spacing: 8) {
                    Image("GitHub_Invertocat_White")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)

                    Text("Repository öffnen")
                }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .modifier(LaunchAnnouncementCardStyle())
    }
}

private struct LaunchAnnouncementCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .frame(maxWidth: 800)
                .glassEffect(in: .rect(cornerRadius: 10.0))
        } else {
            content
                .background(.ultraThinMaterial)
                .frame(maxWidth: 800)
                .cornerRadius(10.0)
        }
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
                    let zoomBoost = 0.35 + motion * 0.95 // Verstärkt Zoomdynamik, je weiter die Animation fortgeschritten ist.
                    let scale = (4.9 + eased * 6.2 * zoomBoost) + exitProgress * 1.8 // Tatsächlicher Zoomfaktor inkl. zusätzlichem Exit-Push.
                    let blur = (6.0 + eased * 12.0 * zoomBoost) + exitProgress * 14.0 // Unschärfe nimmt beim "nach vorn kommen" und beim Exit zu.
                    let baseOpacity = (0.52 - eased * 0.28) + Double(index) * 0.02 // Grundsichtbarkeit pro Layer (mit leichter Layer-Staffelung).
                    let fadeIn = min(1.0, max(0.0, p / 0.22)) // Sanftes Einblenden am Anfang des Layer-Zyklus.
                    let fadeOut = min(1.0, max(0.0, (1.0 - p) / 0.28)) // Sanftes Ausblenden gegen Ende des Layer-Zyklus.
                    let opacity = baseOpacity * fadeIn * (fadeOut * fadeOut) * layerVisibility * (1.0 - exitProgress) // Finale Opazität inkl. globaler Sichtbarkeit und Exit-Fade.
                    let sway = sin((progress + Double(index) * 0.9) * .pi * 2.0) // Seitliches/rotatorisches "Taumeln" je Layer.
                    let rotation = (Double(index) * 24.0) + motion * 115.0 + sway * (16.0 * wobble) + eased * (3.0 * wobble) // Endrotation: Basiswinkel + Taumeln + leichter Vorwärtsdrall.
                    let hue = (Double(index) * 120.0) + eased * 105.0 + motion * 20.0 - 10.0 // Farbverschiebung pro Layer über Zeit/Phase.

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

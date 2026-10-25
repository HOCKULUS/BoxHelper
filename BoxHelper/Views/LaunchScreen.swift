
//
//  LauchScreen.swift
//  BoxHelper
//
//  Created by HOCKULUS on 14.03.25.
//

import SwiftUI

struct LaunchScreen: View {
    @State private var closeEnabledAt: Double?
    @State private var closeUnlockID = UUID()
    @State private var showLogo = false
    @State private var showContinueButton = false
    @State private var isExiting = false
    @State private var didTapWeiter = false
    @State private var showIntroVisuals = false
    @Binding var isActive : Bool
    var presentation: LaunchPresentationPolicy.Presentation = .initial
    private let introRevealDuration: TimeInterval = 1.5
    private let introTextFadeDuration: TimeInterval = 1.5
    private let stageTransitionDuration: TimeInterval = 1.5
    private let exitDuration: TimeInterval = 1.5
    private let skyColor = Color(red: 0.53, green: 0.78, blue: 0.96)

    // Human readable app version shown in the update stage.
    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        //let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(version)"
    }

    var body: some View {
        ZStack {
            // Ein heller Himmel bleibt auch nach dem Abbremsen hinter den Wolken.
            skyColor
            LaunchLoopingBackground(
                isVisible: showIntroVisuals,
                isStopping: didTapWeiter,
                isExiting: isExiting,
                revealDuration: introRevealDuration
            )
            LaunchSkyOverlay(backgroundColor: skyColor)

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
                        .overlay(alignment: .bottom) {
                            // Das Overlay belegt keinen Platz im Stack: Logo, Titel
                            // und Weiter-Taste behalten ihre bisherigen Positionen.
                            LaunchCloudFeatureBadge()
                                .alignmentGuide(.bottom) { dimensions in
                                    dimensions[.top] - 16
                                }
                                .opacity(showLogo && !didTapWeiter && !isExiting ? 1 : 0)
                                .animation(.easeInOut(duration: introRevealDuration), value: showLogo)
                                .animation(.easeOut(duration: 0.2), value: didTapWeiter)
                                .accessibilityHidden(!showLogo || didTapWeiter || isExiting)
                                .allowsHitTesting(false)
                        }
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
                        LazyVStack(alignment: .leading, spacing: 20) {
                            LaunchSupportCard()
                            LaunchUpdateHighlights()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    // Die Scrollfläche hat exakt dieselbe Breite und Rundung wie ihre Karten.
                    .frame(maxWidth: LaunchLayout.maximumContentWidth)
                    .clipShape(LaunchLayout.cardShape)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
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
                if !didTapWeiter {
                    Spacer()
                }
                Button(didTapWeiter ? "Fortfahren" : "Weiter") {
                    if didTapWeiter {
                        startExitFlow()
                    } else {
                        advanceToUpdateStage()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.top, 20)
                .padding(.bottom, 40)
                .opacity(showContinueButton && (!didTapWeiter || closeEnabledAt != nil) ? 1 : 0)
                // Beim Phasenwechsel sofort verbergen; erst nach der Lesefrist einblenden.
                .animation(nil, value: didTapWeiter)
                .animation(.easeInOut(duration: introTextFadeDuration), value: showContinueButton)
                .disabled(!showContinueButton || isExiting || (didTapWeiter && closeEnabledAt == nil))
                .accessibilityHidden(didTapWeiter && closeEnabledAt == nil)
                .animation(.easeInOut(duration: 0.2), value: closeEnabledAt)
                .offset(y: isExiting ? 500 : 0)
                .animation(.easeInOut(duration: exitDuration), value: isExiting)
                .animation(.easeInOut(duration: introTextFadeDuration), value: didTapWeiter)
                .opacity(isExiting ? 0 : 1)
            }
        }
        .frame(alignment: .center)
        .ignoresSafeArea(.all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Dunkle Schrift und helle Karten bleiben auf dem blauen Himmel gut lesbar.
        .environment(\.colorScheme, .light)
        // Der LaunchScreen verwendet unabhängig von der App-Einstellung Systemblau.
        .tint(.blue)
        .accentColor(.blue)
        .onAppear {
            // Reset: Beim erneuten Anzeigen immer wieder bei Phase 1 starten.
            closeEnabledAt = nil
            showLogo = false
            showContinueButton = false
            showIntroVisuals = false
            didTapWeiter = false
            isExiting = false

            revealIntroContent()
        }
        .interactiveDismissDisabled(true)
        .accessibilityAction(.escape) {
            if didTapWeiter { startExitFlow() }
        }
        .task(id: closeUnlockID) {
            guard didTapWeiter else { return }
            do {
                // Nur Fortfahren schließt. Die Lesefrist startet mit der Übersicht,
                // nicht schon während des vertrauten Logo-Intros.
                try await Task.sleep(for: .seconds(presentation.closeDelay))
                try Task.checkCancellation()
                withAnimation(.easeInOut(duration: 0.2)) {
                    closeEnabledAt = ProcessInfo.processInfo.systemUptime
                }
            } catch { /* Ein entfernter Bildschirm gibt keine Schließtaste mehr frei. */ }
        }
        .task(id: isExiting) {
            guard isExiting else { return }
            do {
                try await Task.sleep(for: .seconds(exitDuration))
                try Task.checkCancellation()
                isActive = false
            } catch { /* Beim Verlassen kein verspäteter Wechsel zur App. */ }
        }
    }

    private func revealIntroContent() {
        guard !didTapWeiter, !isExiting else { return }

        withAnimation(.easeInOut(duration: stageTransitionDuration)) {
            showIntroVisuals = true
            showLogo = true
            showContinueButton = true
        }
    }

    private func advanceToUpdateStage() {
        guard !didTapWeiter, !isExiting else { return }
        didTapWeiter = true
        closeEnabledAt = nil
        closeUnlockID = UUID()
        withAnimation(.easeInOut(duration: stageTransitionDuration)) {
            showContinueButton = true
        }
    }

    private func startExitFlow() {
        guard !isExiting, closeEnabledAt != nil else { return }
        LaunchPresentationPolicy.complete(presentation)
        isExiting = true

        // Phase 3: Content fährt nach oben und blendet aus.
        withAnimation(.easeInOut(duration: exitDuration)) {
            showContinueButton = false
        }
    }

}


#Preview { LaunchScreen(isActive: .constant(true)) }

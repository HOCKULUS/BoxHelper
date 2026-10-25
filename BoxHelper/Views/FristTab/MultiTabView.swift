//
//  TabView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 02.04.25.
//

import SwiftUI
import UIKit
import TipKit

struct MutiTabView: View {
    @Binding var selectedOption: String
    @State private var backgroundColor: Color = Color.clear  // Neue State-Variable für die Hintergrundfarbe
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @Environment(\.colorScheme) var colorScheme
    @State var searchText: String = Self.initialSearchText()
    @State private var loadLastSearch: Bool = UserDefaults.standard.object(forKey: "loadLastSearch") == nil ? true : UserDefaults.standard.bool(forKey: "loadLastSearch")
    @AppStorage("alwaysShowNavBar") private var alwaysShowNavBar: Bool = true
    @AppStorage("navBarPosition") private var navBarPosition: String = "Top"
    @AppStorage("enableFirstTabSwipeNavigation") private var enableFirstTabSwipeNavigation: Bool = true
    @AppStorage("firstTabSwipeAnimationStyle") private var firstTabSwipeAnimationStyle: String = SwipeAnimationStyle.slide.rawValue
    @AppStorage("firstTabSwipeAnimationDuration") private var firstTabSwipeAnimationDuration: Double = 0.2
    @AppStorage("firstTabSwipeSensitivity") private var firstTabSwipeSensitivity: String = "normal"
    @State private var swipeDirection: SwipeDirection = .left
    @State private var displayedOption: String = "boxes"
    @State private var animateSwipeTransition: Bool = false
    @State private var isSelecting = false
    @State private var isScrolling = false
    @ObservedObject private var handoff = InventoryHandoffStore.shared
    @State private var isVisible = false
    @State private var lastAppliedSearchHandoff: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var didTriggerTabSwitchInCurrentDrag: Bool = false
    
    //@State var selectedOption : String = "boxes"
    @State var boxes_count = loadBoxes().count
    let addBackup = Backup()
    var body: some View {
        ZStack {
            if boxes_count > 5 {
                //TipView(addBackup)
            }
            firstTabView(for: displayedOption)
                .transition(tabTransition)
                .onChange(of: searchText, initial: true) { _, newValue in
                loadLastSearch = UserDefaults.standard.object(forKey: "loadLastSearch") == nil ? true : UserDefaults.standard.bool(forKey: "loadLastSearch")
                if loadLastSearch {
                    UserDefaults.standard.set(newValue, forKey: "searchText")
                } else {
                    UserDefaults.standard.removeObject(forKey: "searchText")
                }
                publishSearchHandoff()
            }
                .onAppear {
                if !loadLastSearch {
                    UserDefaults.standard.removeObject(forKey: "searchText")
                }
                selectedColor = UserDefaultsManager.loadAccentColor()
            }
        }
        // Alle vier Listen melden ihren Bearbeitungsmodus über denselben PreferenceKey.
        .inventoryCloudToolbar(isVisible: !isSelecting)
        .modifier(FirstTabPickerLayout(
            selection: tabSelectionBinding,
            isVisible: alwaysShowNavBar,
            position: navBarPosition,
            isSelecting: isSelecting
        ))
        .simultaneousGesture(
            DragGesture(minimumDistance: firstTabSwipeMinimumDistance)
                .onChanged { value in
                    guard !isSelecting, !isScrolling else { return }
                    guard enableFirstTabSwipeNavigation else { return }
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }

                    let translation = boundedDragOffset(value.translation.width)
                    dragOffset = translation
                    print("Dragging: \(dragOffset)")

                    // Sofort blättern, sobald die Trigger-Distanz erreicht wurde.
                    guard !didTriggerTabSwitchInCurrentDrag else { return }
                    guard abs(translation) >= firstTabSwipeMinimumDistance else { return }

                    if translation < 0 {
                        print("Immediate trigger left")
                        switchToAdjacentTab(step: 1)
                    } else if translation > 0 {
                        print("Immediate trigger right")
                        switchToAdjacentTab(step: -1)
                    }
                    didTriggerTabSwitchInCurrentDrag = true
                    dragOffset = 0
                }
                .onEnded { value in
                    defer { didTriggerTabSwitchInCurrentDrag = false }
                    guard !isSelecting, !isScrolling else { return }
                    guard enableFirstTabSwipeNavigation else { return }
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    guard !didTriggerTabSwitchInCurrentDrag else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = 0
                        }
                        return
                    }
                    let translation = boundedDragOffset(value.translation.width)

                    if abs(translation) >= firstTabSwipeMinimumDistance {
                        if translation < 0 {
                            print("Trigger left")
                            switchToAdjacentTab(step: 1)
                        } else if translation > 0 {
                            print("Trigger right")
                            switchToAdjacentTab(step: -1)
                        }
                    }

                    withAnimation(.easeOut(duration: 0.25)) {
                        dragOffset = 0
                    }

                    print("Drag ended, reset offset")
                }
        )
        .onPreferenceChange(FirstTabSelectionActiveKey.self) { isSelecting = $0 }
        .contentShape(Rectangle())
        .onAppear {
            displayedOption = selectedOption
            isVisible = true
            applySearchHandoff()
            publishSearchHandoff()
        }
        .onDisappear {
            isVisible = false
            handoff.deactivateSearch()
        }
        .onChange(of: handoff.incomingSearch?.id, initial: true) { _, _ in applySearchHandoff() }
        .onChange(of: displayedOption) { _, _ in publishSearchHandoff() }
        .onChange(of: selectedOption, initial: false) { _, newValue in
            // External tab changes (e.g. quick actions) should not animate.
            guard !animateSwipeTransition else { return }
            displayedOption = newValue
        }
    }

    private enum SwipeDirection {
        case left
        case right
    }

    private static func initialSearchText() -> String {
        let defaults = UserDefaults.standard
        let remember = defaults.object(forKey: "loadLastSearch") == nil || defaults.bool(forKey: "loadLastSearch")
        return remember ? defaults.string(forKey: "searchText") ?? "" : ""
    }

    /// Suchtext und Liste gehören zur selben Tätigkeit, auch beim Wechsel per Wischgeste.
    private func publishSearchHandoff() {
        guard isVisible else { return }
        handoff.updateSearch(query: searchText, tab: displayedOption)
    }

    private func applySearchHandoff() {
        guard let request = handoff.incomingSearch, request.id != lastAppliedSearchHandoff else { return }
        lastAppliedSearchHandoff = request.id
        animateSwipeTransition = false
        selectedOption = request.tab
        displayedOption = request.tab
        searchText = request.query
        Task { @MainActor in
            await Task.yield()
            handoff.consumeSearchRequest(request.id)
        }
    }

    // Stores all selectable swipe animations and maps cleanly to UserDefaults raw values.
    private enum SwipeAnimationStyle: String, CaseIterable {
        case none
        case slide
        case fade
        case zoom
        case push
        case cube3D
        case flip3D
    }

    private var firstTabOrder: [String] {
        ["boxes", "items", "locations", "images"]
    }

    private var tabSelectionBinding: Binding<String> {
        Binding(
            get: { selectedOption },
            set: { newValue in
                // Picker-based switching should be immediate, without transition animation.
                animateSwipeTransition = false
                selectedOption = newValue
                displayedOption = newValue
            }
        )
    }

    private var tabTransition: AnyTransition {
        guard animateSwipeTransition else { return .identity }
        let style = SwipeAnimationStyle(rawValue: firstTabSwipeAnimationStyle) ?? .slide

        switch style {
        case .none:
            return .identity
        case .slide:
            return .asymmetric(
                insertion: .move(edge: swipeDirection == .left ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: swipeDirection == .left ? .leading : .trailing).combined(with: .opacity)
            )
        case .fade:
            return .opacity
        case .zoom:
            return .asymmetric(
                insertion: .scale(scale: 0.92).combined(with: .opacity),
                removal: .scale(scale: 1.08).combined(with: .opacity)
            )
        case .push:
            return .asymmetric(
                insertion: .offset(x: swipeDirection == .left ? 120 : -120).combined(with: .opacity),
                removal: .offset(x: swipeDirection == .left ? -120 : 120).combined(with: .opacity)
            )
        case .cube3D:
            return .asymmetric(
                insertion: .modifier(
                    active: CubeRotateTransitionModifier(
                        angle: swipeDirection == .left ? 75 : -75,
                        xOffset: swipeDirection == .left ? 120 : -120
                    ),
                    identity: CubeRotateTransitionModifier(angle: 0, xOffset: 0)
                ),
                removal: .modifier(
                    active: CubeRotateTransitionModifier(
                        angle: swipeDirection == .left ? -75 : 75,
                        xOffset: swipeDirection == .left ? -120 : 120
                    ),
                    identity: CubeRotateTransitionModifier(angle: 0, xOffset: 0)
                )
            )
        case .flip3D:
            return .asymmetric(
                insertion: .modifier(
                    active: FlipTransitionModifier(
                        angle: swipeDirection == .left ? -95 : 95,
                        xOffset: swipeDirection == .left ? 90 : -90
                    ),
                    identity: FlipTransitionModifier(angle: 0, xOffset: 0)
                ),
                removal: .modifier(
                    active: FlipTransitionModifier(
                        angle: swipeDirection == .left ? 95 : -95,
                        xOffset: swipeDirection == .left ? -90 : 90
                    ),
                    identity: FlipTransitionModifier(angle: 0, xOffset: 0)
                )
            )
        }
    }

    // Keeps swipe duration configurable while preventing out-of-range persisted values.
    private var clampedSwipeDuration: Double {
        min(max(firstTabSwipeAnimationDuration, 0.2), 10)
    }

    private var firstTabSwipeMinimumDistance: CGFloat {
        // User-configurable swipe sensitivity for first-tab navigation.
        switch firstTabSwipeSensitivity {
        case "ultraHigh":
            return 2
        case "veryHigh":
            return 25
        case "high":
            return 50
        case "low":
            return 150
        case "veryLow":
            return 200
        default:
            return 100
        }
    }

    private func switchToAdjacentTab(step: Int) {
        guard let currentIndex = firstTabOrder.firstIndex(of: displayedOption) else { return }
        let newIndex = currentIndex + step
        guard firstTabOrder.indices.contains(newIndex) else { return }
        let newOption = firstTabOrder[newIndex]
        updateSwipeDirection(from: displayedOption, to: newOption)
        let style = SwipeAnimationStyle(rawValue: firstTabSwipeAnimationStyle) ?? .slide

        // "None" disables transition and timing completely.
        if style == .none {
            animateSwipeTransition = false
            selectedOption = newOption
            displayedOption = newOption
            return
        }

        let duration = clampedSwipeDuration
        animateSwipeTransition = true
        selectedOption = newOption
        withAnimation(.easeInOut(duration: duration)) {
            displayedOption = newOption
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.02) {
            animateSwipeTransition = false
        }
    }

    private func updateSwipeDirection(from oldValue: String, to newValue: String) {
        guard let oldIndex = firstTabOrder.firstIndex(of: oldValue),
              let newIndex = firstTabOrder.firstIndex(of: newValue) else {
            return
        }
        swipeDirection = newIndex >= oldIndex ? .left : .right
    }

    private func boundedDragOffset(_ proposedOffset: CGFloat) -> CGFloat {
        // Prevents dragging further when already at the first/last tab.
        if proposedOffset > 0 && displayedOption == "boxes" {
            return 0
        }
        if proposedOffset < 0 && displayedOption == "images" {
            return 0
        }
        return proposedOffset
    }

    @ViewBuilder
    private func firstTabView(for option: String) -> some View {
        switch option {
        case "items":
            ItemsView(searchText: $searchText, isScrolling: $isScrolling, selectedOption: $selectedOption)
        case "locations":
            LocationsView(searchText: $searchText, isScrolling: $isScrolling, selectedOption: $selectedOption)
        case "images":
            ImagesView(searchText: $searchText, isScrolling: $isScrolling, selectedOption: $selectedOption)
        default:
            BoxView(searchText: $searchText, isScrolling: $isScrolling, selectedOption: $selectedOption)
        }
    }
}

private struct CubeRotateTransitionModifier: ViewModifier {
    let angle: Double
    let xOffset: CGFloat

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.85)
            .offset(x: xOffset)
            .opacity(1 - min(abs(angle) / 100.0, 0.9))
    }
}

private struct FlipTransitionModifier: ViewModifier {
    let angle: Double
    let xOffset: CGFloat

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 1, z: 0), perspective: 0.9)
            .offset(x: xOffset)
            .opacity(1 - min(abs(angle) / 120.0, 0.85))
    }
}

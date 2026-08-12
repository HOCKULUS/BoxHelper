//
//  TabView.swift
//  BoxHelper
//
//  Created by HOCKULUS on 02.04.25.
//

import SwiftUI
import UIKit
import StoreKit
import TipKit

struct MutiTabView: View {
    @Binding var selectedOption: String
    @State private var backgroundColor: Color = Color.clear  // Neue State-Variable für die Hintergrundfarbe
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @Environment(\.colorScheme) var colorScheme
    @State var searchText: String = (UserDefaults.standard.string(forKey: "searchText") ?? "")
    @State private var loadLastSearch: Bool = UserDefaults.standard.object(forKey: "loadLastSearch") == nil ? true : UserDefaults.standard.bool(forKey: "loadLastSearch")
    @Environment(\.requestReview) var requestReview
    @State private var alwaysShowNavBar: Bool = UserDefaults.standard.object(forKey: "alwaysShowNavBar") == nil ? true : UserDefaults.standard.bool(forKey: "alwaysShowNavBar")
    @State private var navBarPosition: String = UserDefaults.standard.string(forKey: "navBarPosition") ?? "Top"
    @AppStorage("enableFirstTabSwipeNavigation") private var enableFirstTabSwipeNavigation: Bool = true
    @AppStorage("firstTabSwipeAnimationStyle") private var firstTabSwipeAnimationStyle: String = SwipeAnimationStyle.slide.rawValue
    @AppStorage("firstTabSwipeAnimationDuration") private var firstTabSwipeAnimationDuration: Double = 0.2
    @AppStorage("firstTabSwipeSensitivity") private var firstTabSwipeSensitivity: String = "normal"
    @State private var swipeDirection: SwipeDirection = .left
    @State private var displayedOption: String = "boxes"
    @State private var animateSwipeTransition: Bool = false
    @State private var isScrolling = false
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
            }
                .onAppear {
                if !loadLastSearch {
                    UserDefaults.standard.removeObject(forKey: "searchText")
                    searchText = ""
                }
                selectedColor = UserDefaultsManager.loadAccentColor()
            }
            

            if alwaysShowNavBar && navBarPosition == "Left" {
                VStack {
                    Spacer()
                    HStack {
                        listPicker(selection: tabSelectionBinding)
                            .rotationEffect(.degrees(90))
                            .frame(width: 150, height: 40)
                            .offset(x: -70)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 5)
                .zIndex(100)
            }

            if alwaysShowNavBar && navBarPosition == "Right" {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        listPicker(selection: tabSelectionBinding)
                            .rotationEffect(.degrees(90))
                            .frame(width: 150, height: 40)
                            .offset(x: 70)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 5)
                .zIndex(100)
            }

            if alwaysShowNavBar && navBarPosition == "Top" {
                if #available(iOS 26.0, *) {
                    VStack {
                        listPicker(selection: tabSelectionBinding)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .zIndex(100)
                }
                else {
                    VStack {
                        listPicker(selection: tabSelectionBinding)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 50)
                    .zIndex(100)
                }
            }

            if alwaysShowNavBar && navBarPosition == "Bottom" {
                VStack {
                    Spacer()
                    listPicker(selection: tabSelectionBinding)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 5)
                .zIndex(100)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: firstTabSwipeMinimumDistance)
                .onChanged { value in
                    guard !isScrolling else { return }
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
                    guard !isScrolling else { return }
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
        .contentShape(Rectangle())
        .onAppear {
            alwaysShowNavBar = UserDefaults.standard.object(forKey: "alwaysShowNavBar") == nil ? true : UserDefaults.standard.bool(forKey: "alwaysShowNavBar")
            navBarPosition = UserDefaults.standard.string(forKey: "navBarPosition") ?? "Top"
            displayedOption = selectedOption
        }
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
            ItemsView(showLocalListPicker: false, searchText: $searchText, isScrolling: $isScrolling, selectedOption: $selectedOption)
        case "locations":
            LocationsView(showLocalListPicker: false, searchText: $searchText, isScrolling: $isScrolling, selectedOption: $selectedOption)
        case "images":
            ImagesView(showLocalListPicker: false, searchText: $searchText, isScrolling: $isScrolling, selectedOption: $selectedOption)
        default:
            BoxView(showLocalListPicker: false, searchText: $searchText, isScrolling: $isScrolling, selectedOption: $selectedOption)
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

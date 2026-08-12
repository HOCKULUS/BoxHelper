//
//  SettingsInteractionAppearanceView.swift
//  BoxHelper
//

import SwiftUI
import UIKit
import StoreKit

struct SettingsInteractionAppearanceView: View {
    private static let firstTabSwipeAnimationDurationKey = "firstTabSwipeAnimationDuration"
    private static let supportedFirstTabSwipeAnimationDurations: [Double] = [0.2, 0.4, 0.6]
    private static let defaultFirstTabSwipeAnimationDuration = 0.2

    var iconBackgroundColor: Color
    let availableColors: [Color] = [
        .customNeonPink,
        .customCoral,
        .orange,
        .yellow,
        .customMint,
        .green,
        .customGreen,
        .customBlueGreen,
        .teal,
        .blue,
        .indigo,
        .customLavender,
        .brown,
        .gray,
        .customGray
    ]

    @EnvironmentObject var accentColorManager: AccentColorManager
    @Environment(\.colorScheme) var colorScheme
    @State private var loadPressAndHold: Bool = UserDefaultsManager.shared.loadPressAndHold()
    @State private var pageOnLauch: String = UserDefaultsManager.shared.loadPageOnLauch()
    @State private var loadLastSearch: Bool = UserDefaults.standard.object(forKey: "loadLastSearch") == nil ? true : UserDefaults.standard.bool(forKey: "loadLastSearch")
    @State private var suggestions: Bool = UserDefaults.standard.object(forKey: "suggestions") == nil ? true : UserDefaults.standard.bool(forKey: "suggestions")
    @State private var deepNavigation: Bool = UserDefaults.standard.object(forKey: "deepNavigation") == nil ? true : UserDefaults.standard.bool(forKey: "deepNavigation")
    @State private var showDetails: Bool = UserDefaults.standard.object(forKey: "showDetails") == nil ? true : UserDefaults.standard.bool(forKey: "showDetails")
    @State private var showDetailsDate1: Bool = UserDefaults.standard.object(forKey: "showDetailsDate1") == nil ? false : UserDefaults.standard.bool(forKey: "showDetailsDate1")
    @State private var showDetailsDate2: Bool = UserDefaults.standard.object(forKey: "showDetailsDate2") == nil ? false : UserDefaults.standard.bool(forKey: "showDetailsDate2")
    @State private var showDetailsItemsCounter: Bool = UserDefaults.standard.object(forKey: "showDetailsItemsCounter") == nil ? true : UserDefaults.standard.bool(forKey: "showDetailsItemsCounter")
    @State private var showDetailsTagCounter: Bool = UserDefaults.standard.object(forKey: "showDetailsTagCounter") == nil ? true : UserDefaults.standard.bool(forKey: "showDetailsTagCounter")
    @State private var showDetailsImagesCounter: Bool = UserDefaults.standard.object(forKey: "showDetailsImagesCounter") == nil ? true : UserDefaults.standard.bool(forKey: "showDetailsImagesCounter")
    @State private var showDetailsLocation: Bool = UserDefaults.standard.object(forKey: "showDetailsLocation") == nil ? true : UserDefaults.standard.bool(forKey: "showDetailsLocation")
    @State private var showTags: Bool = UserDefaults.standard.object(forKey: "showTags") == nil ? true : UserDefaults.standard.bool(forKey: "showTags")
    @State private var enableFirstTabSwipeNavigation: Bool = UserDefaults.standard.object(forKey: "enableFirstTabSwipeNavigation") == nil ? true : UserDefaults.standard.bool(forKey: "enableFirstTabSwipeNavigation")
    @State private var firstTabSwipeAnimationStyle: String = UserDefaults.standard.string(forKey: "firstTabSwipeAnimationStyle") ?? "slide"
    @State private var firstTabSwipeSensitivity: String = UserDefaults.standard.string(forKey: "firstTabSwipeSensitivity") ?? "normal"
    @State private var firstTabSwipeAnimationDuration: Double = Self.loadFirstTabSwipeAnimationDuration()
    @State private var searchSuggestions: [String] = UserDefaults.standard.stringArray(forKey: "searchSuggestions") ?? []
    @State private var searchSuggestionsItems: [String] = UserDefaults.standard.stringArray(forKey: "searchSuggestionsItems") ?? []
    @State private var searchSuggestionsLocations: [String] = UserDefaults.standard.stringArray(forKey: "searchSuggestionsLocations") ?? []
    @State private var numberofsearchSuggestions: Int = UserDefaults.standard.integer(forKey: "numberofsearchSuggestions") == 0 ? 5 : UserDefaults.standard.integer(forKey: "numberofsearchSuggestions")
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @State private var spotlightIndexingEnabled: Bool = isSpotlightIndexingEnabled()
    @State private var firstTabOnLaunchMode: String = UserDefaults.standard.string(forKey: "firstTabOnLaunchMode") ?? "remember"
    @State private var firstTabOnLaunchSelection: String = UserDefaults.standard.string(forKey: "firstTabOnLaunchSelection") ?? "boxes"

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(iconBackgroundColor)
                                .frame(width: 70, height: 70)

                            Image(systemName: "slider.horizontal.3")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 10)
                        Spacer()
                    }

                    Text("Bedienung & Darstellung")
                        .font(.system(size: 25, weight: .bold))

                    Text("Lege fest, wie sich die App verhält und passe ihre Darstellung an deine Bedürfnisse an.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 10)
                }
            }
            Section(header: Text("Search")) {
                Toggle("Remember last search", isOn: $loadLastSearch)
                    .onChange(of: loadLastSearch, initial: true) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "loadLastSearch")
                    }
                Toggle("Search suggestions", isOn: $suggestions)
                    .onChange(of: suggestions, initial: true) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "suggestions")
                    }
                if suggestions {
                    Picker("Number of search suggestions:", selection: $numberofsearchSuggestions) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("3").tag(3)
                        Text("4").tag(4)
                        Text("5").tag(5)
                        Text("10").tag(10)
                        Text("15").tag(15)
                        Text("20").tag(20)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: numberofsearchSuggestions, initial: false) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "numberofsearchSuggestions")
                    }
                    HStack {
                        Text("Suggestions:")
                        Spacer()
                        Text("\(searchSuggestions.count + searchSuggestionsItems.count + searchSuggestionsLocations.count)")
                    }
                    Button {
                        searchSuggestions = []
                        searchSuggestionsItems = []
                        searchSuggestionsLocations = []
                        UserDefaults.standard.set([], forKey: "searchSuggestions")
                        UserDefaults.standard.set([], forKey: "searchSuggestionsItems")
                        UserDefaults.standard.set([], forKey: "searchSuggestionsLocations")
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash.fill")
                                .foregroundColor(searchSuggestions.isEmpty && searchSuggestionsItems.isEmpty && searchSuggestionsLocations.isEmpty ? .gray : .red)
                            Text("Delete suggestions")
                                .foregroundColor(searchSuggestions.isEmpty && searchSuggestionsItems.isEmpty && searchSuggestionsLocations.isEmpty ? .gray : .red)
                            Spacer()
                        }
                    }
                    .disabled(searchSuggestions.isEmpty && searchSuggestionsItems.isEmpty && searchSuggestionsLocations.isEmpty)
                }
            }
            Section(
                header: Text("System"),
                footer: Text("If enabled, box, item and location names are indexed in iOS Spotlight search.")
            ) {
                Toggle("System Search (Spotlight)", isOn: $spotlightIndexingEnabled)
                    .onChange(of: spotlightIndexingEnabled, initial: false) { _, newValue in
                        setSpotlightIndexingEnabled(newValue)
                    }
            }
            Section(header: Text("Page on launch"), footer: Text("Change here the first page you see when you open the app.")) {
                Picker("Page on launch", selection: $pageOnLauch) {
                    Text("Last visited").tag("Last")
                    Text("List View").tag("Boxes")
                    Text("TabView.Label.Create").tag("Create")
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: pageOnLauch, initial: false) { _, newValue in
                    UserDefaultsManager.shared.savePageOnLauch(newValue)
                }
            }
            Section(
                header: Text("List View Tab on launch"),
                footer: Text("Change here the first tab you see on the list view when you open the app.")
            ) {
                Picker("", selection: $firstTabOnLaunchMode) {
                    Label("Last visited", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90").tag("remember")
                    Label("Eigenen", systemImage: "slider.horizontal.3").tag("fixed")
                }
                .pickerStyle(.segmented)
                .onChange(of: firstTabOnLaunchMode, initial: false) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "firstTabOnLaunchMode")
                }

                if firstTabOnLaunchMode == "fixed" {
                    Picker("Start-Tab", selection: $firstTabOnLaunchSelection) {
                        Label("Boxes", systemImage: "shippingbox.fill").tag("boxes")
                        Label("Items", systemImage: "square.grid.2x2.fill").tag("items")
                        Label("Locations", systemImage: "location.fill").tag("locations")
                        Label("Images", systemImage: "photo.stack.fill").tag("images")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: firstTabOnLaunchSelection, initial: false) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "firstTabOnLaunchSelection")
                    }
                }
            }
            Section(header: Text("Input Behavior")) {
                if #available(iOS 18, *) {
                    Toggle("Enable Long-Press to Edit", isOn: $loadPressAndHold)
                        .onChange(of: loadPressAndHold, initial: true) { _, newValue in
                            UserDefaultsManager.shared.savePressAndHold(newValue)
                        }
                } else {
                    Toggle("Enable Long-Press to Edit", isOn: $loadPressAndHold)
                        .onChange(of: loadPressAndHold, initial: false) { _, newValue in
                            UserDefaultsManager.shared.savePressAndHold(newValue)
                        }
                        .disabled(true)
                }
            }
            Section(header: Text("Subviews"), footer: Text("Enabling this allows navigation into deeper subviews, which could potentially be confusing.")) {
                Toggle("Enable Subviewnavigation", isOn: $deepNavigation)
                    .onChange(of: deepNavigation, initial: true) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "deepNavigation")
                    }
            }
            Section(header: Text("List View Navigation")) {
                Toggle("Swipe between tabs", isOn: $enableFirstTabSwipeNavigation)
                    .onChange(of: enableFirstTabSwipeNavigation, initial: true) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "enableFirstTabSwipeNavigation")
                    }
                if enableFirstTabSwipeNavigation {
                    Picker("Empfindlichkeit", selection: $firstTabSwipeSensitivity) {
                        Text("Ultra hoch").tag("ultraHigh")
                        Text("Sehr hoch").tag("veryHigh")
                        Text("Hoch").tag("high")
                        Text("Normal").tag("normal")
                        Text("Niedrig").tag("low")
                        Text("Sehr niedrig").tag("veryLow")
                    }
                    .pickerStyle(.menu)
                    .disabled(!enableFirstTabSwipeNavigation)
                    .onChange(of: firstTabSwipeSensitivity, initial: true) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "firstTabSwipeSensitivity")
                    }
                    
                    Picker("Animation", selection: $firstTabSwipeAnimationStyle) {
                        Text("None").tag("none")
                        Text("Slide").tag("slide")
                        Text("Fade").tag("fade")
                        //Text("Zoom").tag("zoom")
                        //Text("Push").tag("push")
                        //Text("Cube 3D").tag("cube3D")
                    }
                    .pickerStyle(.menu)
                    .disabled(!enableFirstTabSwipeNavigation)
                    .onChange(of: firstTabSwipeAnimationStyle, initial: true) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "firstTabSwipeAnimationStyle")
                    }
                    
                    HStack {
                        Text("Duration")
                        Spacer()
                        Picker("", selection: $firstTabSwipeAnimationDuration) {
                            Text("0.2s").tag(0.2)
                            Text("0.4s").tag(0.4)
                            Text("0.6s").tag(0.6)
                        }
                        .pickerStyle(.menu)
                        .disabled(!enableFirstTabSwipeNavigation || firstTabSwipeAnimationStyle == "none")
                        .onChange(of: firstTabSwipeAnimationDuration, initial: false) { oldValue, newValue in
                            print("Picker changed from \(oldValue) to \(newValue)")
                            
                            let clamped = Self.normalizedFirstTabSwipeAnimationDuration(newValue)
                            print("Clamped value: \(clamped)")
                            
                            if clamped != newValue {
                                print("Value adjusted to clamped range")
                            }
                            
                            firstTabSwipeAnimationDuration = clamped
                            UserDefaults.standard.set(clamped, forKey: Self.firstTabSwipeAnimationDurationKey)
                            print("Saved to UserDefaults: firstTabSwipeAnimationDuration = \(clamped)")
                        }
                        /*Text(firstTabSwipeAnimationStyle == "none" ? "0 ms" : String(format: "%.1f s", firstTabSwipeAnimationDuration))
                         .foregroundStyle(.secondary)*/
                    }
                    //.listRowSeparator(Visibility.hidden)
                    /*
                     Slider(value: $firstTabSwipeAnimationDuration, in: 0.2...0.6, step: 0.2)
                     .disabled(!enableFirstTabSwipeNavigation || firstTabSwipeAnimationStyle == "none")
                     .onChange(of: firstTabSwipeAnimationDuration, initial: false) { _, newValue in
                     let clamped = min(max(newValue, 0.2), 10)
                     firstTabSwipeAnimationDuration = clamped
                     UserDefaults.standard.set(clamped, forKey: "firstTabSwipeAnimationDuration")
                     }
                     */
                }
            }
            // Centralized list display settings used by the first tabs.
            Section(header: Text("Listenansicht")) {
                HStack {
                    Text("Settings.showDetails")
                    Spacer()
                    Toggle("", isOn: $showDetails)
                        .onChange(of: showDetails, initial: false) { _, newValue in
                            UserDefaultsManager.shared.saveShowDetails(newValue)
                        }
                        .tint(accentColorManager.accentColor)
                }
                if showDetails {
                    HStack {
                        Text("Settings.showDetailsLocation")
                        Spacer()
                        Toggle("", isOn: $showDetailsLocation)
                            .onChange(of: showDetailsLocation, initial: false) { _, newValue in
                                UserDefaultsManager.shared.saveShowDetailsLocation(newValue)
                            }
                            .tint(accentColorManager.accentColor)
                    }
                    HStack {
                        Text("Settings.showDetailsItemCounter")
                        Spacer()
                        Toggle("", isOn: $showDetailsItemsCounter)
                            .onChange(of: showDetailsItemsCounter, initial: false) { _, newValue in
                                UserDefaultsManager.shared.saveShowDetailsItemsCounter(newValue)
                            }
                            .tint(accentColorManager.accentColor)
                    }
                    if showTags {
                        HStack {
                            Text("Show Tag Counter")
                            Spacer()
                            Toggle("", isOn: $showDetailsTagCounter)
                                .onChange(of: showDetailsTagCounter, initial: false) { _, newValue in
                                    UserDefaultsManager.shared.saveShowDetailsTagCounter(newValue)
                                }
                                .tint(accentColorManager.accentColor)
                        }
                    }
                    HStack {
                        Text("Settings.showDetailsImagesCounter")
                        Spacer()
                        Toggle("", isOn: $showDetailsImagesCounter)
                            .onChange(of: showDetailsImagesCounter, initial: false) { _, newValue in
                                UserDefaultsManager.shared.saveShowDetailsImagesCounter(newValue)
                            }
                            .tint(accentColorManager.accentColor)
                    }
                    HStack {
                        Text("Settings.showDetailsDate1")
                        Spacer()
                        Toggle("", isOn: $showDetailsDate1)
                            .onChange(of: showDetailsDate1, initial: false) { _, newValue in
                                UserDefaultsManager.shared.saveShowDetailsDate1(newValue)
                            }
                            .tint(accentColorManager.accentColor)
                    }
                    HStack {
                        Text("Settings.showDetailsDate2")
                        Spacer()
                        Toggle("", isOn: $showDetailsDate2)
                            .onChange(of: showDetailsDate2, initial: false) { _, newValue in
                                UserDefaultsManager.shared.saveShowDetailsDate2(newValue)
                            }
                            .tint(accentColorManager.accentColor)
                    }
                }
            }

            if UIDevice.current.userInterfaceIdiom != .mac {
                Section(header: Text("Icon")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            Button(action: { changeIcon(to: "AppIcon") }) {
                                VStack {
                                    Image("AppLogoPreview")
                                        .resizable()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    Text("Default").font(.footnote).foregroundStyle(Color.primary)
                                }
                            }
                            Button(action: { changeIcon(to: "AppIconFirst") }) {
                                VStack {
                                    Image("AppLogoFirstPreview")
                                        .resizable()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    Text("1st").font(.footnote).foregroundStyle(Color.primary)
                                }
                            }
                            Button(action: { changeIcon(to: "AppIconSkeuomorph") }) {
                                VStack {
                                    Image("AppLogoSkeuomorphPreview")
                                        .resizable()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    Text("Classic").font(.footnote).foregroundStyle(Color.primary)
                                }
                            }
                            Button(action: { changeIcon(to: "AppIconPride") }) {
                                VStack {
                                    Image("AppLogoPridePreview")
                                        .resizable()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    Text("Pride").font(.footnote).foregroundStyle(Color.primary)
                                }
                            }
                            Button(action: { changeIcon(to: "AppIconReal") }) {
                                VStack {
                                    Image("AppLogoRealPreview")
                                        .resizable()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    Text("Realistic").font(.footnote).foregroundStyle(Color.primary)
                                }
                            }
                            Button(action: { changeIcon(to: "AppIconClassic") }) {
                                VStack {
                                    Image("AppLogoClassicPreview")
                                        .resizable()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    Text("3D").font(.footnote).foregroundStyle(Color.primary)
                                }
                            }
                        }
                    }
                    .cornerRadius(14)
                }
            }
            Section(header: Text("Color Scheme")) {
                VStack {
                    HStack {
                        Text("Change App Color:")
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(selectedColor)
                                .frame(width: 30, height: 30)
                            Image(systemName: "textformat")
                                .foregroundStyle(isColorTooDark(color: selectedColor) ? .white : .black)
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                                .labelsHidden()
                                .onChange(of: selectedColor) { _, newValue in
                                    UserDefaultsManager.saveAccentColor(newValue)
                                    selectedColor = newValue
                                    accentColorManager.updateAccentColor(to: newValue)
                                }
                                .scaleEffect(CGSize(width: 1.8, height: 1.8))
                                .padding(.horizontal, 13)
                            ForEach(availableColors, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: selectedColor == color ? 47 : 50, height: selectedColor == color ? 47 : 50)
                                    .overlay(
                                        Circle()
                                            .stroke(accentColorManager.accentColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                        UserDefaultsManager.saveAccentColor(color)
                                        accentColorManager.updateAccentColor(to: color)
                                    }
                            }
                        }
                        .frame(height: 50)
                    }
                    .cornerRadius(230)
                }
            }
        }
        .navigationTitle("Bedienung & Darstellung")
        .navigationBarTitleDisplayMode(.inline)
        .listSectionSpacing(8)
        .tint(accentColorManager.accentColor)
        .onAppear {
            numberofsearchSuggestions = UserDefaults.standard.integer(forKey: "numberofsearchSuggestions") == 0 ? 5 : UserDefaults.standard.integer(forKey: "numberofsearchSuggestions")
            pageOnLauch = UserDefaultsManager.shared.loadPageOnLauch()
            loadPressAndHold = UserDefaultsManager.shared.loadPressAndHold()
            showDetails = UserDefaults.standard.object(forKey: "showDetails") == nil ? true : UserDefaults.standard.bool(forKey: "showDetails")
            showDetailsDate1 = UserDefaults.standard.object(forKey: "showDetailsDate1") == nil ? false : UserDefaults.standard.bool(forKey: "showDetailsDate1")
            showDetailsDate2 = UserDefaults.standard.object(forKey: "showDetailsDate2") == nil ? false : UserDefaults.standard.bool(forKey: "showDetailsDate2")
            showDetailsItemsCounter = UserDefaults.standard.object(forKey: "showDetailsItemsCounter") == nil ? true : UserDefaults.standard.bool(forKey: "showDetailsItemsCounter")
            showDetailsTagCounter = UserDefaults.standard.object(forKey: "showDetailsTagCounter") == nil ? true : UserDefaults.standard.bool(forKey: "showDetailsTagCounter")
            showDetailsImagesCounter = UserDefaults.standard.object(forKey: "showDetailsImagesCounter") == nil ? true : UserDefaults.standard.bool(forKey: "showDetailsImagesCounter")
            showDetailsLocation = UserDefaults.standard.object(forKey: "showDetailsLocation") == nil ? true : UserDefaults.standard.bool(forKey: "showDetailsLocation")
            showTags = UserDefaults.standard.object(forKey: "showTags") == nil ? true : UserDefaults.standard.bool(forKey: "showTags")
            enableFirstTabSwipeNavigation = UserDefaults.standard.object(forKey: "enableFirstTabSwipeNavigation") == nil ? true : UserDefaults.standard.bool(forKey: "enableFirstTabSwipeNavigation")
            firstTabSwipeSensitivity = UserDefaults.standard.string(forKey: "firstTabSwipeSensitivity") ?? "normal"
            firstTabSwipeAnimationStyle = UserDefaults.standard.string(forKey: "firstTabSwipeAnimationStyle") ?? "slide"
            firstTabSwipeAnimationDuration = Self.loadFirstTabSwipeAnimationDuration()
            firstTabOnLaunchMode = UserDefaults.standard.string(forKey: "firstTabOnLaunchMode") ?? "remember"
            // Stellt sicher, dass nur bekannte FirstTabs in der UI angezeigt und gespeichert werden.
            let allowedTabs = ["boxes", "items", "locations", "images"]
            let loadedStartTab = UserDefaults.standard.string(forKey: "firstTabOnLaunchSelection") ?? "boxes"
            firstTabOnLaunchSelection = allowedTabs.contains(loadedStartTab) ? loadedStartTab : "boxes"
            searchSuggestions = UserDefaults.standard.stringArray(forKey: "searchSuggestions") ?? []
            searchSuggestionsItems = UserDefaults.standard.stringArray(forKey: "searchSuggestionsItems") ?? []
            searchSuggestionsLocations = UserDefaults.standard.stringArray(forKey: "searchSuggestionsLocations") ?? []
            selectedColor = accentColorManager.accentColor
        }
    }

    // Maps persisted values to the menu-supported durations so the picker always shows a valid selection.
    private static func loadFirstTabSwipeAnimationDuration() -> Double {
        guard let storedValue = UserDefaults.standard.object(forKey: firstTabSwipeAnimationDurationKey) as? Double else {
            return defaultFirstTabSwipeAnimationDuration
        }

        return normalizedFirstTabSwipeAnimationDuration(storedValue)
    }

    private static func normalizedFirstTabSwipeAnimationDuration(_ value: Double) -> Double {
        supportedFirstTabSwipeAnimationDurations.min(by: {
            abs($0 - value) < abs($1 - value)
        }) ?? defaultFirstTabSwipeAnimationDuration
    }

    func changeIcon(to iconName: String?) {
        guard UIApplication.shared.supportsAlternateIcons else {
            print("Dieses Gerät unterstützt keine alternativen Icons.")
            return
        }
        if iconName == "AppIcon" {
            UIApplication.shared.setAlternateIconName(nil)
        } else {
            UIApplication.shared.setAlternateIconName(iconName) { error in
                if let error = error {
                    print("Fehler beim Wechseln des Icons: \(error.localizedDescription)")
                } else {
                    print("Icon erfolgreich gewechselt!")
                }
            }
        }
    }
}

import SwiftUI
import CoreSpotlight
import UIKit
import StoreKit

extension Notification.Name {
    static let openSettingsFromCreate = Notification.Name("openSettingsFromCreate")
    static let openSpotlightItem = Notification.Name("openSpotlightItem")
    static let openSpotlightLocation = Notification.Name("openSpotlightLocation")
}

struct ContentView: View {
    @StateObject private var accentColorManager = AccentColorManager()
    @EnvironmentObject var quickActionState: QuickActionState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @Environment(\.colorScheme) var colorScheme  // Zugriff auf Dark/Light Mode
    @State private var selectedColor: Color = UserDefaultsManager.loadAccentColor()
    @State private var selectedTab: Tab = .boxes // Standard-Tab, z. B. "Overview"
    @State private var BoxUUIDString: String? = nil
    @State var boxUUID: UUID? // UUID als optionaler Wert, da sie evtl. nicht immer gesetzt ist
    //@State var selectedBoxId = UserDefaults.standard.string(forKey: "uuidViaUrl") // UUID als String
    @State private var boxes: [MovingBox] = loadBoxes() // State für alle Boxen
    @State private var selectedBox: MovingBox? = nil// State für die ausgewählte Box
    @State private var selection: String? = "overview"
    @State var missingUUID : UUID? = nil
    @Binding var lastState: String
    @State var searchText: String = ""
    @State var isActive : Bool = true //UserDefaultsManager.shared.loadLauchscreen() ?? true
    @State private var navigation = NavigationPath()
    @State var selectedOption : String = "boxes"
    @ObservedObject private var handoff = InventoryHandoffStore.shared
    @ObservedObject private var handoffReception = InventoryHandoffReception.shared
    @ObservedObject private var widgetNavigation = RecentBoxWidgetNavigation.shared
    @State private var lastHandledFormHandoff: UUID?
    @State private var lastHandledSearchHandoff: UUID?
    @State private var showSettings = false
    @State private var pageOnLauch: String = UserDefaultsManager.shared.loadPageOnLauch()
    @State private var shortURLMatches: [MovingBox] = []
    @State private var showShortURLConflictSheet = false
    @State private var disableShortURLInConflictSheet = false
    @State private var hasAppliedFirstTabStartupSelection = false
    @State private var hasVisitedListThisLaunch = false
    //@State private var selectedBoxID: String = ""
    // Die Navigation hält nur die UUID fest; Lesen und Schreiben nutzen den aktuellen Bestand.
    private func bindingForBox(_ box: MovingBox) -> Binding<MovingBox> {
        Binding(
            get: { boxes.first(where: { $0.id == box.id }) ?? box },
            set: { newBox in
                if let current = InventoryMutation.box(box.id, change: { $0 = newBox }) {
                    boxes = current
                }
            }
        )
    }

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .tv {
                NavigationSplitView {
                    NavigationStack(path: $navigation) {
                        MutiTabView(selectedOption: $selectedOption)
                            .navigationDestination(for: UUID.self) { id in
                                if let box = boxes.first(where: { $0.id == id}) {
                                    BoxDetailView(searchText: $searchText, selectedOption: $selectedOption, box: bindingForBox(box))
                                }
                                else {
                                    AnyView(EmptyView())
                                }
                            }
                    }
                }
                detail: {
                    CreateView(missingUUID: $missingUUID)
                }
            }
            else  {
                if #available(iOS 26.0, *) {
                    TabView(selection: $selectedTab) {
                        NavigationStack(path: $navigation) {
                            MutiTabView(selectedOption: $selectedOption)
                                .navigationDestination(for: UUID.self) { id in
                                    if let box = boxes.first(where: { $0.id == id}) {
                                        BoxDetailView(searchText: $searchText, selectedOption: $selectedOption, box: bindingForBox(box))
                                    }
                                    else {
                                        InvalidLinkView()
                                    }
                                }
                        }
                        .tabItem {
                            Label(returnNavigationLabel(selectedOption), systemImage: returnNavigationSymbol(selectedOption))
                        }
                        .tag(Tab.boxes)
                        CreateView(missingUUID: $missingUUID)
                            .tabItem {
                                Label("TabView.Label.Create", systemImage: "plus.circle.fill")
                            }
                            .tag(Tab.create)
                        SettingsView()
                            .tabItem {
                                Label("TabView.Label.Settings", systemImage: "gearshape.fill")
                            }
                            .tag(Tab.settings)
                    }
                    .onOpenURL { url in
                        processIncomingURL(url)
                    }
                    .accentColor(accentColorManager.accentColor)
                    .environmentObject(accentColorManager)
                    .navigationTitle("BoxHelper")
                    .navigationViewStyle(StackNavigationViewStyle())
                    .onAppear {
                        pageOnLauch = UserDefaultsManager.shared.loadPageOnLauch()
                        lastState = UserDefaultsManager.shared.loadLastState()
                        if BoxUUIDString == nil, handoff.pendingFormKind == nil, handoff.incomingSearch == nil {
                            if boxes.isEmpty {
                                selectedTab = .create
                            }
                            else{
                                if pageOnLauch == "Last" {
                                    if lastState == "settings" {
                                        selectedTab = .settings
                                    }
                                    if lastState == "create" {
                                        selectedTab = .create
                                    }
                                    if lastState == "boxes" {
                                        selectedTab = .boxes
                                    }
                                }
                                else {
                                    if pageOnLauch == "Create" {
                                        selectedTab = .create
                                    }
                                    else {
                                        selectedTab = .boxes
                                    }
                                }
                            }
                        }
                        accentColorManager.accentColor = UserDefaultsManager.loadAccentColor()
                        applyFirstTabStartupSelectionIfNeeded()
                        consumePendingQuickAction()
                        handleAutomaticReviewForListVisit()
                    }
                    .onChange(of: quickActionState.pendingAction) { _, action in
                        guard let action else { return }
                        consumePendingQuickAction(action)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .openSettingsFromCreate)) { _ in
                        selectedTab = .settings
                    }
                    .onChange(of: selectedTab, initial: false) { _, newValue in
                        applyFirstTabStartupSelectionIfNeeded()
                        if newValue == .boxes { handleAutomaticReviewForListVisit() }
                    }
                    .onChange(of: selectedOption, initial: false) { _, newValue in
                        persistLastFirstTabSelection(newValue)
                    }
                }
                else {
                    TabView(selection: $selectedTab) {
                        NavigationStack(path: $navigation) {
                            MutiTabView(selectedOption: $selectedOption)
                                .navigationDestination(for: UUID.self) { id in
                                    if let box = boxes.first(where: { $0.id == id}) {
                                        BoxDetailView(searchText: $searchText, selectedOption: $selectedOption, box: bindingForBox(box))
                                    }
                                    else {
                                        InvalidLinkView()
                                    }
                                }
                        }
                        .tabItem {
                        
                                Label(returnNavigationLabel(selectedOption), systemImage: returnNavigationSymbol(selectedOption))
                        }
                        .tag(Tab.boxes)
                        CreateView(missingUUID: $missingUUID)
                            .tabItem {
                                Label("TabView.Label.Create", systemImage: "plus.circle.fill")
                            }
                            .tag(Tab.create)
                        
                        SettingsView()
                            .tabItem {
                                Label("TabView.Label.Settings", systemImage: "gearshape.fill")
                            }
                            .tag(Tab.settings)
                    }
                    .onOpenURL { url in
                        processIncomingURL(url)
                    }
                    .accentColor(accentColorManager.accentColor)
                    .environmentObject(accentColorManager)
                    .navigationTitle("BoxHelper")
                    .navigationViewStyle(StackNavigationViewStyle())
                    .onAppear {
                        pageOnLauch = UserDefaultsManager.shared.loadPageOnLauch()
                        lastState = UserDefaultsManager.shared.loadLastState()
                        if BoxUUIDString == nil, handoff.pendingFormKind == nil, handoff.incomingSearch == nil {
                            
                            if boxes.isEmpty {
                                selectedTab = .create
                            }
                            else{
                                if pageOnLauch == "Last" {
                                    if lastState == "settings" {
                                        selectedTab = .settings
                                    }
                                    if lastState == "create" {
                                        selectedTab = .create
                                    }
                                    if lastState == "boxes" {
                                        selectedTab = .boxes
                                    }
                                }
                                else {
                                    if pageOnLauch == "Create" {
                                        selectedTab = .create
                                    }
                                    else {
                                        selectedTab = .boxes
                                    }
                                }
                            }
                        }
                        
                        accentColorManager.accentColor = UserDefaultsManager.loadAccentColor()
                        applyFirstTabStartupSelectionIfNeeded()
                        consumePendingQuickAction()
                        handleAutomaticReviewForListVisit()
                    }
                    .onChange(of: quickActionState.pendingAction) { _, action in
                        guard let action else { return }
                        consumePendingQuickAction(action)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .openSettingsFromCreate)) { _ in
                        selectedTab = .settings
                    }
                    .onChange(of: selectedTab, initial: false) { _, newValue in
                        applyFirstTabStartupSelectionIfNeeded()
                        if newValue == .boxes { handleAutomaticReviewForListVisit() }
                    }
                    .onChange(of: selectedOption, initial: false) { _, newValue in
                        persistLastFirstTabSelection(newValue)
                    }
                }
            }
            /*
            .sheet(isPresented: $showBoxDetail) {
                ...
            }
             */
        }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryDidChange)) { _ in
            boxes = loadBoxes()
        }
        .onChange(of: widgetNavigation.requestID, initial: true) { _, _ in
            guard let id = widgetNavigation.boxID else { return }
            boxes = loadBoxes()
            widgetNavigation.consume()
            selectedTab = .boxes
            selectedOption = "boxes"
            searchText = ""
            navigation = NavigationPath()
            // Ein veraltetes Widget kann noch eine inzwischen gelöschte Kiste zeigen.
            // In diesem Fall zur Liste wechseln, statt eine Neuerstellung anzubieten.
            guard boxes.contains(where: { $0.id == id }) else {
                RecentBoxWidgetPublisher.schedule()
                return
            }
            BoxUUIDString = id.uuidString
            openBoxFromIncomingLink(id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .resumeInventoryHandoff)) { _ in
            routePendingHandoff()
        }
        .onChange(of: handoff.pendingFormRequestID, initial: true) { _, _ in routePendingHandoff() }
        .onChange(of: handoff.incomingSearch?.id, initial: true) { _, _ in routePendingHandoff() }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryShareAccepted)) { _ in
            if InventoryCloudSyncState.shared.isActive { selectedTab = .boxes }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudAppPreferencesDidChange)) { _ in
            accentColorManager.accentColor = UserDefaultsManager.loadAccentColor()
            pageOnLauch = UserDefaultsManager.shared.loadPageOnLauch()
        }
        .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
            handoffReception.continueActivity(userActivity)
        }
        .onChange(of: handoffReception.spotlightRequestID, initial: true) { _, request in
            if let activity = handoffReception.spotlightActivity {
                handleSpotlightUserActivity(activity)
                Task { @MainActor in
                    await Task.yield()
                    handoffReception.consumeSpotlightRequest(request)
                }
            }
        }
        .sheet(isPresented: $showShortURLConflictSheet) {
            NavigationStack {
                List {
                    Section {
                        Text("Multiple Boxes found, consider disable ShortURL and print new labels for each box.")
                            .font(.headline)
                            .padding(.vertical, 4)
                            .foregroundStyle(Color(.yellow))
                    }
                    .listRowBackground(Color.clear)

                    Section("Matches") {
                        ForEach(shortURLMatches) { box in
                            Button {
                                openBoxFromIncomingLink(box.id)
                                showShortURLConflictSheet = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(box.name.isEmpty ? "Unnamed Box" : box.name)
                                            .foregroundStyle(.primary)
                                        Text(box.id.uuidString)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Section("QR Code") {
                        Toggle("Disable ShortURL", isOn: $disableShortURLInConflictSheet)
                            .onChange(of: disableShortURLInConflictSheet, initial: false) { _, newValue in
                                UserDefaultsManager.shared.saveUseShortQRCodeURL(!newValue)
                            }
                    }
                }
                .navigationTitle("URL Conflict")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showShortURLConflictSheet = false
                        }
                    }
                }
            }
        }
        .onChange(of: scenePhase, initial: false) { _, phase in
            if phase == .active {
                consumePendingQuickAction()
            }
        }
    }

    private func applyQuickAction(_ action: AppQuickAction) {
        switch action {
        case .createBox:
            selectedTab = .create
        case .showItems:
            selectedTab = .boxes
            selectedOption = "items"
        case .showLocations:
            selectedTab = .boxes
            selectedOption = "locations"
        case .showSettings:
            selectedTab = .settings
        }
    }

    private func consumePendingQuickAction(_ action: AppQuickAction? = nil) {
        let resolvedAction = action ?? quickActionState.pendingAction
        guard let resolvedAction else { return }
        applyQuickAction(resolvedAction)
        quickActionState.pendingAction = nil
    }

    // Verarbeitet sowohl alte Full-UUID-Links als auch neue ShortURL-Links.
    private func processIncomingURL(_ url: URL) {
        boxes = loadBoxes()
        let resolution = resolveIncomingBoxURL(url, boxes: boxes)

        if resolution.hasMultipleMatches {
            shortURLMatches = resolution.matchingBoxes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            disableShortURLInConflictSheet = !UserDefaultsManager.shared.loadUseShortQRCodeURL()
            showShortURLConflictSheet = true
            return
        }

        if let uuidString = resolution.resolvedUUIDString, let uuid = UUID(uuidString: uuidString) {
            BoxUUIDString = uuidString
            openBoxFromIncomingLink(uuid)
            return
        }

        BoxUUIDString = nil
    }

    private func openBoxFromIncomingLink(_ uuid: UUID) {
        if let boxIndex = boxes.firstIndex(where: { $0.id == uuid }) {
            selectedBox = boxes[boxIndex]
            boxUUID = uuid
            selectedTab = .boxes
            navigation.append(boxes[boxIndex].id)
        } else {
            missingUUID = uuid
            selectedTab = .create
        }
    }

    // Setzt den Start-Tab für den FirstTab-Bereich genau einmal pro App-Start,
    // sobald der User den Boxen-Bereich erstmals öffnet.
    private func applyFirstTabStartupSelectionIfNeeded() {
        guard selectedTab == .boxes else { return }
        guard !hasAppliedFirstTabStartupSelection else { return }
        hasAppliedFirstTabStartupSelection = true

        let mode = UserDefaults.standard.string(forKey: "firstTabOnLaunchMode") ?? "remember"
        if mode == "fixed" {
            let fixedTab = normalizedFirstTabSelection(UserDefaults.standard.string(forKey: "firstTabOnLaunchSelection"))
            selectedOption = fixedTab
            return
        }

        if let savedTab = UserDefaults.standard.string(forKey: "lastFirstTabSelection"), !savedTab.isEmpty {
            selectedOption = normalizedFirstTabSelection(savedTab)
        }
    }

    private func persistLastFirstTabSelection(_ tab: String) {
        // Speichert nur gültige FirstTab-Werte, damit keine ungültigen Zustände persistiert werden.
        UserDefaults.standard.set(normalizedFirstTabSelection(tab), forKey: "lastFirstTabSelection")
    }

    private func handleAutomaticReviewForListVisit() {
        // A list visit arms the request for the next app launch, never the current one.
        guard !hasVisitedListThisLaunch, selectedTab == .boxes else { return }
        hasVisitedListThisLaunch = true

        let defaults = UserDefaults.standard
        let pendingKey = "automaticReviewPendingAfterListVisit"
        guard defaults.bool(forKey: pendingKey) else {
            defaults.set(true, forKey: pendingKey)
            return
        }

        guard loadBoxes().count >= 2, loadItems().count >= 4 else { return }
        defaults.set(false, forKey: pendingKey)

        if #available(iOS 18.0, *),
           let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            AppStore.requestReview(in: windowScene)
        } else {
            requestReview()
        }
    }

    private func normalizedFirstTabSelection(_ tab: String?) -> String {
        let allowedTabs = ["boxes", "items", "locations", "images"]
        guard let tab, allowedTabs.contains(tab) else {
            return "boxes"
        }
        return tab
    }

    /// Empfangene Aktivitäten haben Vorrang vor der gespeicherten Startseite.
    /// Die Anfrage-ID verhindert, dass ein späterer UI-Refresh erneut dahin navigiert.
    private func routePendingHandoff() {
        if let search = handoff.incomingSearch, search.id != lastHandledSearchHandoff {
            lastHandledSearchHandoff = search.id
            hasAppliedFirstTabStartupSelection = true
            selectedOption = search.tab
            selectedTab = .boxes
            navigation = NavigationPath()
        } else if let request = handoff.pendingFormRequestID, request != lastHandledFormHandoff {
            lastHandledFormHandoff = request
            missingUUID = nil
            selectedTab = .create
            navigation = NavigationPath()
        }
    }

    // Spotlight publishes boxes only; opening a result always shows that box's details.
    private func handleSpotlightUserActivity(_ userActivity: NSUserActivity) {
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
        let components = identifier.split(separator: ":", maxSplits: 1)
        guard components.count == 2, components[0] == "box",
              let id = UUID(uuidString: String(components[1])) else { return }

        boxes = loadBoxes()
        // A deleted result must never open the create form as an incoming QR link would.
        guard boxes.contains(where: { $0.id == id }) else {
            scheduleSpotlightReindexIfEnabled()
            return
        }
        BoxUUIDString = id.uuidString
        selectedTab = .boxes
        applyFirstTabStartupSelectionIfNeeded()
        selectedOption = "boxes"
        navigation = NavigationPath()
        openBoxFromIncomingLink(id)
    }

    enum Tab: Hashable {
        case test
        case boxes
        case items
        case locations
        case create
        case settings
    }
}
class AccentColorManager: ObservableObject {
    @Published var accentColor: Color = UserDefaultsManager.loadAccentColor()

    func updateAccentColor(to newColor: Color) {
        guard accentColor != newColor else { return }
        // @Published already sends objectWillChange; a second notification repeats the update.
        accentColor = newColor
        UserDefaultsManager.saveAccentColor(newColor)
    }
}

#Preview {
    ContentView(lastState: Binding(get: { .init() }, set: { _ in }))
        .environmentObject(QuickActionState.shared)
}

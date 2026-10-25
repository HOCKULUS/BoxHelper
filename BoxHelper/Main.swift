import SwiftUI
import SwiftData
import TipKit
import UIKit
import CloudKit

extension Notification.Name {
    static let replayLaunchScreen = Notification.Name("replayLaunchScreen")
}

@main
struct BoxHelperApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var quickActionState = QuickActionState.shared
    @StateObject private var storageState = InventoryStorageState.shared
    @State private var didHandleAppStart = false
    @State private var showAcceptedCloudShare = false
    @ObservedObject private var handoff = InventoryHandoffStore.shared
    @ObservedObject private var handoffReception = InventoryHandoffReception.shared
    @ObservedObject private var widgetNavigation = RecentBoxWidgetNavigation.shared
    @State private var launchPresentation: LaunchPresentationPolicy.Presentation = .initial
    @State var isActive : Bool = UserDefaultsManager.shared.loadLauchscreen()
    @State var lastState : String = UserDefaultsManager.shared.loadLastState()
    
    init() {
        // Vor dem ersten Formular oder Intent sämtliche Legacy-Tabellen atomar übernehmen.
        InventoryStorageState.shared.initialize()

        //Farbshema
        /*
        let label = UIColor(named: "DesertLabel") ?? UIColor.label
        let secondaryLabel = UIColor(named: "DesertSecondaryLabel") ?? UIColor.secondaryLabel
        let tertiaryLabel = UIColor(named: "DesertTertiaryLabel") ?? UIColor.tertiaryLabel
        let quaternaryLabel = UIColor(named: "DesertQuaternaryLabel") ?? UIColor.quaternaryLabel

        let systemFill = UIColor(named: "DesertSystemFill") ?? UIColor.systemFill
        let secondarySystemFill = UIColor(named: "DesertSecondarySystemFill") ?? UIColor.secondarySystemFill
        let tertiarySystemFill = UIColor(named: "DesertTertiarySystemFill") ?? UIColor.tertiarySystemFill
        let quaternarySystemFill = UIColor(named: "DesertQuaternarySystemFill") ?? UIColor.quaternarySystemFill

        let placeholderText = UIColor(named: "DesertPlaceholderText") ?? UIColor.placeholderText

        let systemBackground = UIColor(named: "DesertSystemBackground") ?? UIColor.systemBackground
        let secondarySystemBackground = UIColor(named: "DesertSecondarySystemBackground") ?? UIColor.secondarySystemBackground
        let tertiarySystemBackground = UIColor(named: "DesertTertiarySystemBackground") ?? UIColor.tertiarySystemBackground

        let systemGroupedBackground = UIColor(named: "DesertSystemGroupedBackground") ?? UIColor.systemGroupedBackground
        let secondarySystemGroupedBackground = UIColor(named: "DesertSecondarySystemGroupedBackground") ?? UIColor.secondarySystemGroupedBackground
        let tertiarySystemGroupedBackground = UIColor(named: "DesertTertiarySystemGroupedBackground") ?? UIColor.tertiarySystemGroupedBackground

        let separator = UIColor(named: "DesertSeparator") ?? UIColor.separator
        let opaqueSeparator = UIColor(named: "DesertOpaqueSeparator") ?? UIColor.opaqueSeparator
        let link = UIColor(named: "DesertLink") ?? UIColor.link
        let darkText = UIColor(named: "DesertDarkText") ?? UIColor.darkText
        let lightText = UIColor(named: "DesertLightText") ?? UIColor.lightText

        // NavigationBar
            let UINavigationBarAppearance = UINavigationBarAppearance()
            UINavigationBarAppearance.configureWithOpaqueBackground()
            UINavigationBarAppearance.backgroundColor = systemBackground
            UINavigationBarAppearance.titleTextAttributes = [.foregroundColor: label]
            UINavigationBarAppearance.largeTitleTextAttributes = [.foregroundColor: label]

            // Alle Button-States manuell setzen
            UINavigationBarAppearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: label]
            UINavigationBarAppearance.backButtonAppearance.highlighted.titleTextAttributes = [.foregroundColor: label]
            UINavigationBarAppearance.backButtonAppearance.disabled.titleTextAttributes = [.foregroundColor: label]
            UINavigationBarAppearance.backButtonAppearance.focused.titleTextAttributes = [.foregroundColor: label]

            UINavigationBarAppearance.buttonAppearance.normal.titleTextAttributes = [.foregroundColor: label]
            UINavigationBarAppearance.buttonAppearance.highlighted.titleTextAttributes = [.foregroundColor: label]
            UINavigationBarAppearance.buttonAppearance.disabled.titleTextAttributes = [.foregroundColor: label]
            UINavigationBarAppearance.buttonAppearance.focused.titleTextAttributes = [.foregroundColor: label]

            UINavigationBarAppearance.doneButtonAppearance.normal.titleTextAttributes = [.foregroundColor: label]
            UINavigationBarAppearance.doneButtonAppearance.highlighted.titleTextAttributes = [.foregroundColor: label]
            UINavigationBarAppearance.doneButtonAppearance.disabled.titleTextAttributes = [.foregroundColor: label]
            UINavigationBarAppearance.doneButtonAppearance.focused.titleTextAttributes = [.foregroundColor: label]

            // Global anwenden
            UINavigationBar.appearance().standardAppearance = UINavigationBarAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = UINavigationBarAppearance
            UINavigationBar.appearance().compactAppearance = UINavigationBarAppearance
            UINavigationBar.appearance().tintColor = label // Chevron + UIBarButtonItems
        
        // Section / List (UITableView)
            let UITableViewAppearance = UITableView.appearance()
            UITableViewAppearance.backgroundColor = systemGroupedBackground
            UITableViewAppearance.separatorColor = separator

            // Section Header/Footer Label Farben (via UILabel appearance)
            let UITableViewHeaderFooterLabel = UILabel.appearance(whenContainedInInstancesOf: [UITableViewHeaderFooterView.self])
            UITableViewHeaderFooterLabel.textColor = label
            UITableViewHeaderFooterLabel.backgroundColor = systemGroupedBackground

            // Optional: Auswahlfarben (Selection Background)
            let selectedBackgroundView = UIView()
            selectedBackgroundView.backgroundColor = secondarySystemFill
            UITableViewCell.appearance().selectedBackgroundView = selectedBackgroundView

            // Zellhintergrundfarbe
            UITableViewCell.appearance().backgroundColor = systemBackground

            // Placeholder (z. B. bei TextFields in Cells)
            UITextField.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).attributedPlaceholder = NSAttributedString(
                string: "Placeholder",
                attributes: [.foregroundColor: placeholderText]
            )
         */
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if storageState.isInitialized {
                    // Der stabile View-Baum erhält offene Formulare beim Storewechsel.
                    appContent
                } else {
                    ContentUnavailableView {
                        Label("Inventar konnte nicht geöffnet werden", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text(storageState.errorMessage ?? "Die Datenbank wird geöffnet.")
                    } actions: {
                        Button("Erneut versuchen") { storageState.initialize() }
                    }
                }
            }
            .modifier(InventoryTrashIntroduction())
            .alert("Datenbankfehler", isPresented: Binding(
                get: { storageState.isInitialized && storageState.errorMessage != nil },
                set: { if !$0 { storageState.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { storageState.errorMessage = nil }
            } message: {
                Text(storageState.errorMessage ?? "")
            }
            .onContinueUserActivity(InventoryHandoffStore.formActivityType) { handoffReception.continueActivity($0) }
            .onContinueUserActivity(InventoryHandoffStore.searchActivityType) { handoffReception.continueActivity($0) }
            .onChange(of: handoff.pendingFormRequestID, initial: true) { _, request in
                if request != nil { isActive = false }
            }
            .onChange(of: handoff.incomingSearch?.id, initial: true) { _, request in
                if request != nil { isActive = false }
            }
            .onChange(of: handoffReception.spotlightRequestID, initial: true) { _, request in
                if request != nil { isActive = false }
            }
            .onChange(of: handoffReception.hasAcceptedActivity, initial: true) { _, accepted in
                if accepted { isActive = false }
            }
            .overlay {
                if handoffReception.isReceiving {
                    ProgressView("Übergabe wird geladen …")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .alert("Handoff konnte nicht fortgesetzt werden", isPresented: Binding(
                get: { handoffReception.errorMessage != nil },
                set: { if !$0 { handoffReception.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { handoffReception.errorMessage = nil }
            } message: { Text(handoffReception.errorMessage ?? "") }
        }
    }

    private var appContent: some View {
            Group {
                if isActive {
                    LaunchScreen(isActive: $isActive, presentation: launchPresentation)
                }
                else{
                    ContentView(lastState: $lastState)
                        .environmentObject(quickActionState)
                        .task {
                            try? Tips.configure([
                                .displayFrequency(.immediate),
                                .datastoreLocation(.applicationDefault)
                            ])
                        }
                }
            }
            .onChange(of: widgetNavigation.requestID, initial: true) { _, _ in
                // Ein Widget-Auftrag muss auch beim Kaltstart direkt zur Kiste führen.
                if widgetNavigation.requestID != nil { isActive = false }
            }
            .onAppear {
                // Nur ein Appstart pro Prozess: View-Wechsel oder Vordergrundwechsel
                // dürfen die drei Wiederholungen nicht mehrfach verbrauchen.
                guard !didHandleAppStart else { return }
                didHandleAppStart = true
                if handoffReception.hasAcceptedActivity || handoff.pendingFormKind != nil || handoff.incomingSearch != nil
                    || handoffReception.spotlightRequestID != nil || widgetNavigation.requestID != nil {
                    isActive = false
                } else if let presentation = LaunchPresentationPolicy.beginAppStart() {
                    launchPresentation = presentation
                    isActive = true
                } else { isActive = false }
                rebuildSpotlightIndex()
                RecentBoxWidgetPublisher.schedule()
            }

            .onReceive(NotificationCenter.default.publisher(for: .replayLaunchScreen)) { _ in
                // Einstellungen dürfen die Ankündigung zeigen, ohne Appstarts zu zählen.
                launchPresentation = .replay
                isActive = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .inventoryShareAccepted)) { _ in
                showAcceptedCloudShare = true
            }
            .sheet(isPresented: $showAcceptedCloudShare) { InventoryCloudDashboard() }
    }
}

enum AppQuickAction: String {
    case createBox = "de.hockulus.boxhelper.quickaction.create"
    case showItems = "de.hockulus.boxhelper.quickaction.items"
    case showLocations = "de.hockulus.boxhelper.quickaction.locations"
    case showSettings = "de.hockulus.boxhelper.quickaction.settings"
}

@MainActor
final class QuickActionState: ObservableObject {
    static let shared = QuickActionState()
    @Published var pendingAction: AppQuickAction?

    private init() {}

    @discardableResult
    func handle(shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let action = AppQuickAction(rawValue: shortcutItem.type) else {
            return false
        }
        pendingAction = action
        return true
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if InventoryCloudSyncState.shared.isActive {
            // Stille CloudKit-Pushes benötigen keine Benachrichtigungsfreigabe des Nutzers.
            application.registerForRemoteNotifications()
        }
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            _ = QuickActionState.shared.handle(shortcutItem: shortcutItem)
            return false
        }
        return true
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(QuickActionState.shared.handle(shortcutItem: shortcutItem))
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcut = options.shortcutItem {
            _ = QuickActionState.shared.handle(shortcutItem: shortcut)
        }
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = InventoryShareSceneDelegate.self
        return config
    }

    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        Task { await InventorySharingService.shared.accept(metadata) }
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        guard InventoryCloudSyncState.shared.isActive else { return .noData }
        // Auch ein Push ist ein expliziter Wake-Callback. Die Assertion muss vor
        // dem ersten Await bestehen, damit die Wartungs-Worker hier starten dürfen.
        guard let lease = InventoryBackgroundExecution.shared.begin(name: "Inventory Cloud Push", isContinuation: true)
        else { return .failed }
        do {
            return try await lease.perform {
                InventoryCloudSyncCoordinator.shared.scheduleReconciliation(refreshInventory: true)
                try await InventorySharingService.shared.synchronize()
                return UIBackgroundFetchResult.newData
            }
        } catch is CancellationError { return .noData }
        catch { InventoryCloudSyncState.shared.recordCollaborationError(error); return .failed }
    }
}

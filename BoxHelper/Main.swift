import SwiftUI
import SwiftData
import TipKit
import UIKit

extension Notification.Name {
    static let replayLaunchScreen = Notification.Name("replayLaunchScreen")
}

@main
struct BoxHelperApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var quickActionState = QuickActionState.shared
    @State var showLaunchScreen : Bool = false
    @State var isActive : Bool = UserDefaultsManager.shared.loadLauchscreen()
    @State var lastState : String = UserDefaultsManager.shared.loadLastState()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Führe die Migration beim Start der App aus
        var dataManager = DataManager(boxes: [], itemsDatabase: [], locationsDatabase: [])
        dataManager.loadFromUserDefaults() // Vorhandene Daten laden
        dataManager.migrateItemsToNewModel() // Migration durchführen
        dataManager.migrateLocationsToNewModel()
        
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
                if isActive {
                    LaunchScreen(isActive: $isActive)
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
            .modelContainer(sharedModelContainer)
            .onAppear {
                print("🟡 onAppear triggered.")

                let loadedLaunchscreen = UserDefaultsManager.shared.loadLauchscreen()
                print("🔍 Loaded launchscreen flag from UserDefaults: \(String(describing: loadedLaunchscreen))")

                showLaunchScreen = loadedLaunchscreen
                print("📺 showLaunchScreen set to: \(showLaunchScreen)")

                if showLaunchScreen {
                    isActive = true
                    print("✅ Launch screen is active.")
                } else {
                    isActive = false
                    print("⏩ Skipping launch screen.")
                }

                UserDefaultsManager.shared.saveLauchscreen(false)
                print("💾 Launch screen flag set to false in UserDefaults.")
            }
            .onReceive(NotificationCenter.default.publisher(for: .replayLaunchScreen)) { _ in
                // Allow replaying the launch animation on demand from settings.
                isActive = true
            }
        }

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
        return config
    }
}

import CloudKit
import UIKit

/// SwiftUI-Apps erhalten Share-Links über die Scene, auch bei einem kalten Appstart.
@MainActor
final class InventoryShareSceneDelegate: NSObject, UIWindowSceneDelegate {
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Nach abgelaufener Hintergrundzeit die lokalen Wartungsaufträge erneut
        // anstoßen, auch wenn private iCloud-Synchronisierung ausgeschaltet ist.
        InventoryPersistence.refreshAfterRemoteChange()
        InventoryCloudPreferencesStore.shared.scheduleReconciliation()
        InventorySharingService.shared.requestSync()
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        // Echtes Handoff wird auch nach einem Kaltstart über diesen Callback geliefert.
        // Der gemeinsame Empfänger dedupliziert eine zusätzliche SwiftUI-Zustellung.
        InventoryHandoffReception.shared.continueActivity(userActivity)
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Spotlight kann bereits in den Verbindungsoptionen stehen. Handoff wird
        // dagegen nach dem Aufbau der Scene über scene(_:continue:) zugestellt.
        for activity in connectionOptions.userActivities {
            InventoryHandoffReception.shared.continueActivity(activity)
        }
        if let metadata = connectionOptions.cloudKitShareMetadata {
            Task { await InventorySharingService.shared.accept(metadata) }
        }
    }

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        Task { await InventorySharingService.shared.accept(metadata) }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        completionHandler(QuickActionState.shared.handle(shortcutItem: shortcutItem))
    }
}

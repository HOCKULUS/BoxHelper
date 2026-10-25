import CloudKit
import SwiftUI
import UIKit

/// Apple verwaltet Teilnehmer, Einladung, Rechte und Widerruf über dieselbe CKShare.
/// Das Erstellen des Dialogs verschickt selbst noch keine Nachricht.
struct InventoryCloudSharingController: UIViewControllerRepresentable {
    let share: CKShare
    var access: InventoryShareScope.Access = .readWrite

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share,
                                                  container: CKContainer(identifier: CloudSyncPreferences.containerIdentifier))
        // Die Bilderauswahl gilt für die ganze Zone. Eine Freigabe ohne Bilder
        // bleibt daher im Verwaltungsdialog auf Leserechte beschränkt.
        controller.availablePermissions = access == .readOnly
            ? [.allowPrivate, .allowReadOnly] : [.allowPrivate, .allowReadWrite]
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func itemTitle(for csc: UICloudSharingController) -> String? { csc.share?[CKShare.SystemFieldKey.title] as? String ?? "BoxHelper" }
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            InventoryCloudSyncState.shared.recordCollaborationError(error)
        }
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) { InventorySharingService.shared.requestSync() }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) { InventorySharingService.shared.requestSync() }
    }
}

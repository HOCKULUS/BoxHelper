import SwiftUI

/// Ein einziger Einstieg wechselt nach Erstellen oder Beenden automatisch seinen Inhalt.
struct InventorySharingView: View {
    @ObservedObject private var sharing = InventorySharingService.shared
    @State private var selectedShareID = ""
    @State private var isCreating = false
    @State private var presentedShare: PresentedInventoryShare?

    // Eigene Freigaben haben Vorrang. Bereits vorhandene oder empfangene Freigaben
    // bleiben verwaltbar, auch wenn ältere Appversionen mehrere angelegt haben.
    private var activeShares: [InventoryShareDescriptor] {
        sharing.shares.filter(\.isAvailable).sorted {
            if $0.isOwner != $1.isOwner { return $0.isOwner }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    private var selectedShare: InventoryShareDescriptor? {
        activeShares.first { $0.id == selectedShareID } ?? activeShares.first
    }

    var body: some View {
        Group {
            if !isCreating, let descriptor = selectedShare {
                InventoryShareDetailView(descriptor: descriptor,
                                         selectableShares: activeShares,
                                         selectedShareID: $selectedShareID)
                    .id(descriptor.id)
            } else {
                NewInventoryShareView(isCreating: $isCreating, presentedShare: $presentedShare)
            }
        }
        .navigationTitle("Inventar freigeben")
        .navigationBarTitleDisplayMode(.inline)
        // Die Präsentation gehört der stabilen Seite, damit der Wechsel vom
        // Erstellformular zu den Freigabeinformationen die Einladung nicht schließt.
        .sheet(item: $presentedShare) {
            InventoryCloudSharingController(share: $0.share, access: $0.access)
        }
        .task { sharing.start(); sharing.requestSync() }
    }
}

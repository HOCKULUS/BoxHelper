import SwiftUI

/// Nur an den Hauptebenen einbinden; Unteransichten und Sheets erhalten keinen Button.
struct InventoryCloudToolbar: ViewModifier {
    let isVisible: Bool
    @State private var isRootVisible = true

    func body(content: Content) -> some View {
        content.toolbar {
            if isRootVisible && isVisible {
                ToolbarItem(id: "inventoryCloudStatus", placement: .topBarLeading) {
                    InventoryCloudStatusButton()
                }
            }
        }
        // Auch zielbasierte NavigationLinks melden den Ebenenwechsel über den
        // Lebenszyklus, ohne dass jeder Unteransicht ein Navigationspfad übergeben wird.
        .onAppear { isRootVisible = true }
        .onDisappear { isRootVisible = false }
    }
}

extension View {
    func inventoryCloudToolbar(isVisible: Bool = true) -> some View {
        modifier(InventoryCloudToolbar(isVisible: isVisible))
    }
}

struct InventoryCloudStatusButton: View {
    @ObservedObject private var state = InventoryCloudSyncState.shared
    @State private var presented = false

    var body: some View {
        Button { presented = true } label: {
            // Nur das innere Warnzeichen wird rot; die Wolke behält ihre Textfarbe.
            if state.indicator == .failed {
                Image(systemName: "exclamationmark.icloud")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.red, .primary)
            } else {
                Image(systemName: cloudSymbol)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.primary)
            }
        }
        .tint(.primary)
        .accessibilityLabel("iCloud: \(state.syncStatusDescription)")
        .accessibilityHint("iCloud-Status und Freigaben öffnen")
        .accessibilityIdentifier("inventory.iCloud.status")
        .sheet(isPresented: $presented) { InventoryCloudDashboard() }
    }

    private var cloudSymbol: String {
        if state.indicator == .disabled { return "icloud.slash" }
        // Der tatsächlich eingerichtete Cloud-Store erhält die gefüllte Wolke.
        return state.isActive ? "icloud.fill" : "icloud"
    }

}

import SwiftUI
import TipKit

struct InventoryTrashTip: Tip {
    static let deletionEvent = Event(id: "inventoryTrashLocalDeletion")

    var title: Text { Text("Trash.TipTitle") }
    var message: Text? { Text("Trash.TipMessage") }
    var image: Image? { Image(systemName: "trash") }
    var rules: [Rule] {
        #Rule(Self.deletionEvent) { $0.donations.count > 0 }
    }
    var options: [Option] { MaxDisplayCount(1); IgnoresDisplayFrequency(true) }
}

/// Bestätigte Löschungen machen den einmaligen Tipp verfügbar. Angezeigt wird er
/// ausschließlich am Papierkorb-Eintrag in den Einstellungen, ohne eigenen Button.
struct InventoryTrashIntroduction: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .inventoryTrashLocalDeletion)) { _ in
                Task { await InventoryTrashTip.deletionEvent.donate() }
            }
    }
}

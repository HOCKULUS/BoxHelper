import SwiftUI
import TipKit

/// Stellt die neuen Formulare vor; CreateView zeigt den Tipp erst mit vorhandener Kiste.
struct CreateModesTip: Tip {
    var title: Text {
        Text("CreateItemTip.FormsTitle")
    }

    var message: Text? {
        Text("CreateItemTip.FormsMessage")
    }

    var image: Image? {
        Image(systemName: "plus.circle.fill")
    }

    var options: [Option] {
        // Show the introduction once, even if another tip was recently displayed.
        MaxDisplayCount(1)
        IgnoresDisplayFrequency(true)
    }
}

import SwiftUI
import TipKit

/// Die Gegenstands-Auslöser werden beim ersten Besuch kurz und direkt am jeweiligen Button erklärt.
struct CreateItemCameraTip: Tip {
    var title: Text { Text("CreateItemTip.CameraTitle") }
    var message: Text? { Text("CreateItemTip.CameraMessage") }
    var image: Image? { Image(systemName: "camera.fill") }
    var options: [Option] {
        MaxDisplayCount(1)
        IgnoresDisplayFrequency(true)
    }
}

struct CreateItemSensitivityTip: Tip {
    @TipKit.Parameter static var countdownAborts: Int = 0
    var rules: [Rule] { #Rule(Self.$countdownAborts) { $0 >= 3 } }
    var title: Text { Text("FeedSensitivity.Title") }
    var message: Text? { Text("CreateItemTip.SensitivityMessage") }
    var image: Image? { Image(systemName: "cellularbars") }
    var options: [Option] {
        MaxDisplayCount(1)
        IgnoresDisplayFrequency(true)
    }
}

struct CreateItemDictationTip: Tip {
    var title: Text { Text("CreateItem.Dictation") }
    var message: Text? { Text("CreateItem.DictationMessage") }
    var image: Image? { Image(systemName: "microphone.fill") }
    var options: [Option] {
        MaxDisplayCount(1)
        IgnoresDisplayFrequency(true)
    }
}


/// Ein eigener Tipp reagiert auf die erste tatsächliche Anpassung, unabhängig
/// von der Reihenfolge der Kamera-Erklärungen und von Countdown-Abbrüchen.
struct CreateAutomaticSensitivityTip: Tip {
    @TipKit.Parameter static var wasAdjusted: Bool = false
    var rules: [Rule] { #Rule(Self.$wasAdjusted) { $0 == true } }
    var title: Text { Text("CreateItemTip.AutomaticSensitivityTitle") }
    var message: Text? { Text("CreateItemTip.AutomaticSensitivityMessage") }
    var image: Image? { Image(systemName: "wand.and.sparkles.inverse") }
    var options: [Option] { MaxDisplayCount(1); IgnoresDisplayFrequency(true) }
}

import SwiftUI
import TipKit

/// TipKit speichert die einmalige Anzeige gemeinsam für beide Kistenfelder.
struct CreateQRCodeTip: Tip {
    var title: Text { Text("CreateCamera.QRRecognized") }
    var message: Text? { Text("CreateCamera.BoxAdjusted") }
    var image: Image? { Image(systemName: "qrcode") }
    var options: [Option] {
        MaxDisplayCount(1)
        IgnoresDisplayFrequency(true)
    }
}

/// Erst eine tatsächlich übernommene QR-Zuordnung gibt den Tipp am Feld frei.
/// Wiederholte Scans derselben Kiste erzeugen kein Ereignis für diesen Anker.
struct CreateQRCodeInfo: ViewModifier {
    let eventID: UUID?

    func body(content: Content) -> some View {
        content.popoverTip(eventID == nil ? nil : CreateQRCodeTip(), arrowEdge: .top)
    }
}

/// Nur erfolgreiche Änderungen erzeugen einen Hinweis; ignorierte Codes liefern kein Ereignis.
struct CreateQRCodeAction: Equatable {
    let id: UUID
    let boxName: String
}

/// Der Timer hängt am stabilen Formular, nicht an einer ausgetauschten Hinweis-View.
/// Schnelle Folgescans ersetzen Text und Frist und können keinen alten Hinweis stehen lassen.
struct CreateQRCodeActionFeedback: ViewModifier {
    let action: CreateQRCodeAction?
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isVisible, let action {
                    CreateAutomaticThresholdNotice(symbol: "qrcode.viewfinder",
                                                   message: "CreateItem.BoxRecognized", detail: action.boxName)
                        .padding(.horizontal, 16)
                }
            }
            .task(id: action?.id) {
                isVisible = action != nil
                guard action != nil else { return }
                do { try await Task.sleep(for: .seconds(3)) }
                catch { return }
                withAnimation(.easeInOut(duration: 0.2)) { isVisible = false }
            }
    }
}

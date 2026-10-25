import SwiftUI

/// Alle Inventarlisten teilen denselben Picker außerhalb des wechselnden Inhalts.
/// Die obere Safe-Area-Einfügung reserviert seine tatsächliche Höhe automatisch.
struct FirstTabPickerLayout: ViewModifier {
    @Binding var selection: String
    let isVisible: Bool
    let position: String
    let isSelecting: Bool

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if isVisible && position == "Top" {
                    picker
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                        .padding(.bottom, 8)
                }
            }
            .overlay {
                if isVisible && position != "Top" && (position != "Bottom" || !isSelecting) {
                    picker
                        .frame(width: isVertical ? 150 : nil, height: isVertical ? 40 : nil)
                        .rotationEffect(.degrees(isVertical ? 90 : 0))
                        // Nach der Drehung auch den Layout-Rahmen drehen, damit
                        // die seitliche Position ohne manuelle Offsets auskommt.
                        .frame(width: isVertical ? 40 : nil, height: isVertical ? 150 : nil)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 5)
                }
            }
    }

    private var picker: some View {
        listPicker(selection: $selection)
    }

    private var isVertical: Bool {
        position == "Left" || position == "Right"
    }

    private var alignment: Alignment {
        switch position {
        case "Left": return .leading
        case "Right": return .trailing
        default: return .bottom
        }
    }
}

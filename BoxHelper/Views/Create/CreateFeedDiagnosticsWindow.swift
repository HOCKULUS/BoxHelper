import SwiftUI

/// Eigenständiges, quadratisches Fenster über dem Formular. Die Kopfzeile ist der
/// Drag-Bereich, damit die scrollbaren Messwerte und die Schließtaste bedienbar bleiben.
struct CreateFeedDiagnosticsWindow: View {
    let snapshot: FeedDiagnosticsSnapshot
    let close: () -> Void
    @State private var center: CGPoint?
    @GestureState private var translation = CGSize.zero

    var body: some View {
        GeometryReader { geometry in
            let side = max(1, min(320, min(geometry.size.width - 24, geometry.size.height - 24)))
            let initial = CGPoint(x: geometry.size.width - side / 2 - 12,
                                  y: min(geometry.size.height / 2, side / 2 + 90))
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FeedDiagnostics.Title").font(.headline)
                        Text(LocalizedStringKey(snapshot.phase.rawValue)).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .contentShape(Rectangle())
                    .gesture(DragGesture()
                        .updating($translation) { value, state, _ in state = value.translation }
                        .onEnded { value in
                            let origin = center ?? initial
                            center = clamped(CGPoint(x: origin.x + value.translation.width,
                                                     y: origin.y + value.translation.height), size: geometry.size, side: side)
                        })
                    Button(action: close) {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityLabel(Text("Schließen"))
                }
                .padding(.leading, 12)
                Divider()
                ScrollView { CreateFeedDiagnosticsOverlay(snapshot: snapshot) }
            }
            .frame(width: side, height: side)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.12)))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            .position(clamped(CGPoint(x: (center ?? initial).x + translation.width,
                                      y: (center ?? initial).y + translation.height), size: geometry.size, side: side))
            .onChange(of: geometry.size) { _, size in
                center = clamped(center ?? initial, size: size, side: side)
            }
        }
    }

    // Auch nach Rotation bleibt das Fenster vollständig erreichbar.
    private func clamped(_ point: CGPoint, size: CGSize, side: CGFloat) -> CGPoint {
        let inset = side / 2 + 12
        return CGPoint(x: min(max(inset, point.x), max(inset, size.width - inset)),
                       y: min(max(inset, point.y), max(inset, size.height - inset)))
    }
}

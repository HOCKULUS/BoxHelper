import SwiftUI

/// Bestätigt erst beim Loslassen am rechten Ende; ein kurzer Wisch springt zurück.
struct SlideToConfirmDeletion: View {
    var isDisabled = false
    var title: LocalizedStringKey = "Zum Löschen schieben"
    var accessibilityLabel: LocalizedStringKey = "Löschen bestätigen"
    var accessibilityIdentifier = "deletion.confirmSlider"
    var cancelAccessibilityIdentifier = "deletion.cancel"
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @ScaledMetric(relativeTo: .body) private var thumbSize: CGFloat = 48
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var isConfirmed = false
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let travel = max(0, geometry.size.width - thumbSize - 8)
            ZStack(alignment: .leading) {
                Capsule().fill(Color(uiColor: .tertiarySystemFill))
                // Hinter dem Griff wächst eine rein rote Fläche ohne Beschriftung.
                Capsule()
                    .fill(.red)
                    .frame(width: offset > 0 ? offset + thumbSize + 8 : 0)
                DeletionShimmerText(title: title, isPaused: reduceMotion || isDisabled)
                    .padding(.leading, thumbSize + 12)
                    .padding(.trailing, thumbSize + 12)
                    .frame(maxWidth: .infinity)
                    .opacity(1 - Double(travel > 0 ? offset / travel : 0))
                    .mask(alignment: .leading) {
                        HStack(spacing: 0) {
                            Color.clear.frame(width: offset + thumbSize + 8)
                            Rectangle()
                        }
                    }
                // Der Abbruchgriff sitzt spiegelbildlich auf derselben Bahn.
                // Während des Wischens und Zurückspringens bleibt er ausgeblendet.
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(width: thumbSize, height: thumbSize)
                        // Der native Gruppenhintergrund ist hell weiß und dunkel grau.
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                }
                .buttonStyle(.borderless)
                .padding(4)
                .offset(x: travel)
                .opacity(isDragging || offset > 0 ? 0 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isDragging)
                .allowsHitTesting(!isDragging && offset == 0)
                .accessibilityLabel("Abbrechen")
                .accessibilityIdentifier(cancelAccessibilityIdentifier)
                Image(systemName: "chevron.right.2")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .background(.red, in: Circle())
                    .padding(4)
                    .offset(x: offset)
                    .gesture(DragGesture().onChanged { value in
                        guard !isDisabled, !isConfirmed else { return }
                        if value.translation.width != 0 { isDragging = true }
                        offset = min(travel, max(0, value.translation.width))
                    }.onEnded { _ in
                        guard !isDisabled, !isConfirmed else { return }
                        if travel > 0 && offset >= travel * 0.95 {
                            confirm()
                        } else {
                            withAnimation(reduceMotion ? nil : .snappy) {
                                offset = 0
                            } completion: {
                                isDragging = false
                            }
                        }
                    })
            }
            .clipShape(Capsule())
        }
        .frame(height: thumbSize + 8)
        .opacity(isDisabled ? 0.5 : 1)
        .allowsHitTesting(!isDisabled && !isConfirmed)
        .onChange(of: isDisabled) { _, disabled in
            if disabled { offset = 0; isDragging = false }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Zum Bestätigen aktivieren")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { confirm() }
        .accessibilityAction(named: Text("Abbrechen")) { if !isConfirmed { onCancel() } }
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func confirm() {
        guard !isDisabled, !isConfirmed else { return }
        // Auch VoiceOver oder zwei unmittelbar aufeinanderfolgende Gesten starten nur einmal.
        isConfirmed = true
        onConfirm()
    }
}

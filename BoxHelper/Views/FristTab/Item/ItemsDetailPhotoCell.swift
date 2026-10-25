import SwiftUI
import UniformTypeIdentifiers

/// Eine Fotozelle öffnet entweder die Vorschau oder wählt ihre konkrete Referenz
/// aus. Im Auswahlmodus sind Drag-and-drop und Einzelbildlöschung abgeschaltet.
struct ItemsDetailPhotoCell: View {
    let image: UIImage?
    let position: Int
    let total: Int
    let isSelecting: Bool
    let isSelected: Bool
    let isEditing: Bool
    let pressAndHold: Bool
    let selectedColor: Color
    let reorderDelegate: SortedImageReorderDropDelegate
    let select: () -> Void
    let open: () -> Void
    let edit: () -> Void
    let delete: () -> Void
    let drag: () -> NSItemProvider

    var body: some View {
        ZStack(alignment: .topLeading) {
            if isSelecting {
                Button(action: select) { thumbnail }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(position) / \(total)"))
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            } else {
                Button(action: open) { thumbnail }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(position) / \(total)"))
                    .onDrag(drag)
                    .onDrop(of: [UTType.text], delegate: reorderDelegate)
                    .onLongPressGesture {
                        guard pressAndHold else { return }
                        edit()
                    }
            }

            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? selectedColor : .white)
                    .background(Circle().fill(isSelected ? Color.white : Color.black.opacity(0.45)))
                    .padding(5)
                    .allowsHitTesting(false)
            } else if isEditing {
                Button("Löschen", systemImage: "trash.circle.fill", role: .destructive, action: delete)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)))
                    .buttonStyle(.plain)
                    .padding(5)
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            if isSelecting && isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(selectedColor, lineWidth: 3)
            }
        }
    }

    private var thumbnail: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // Auch noch nicht geladene oder fehlende Fotos bleiben auswählbar.
                Color(UIColor.secondarySystemFill)
                    .overlay { ProgressView() }
            }
        }
        .frame(width: 84, height: 84)
        .clipped()
        .contentShape(Rectangle())
    }
}

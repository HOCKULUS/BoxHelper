import SwiftUI

/// A horizontal photo rail with the same dimensions and actions as the box setup form.
struct CreatePhotoStrip: View {
    let images: [UIImage]
    let openGallery: () -> Void
    var openCamera: (() -> Void)? = nil
    var leadingTile: AnyView? = nil
    var emptySlotCount: Int = 3
    let removeImage: (Int) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            VStack(spacing: 7) {
                sourceButton("photo.fill", label: "Fotos hinzufügen", action: openGallery)
                if let openCamera {
                    sourceButton("camera.fill", label: "Popup-Kamera öffnen", action: openCamera)
                }
            }
            ScrollView(.horizontal) {
                HStack {
                    // Item creation inserts its live camera before the stored photo thumbnails.
                    if let leadingTile { leadingTile }
                    if images.isEmpty {
                        // Explizite IDs erlauben auch eine veränderliche Anzahl von Platzhaltern.
                        ForEach(0..<emptySlotCount, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                                .frame(width: 84, height: 84)
                        }
                    } else {
                        ForEach(images.indices, id: \.self) { index in
                            Image(uiImage: images[index])
                                .resizable().scaledToFill()
                                .frame(width: 84, height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(alignment: .topLeading) {
                                    Button(role: .destructive) { removeImage(index) } label: {
                                        Image(systemName: "trash.circle.fill")
                                            .resizable().frame(width: 32, height: 32)
                                            .foregroundStyle(.white.opacity(0.8))
                                            .background(.black.opacity(0.5), in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Foto \(index + 1) löschen")
                                    .padding(3)
                                }
                        }
                    }
                }
            }
            .frame(height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            if !images.isEmpty { Text("\(images.count)") }
        }
        .padding(.vertical, 8)
    }

    private func sourceButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).resizable().scaledToFit().frame(width: 20, height: 20)
                .frame(width: 38, height: 38)
                .foregroundStyle(colorScheme == .dark ? .white : .black)
                .background(Color(UIColor.systemFill), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// OCR runs independently of this strip. It shows tags without a loading indicator.
struct CreateTagStrip: View {
    let tags: [String]
    let hasImages: Bool
    let color: Color
    let clear: () -> Void
    let recognize: () -> Void
    let block: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Button(action: tags.isEmpty ? recognize : clear) {
                Image(systemName: tags.isEmpty ? "text.viewfinder" : "trash")
                    .frame(width: 26, height: 26)
                    .foregroundStyle(tags.isEmpty ? tagTextColor : .white)
                    .background(tags.isEmpty ? color : .red, in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .disabled(!hasImages && tags.isEmpty)
            .accessibilityLabel(tags.isEmpty ? "Texterkennung" : "Tags löschen")
            ScrollView(.horizontal) {
                HStack {
                    if tags.isEmpty {
                        ForEach(0..<3) { _ in
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                                .frame(width: 75, height: 26)
                        }
                    } else {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Button { block(tag) } label: { Image(systemName: "nosign") }
                                    .buttonStyle(.plain).accessibilityLabel("Tag \(tag) blockieren")
                                Text(tag).font(.callout)
                            }
                            .padding(.horizontal, 8).frame(height: 26)
                            .foregroundStyle(tagTextColor)
                            .background(color, in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }
            }
        }
        .padding(.bottom, 5)
    }

    private var tagTextColor: Color { isColorTooDark(color: color) ? .white : .black }
}

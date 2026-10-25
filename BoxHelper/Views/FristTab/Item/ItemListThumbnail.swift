import SwiftUI

/// Zeilen halten nur ein kleines Vorschaubild. Dateizugriff und Dekodierung
/// erledigt der gemeinsame Worker außerhalb der Darstellung.
struct ItemListThumbnail: View {
    let imagePath: String?
    let side: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @ObservedObject private var storage = InventoryStorageState.shared
    @State private var image: UIImage?
    @State private var loadedPath: String?

    private var request: InventoryThumbnailLoader.Request? {
        imagePath.map { InventoryThumbnailLoader.Request(filename: $0, maxPixelSize: side * displayScale) }
    }

    var body: some View {
        Group {
            if loadedPath == imagePath, let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: side, height: side)
        .clipped()
        .task(id: request.map { InventoryThumbnailLoader.TaskIdentity(request: $0, mediaRevision: storage.mediaRevision) }) {
            guard let request else { image = nil; loadedPath = nil; return }
            if loadedPath != imagePath {
                image = InventoryThumbnailLoader.shared.cachedImage(for: request)
                loadedPath = imagePath
            }
            let result = await InventoryThumbnailLoader.shared.load(request, mediaRevision: storage.mediaRevision)
            guard !Task.isCancelled else { return }
            loadedPath = imagePath
            image = result
        }
    }

    private var placeholder: some View {
        // Die Fläche füllt den gesamten Bildrahmen; das Seitenverhältnis des
        // Foto-Symbols darf die Höhe des Platzhalter-Hintergrunds nicht verkleinern.
        (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
            .overlay {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .padding(.leading, 4)
                    .padding(10)
                    .foregroundStyle(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.3))
            }
    }
}

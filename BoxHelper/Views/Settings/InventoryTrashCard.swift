import SwiftUI
import ImageIO

struct InventoryTrashCard: View {
    let entry: InventoryTrashEntry
    let photo: Data?
    let retentionDays: Int
    let restore: () -> Void
    let delete: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    if let thumbnail {
                        Image(uiImage: thumbnail).resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        LinearGradient(colors: [.black.opacity(0.08), .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    } else {
                        Image(systemName: entry.symbol)
                            .font(.system(size: 40))
                            .foregroundStyle(.tint.opacity(0.2))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                Image(systemName: entry.symbol)
                    .font(.caption.bold())
                    .padding(7)
                    .background(.regularMaterial, in: Circle())
                    .padding(10)
            }
            .overlay(alignment: .topTrailing) {
                Menu {
                    Button("Trash.Restore", systemImage: "arrow.uturn.backward", action: restore)
                    Button("Trash.Delete", systemImage: "trash", role: .destructive, action: delete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.bold())
                        .frame(width: 32, height: 32)
                        .background(.regularMaterial, in: Circle())
                }
                .padding(8)
                .accessibilityLabel(Text("Trash.CardActions \(entry.name)"))
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name).font(.subheadline.bold()).lineLimit(1)
                    Text(entry.deletedAt.addingTimeInterval(Double(retentionDays) * 86_400), style: .date)
                        .font(.caption2).lineLimit(1)
                    if entry.source == .cloud { Text("Trash.CloudDeletion").font(.caption2).lineLimit(1) }
                }
                .foregroundStyle(thumbnail == nil ? Color.primary : .white)
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .task(id: photo) {
                // Nur kleine Vorschauen materialisieren; große Originalfotos bleiben
                // für die Wiederherstellung im Archiv und blockieren kein Scrolling.
                guard let photo else { thumbnail = nil; return }
                thumbnail = await Task.detached(priority: .utility) {
                    guard let source = CGImageSourceCreateWithData(photo as CFData, nil),
                          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceCreateThumbnailWithTransform: true,
                            kCGImageSourceThumbnailMaxPixelSize: 480
                          ] as CFDictionary) else { return Optional<UIImage>.none }
                    return UIImage(cgImage: image)
                }.value
            }
    }
}

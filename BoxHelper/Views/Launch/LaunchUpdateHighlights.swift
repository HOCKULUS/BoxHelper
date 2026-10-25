import SwiftUI

/// Kurze, lokalisierte Update-Notizen für die aktuelle Ausgabe.
struct LaunchUpdateHighlights: View {
    // Die Reihenfolge entspricht den Release-Notizen. Die IDs verknüpfen jede
    // Karte mit ihren manuell gepflegten Titeln und Texten im String-Katalog.
    private let updates: [(id: String, symbol: String)] = [
        ("Cloud", "icloud.fill"),
        ("Handoff", "arrow.triangle.2.circlepath"),
        ("Forms", "square.and.pencil"),
        ("Automatic", "camera.fill"),
        ("Dictation", "microphone.fill"),
        ("Shortcuts", "bolt.fill"),
        ("Lists", "arrow.up.arrow.down"),
        ("QRCode", "qrcode.viewfinder"),
        ("Images", "photo.on.rectangle.angled"),
        ("Spotlight", "magnifyingglass"),
        ("Bugs", "ladybug.fill")
    ]

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            Text("Launch5.UpdatesTitle")
                .font(.title2.weight(.bold)).padding(.horizontal, 4)
            ForEach(updates, id: \.id) { update in
                HStack(alignment: .top, spacing: 15) {
                    Image(systemName: update.symbol)
                        .font(.system(size: 20, weight: .semibold)).foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(Color.blue.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 7) {
                        Text(LocalizedStringKey("Launch5." + update.id + ".Title")).font(.headline)
                        Text(LocalizedStringKey("Launch5." + update.id + ".Body"))
                            .font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20).modifier(LaunchCardSurface())
            }
        }
    }
}

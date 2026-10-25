import SwiftUI

/// Der Support-Aufruf folgt der bisherigen Open-Source-Karte mit GitHub-Logo.
struct LaunchSupportCard: View {
    private let repository = URL(string: "https://github.com/HOCKULUS/BoxHelper")!
    private let review = URL(string: "https://apps.apple.com/app/boxhelper/id6737223705?action=write-review")!

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Launch5.SupportTitle").font(.title2.weight(.bold))
                Text("Launch5.SupportMessage").foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Link(destination: repository) {
                HStack(spacing: 8) {
                    Image("GitHub_Invertocat_White").resizable().scaledToFit().frame(width: 18, height: 18)
                    Text("Launch5.SupportAction")
                }
                .font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: LaunchLayout.cardCornerRadius))
            .tint(.blue)
            Link(destination: review) {
                Label("Launch5.ReviewAction", systemImage: "star.bubble.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: LaunchLayout.cardCornerRadius))
            .tint(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .modifier(LaunchCardSurface())
    }
}

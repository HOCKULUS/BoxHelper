import SwiftUI

/// Ein kurzer Release-Hinweis für die Anfangsszene, unabhängig vom iCloud-Status.
struct LaunchCloudFeatureBadge: View {
    var body: some View {
        Text("Launch5.CloudFeature")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.blue)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .fixedSize(horizontal: false, vertical: true)
            .modifier(LaunchCardSurface())
    }
}

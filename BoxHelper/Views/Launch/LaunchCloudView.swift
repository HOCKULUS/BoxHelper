import SwiftUI

/// Weißes Wolkensymbol mit starkem Hintergrundblur innerhalb seiner Silhouette.
struct LaunchCloudView: View {
    let width: CGFloat
    let backdropBlurIntensity: Double

    private var symbol: some View {
        Image(systemName: "icloud.fill")
            .resizable()
            .scaledToFit()
            .frame(width: width, height: width * 0.72)
    }

    var body: some View {
        // Der native Blur wirkt auf die Inhalte hinter der Wolke, statt nur
        // das Symbol weichzuzeichnen. Die weiße Füllung erhält den Wolkencharakter.
        LaunchCloudBackdropBlur(intensity: backdropBlurIntensity)
            .overlay(Color.white.opacity(0.45))
            .frame(width: width, height: width * 0.72)
            .mask(symbol)
    }
}

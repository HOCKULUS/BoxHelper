import SwiftUI

/// The preview keeps one position and size; readiness changes only the placeholder overlay.
struct CreateCameraFeedTile: View {
    @ObservedObject var camera: EmbeddedItemCamera
    let isFeedEnabled: Bool
    let isAutomaticActive: Bool
    var markingStyle: FeedObjectMarkingStyle = .hidden

    var body: some View {
        EmbeddedCameraPreview(camera: camera)
            .frame(width: CreateItemPhotoLayout.height, height: CreateItemPhotoLayout.height)
            .background(Color(UIColor.systemFill))
            .overlay {
                if !isFeedEnabled {
                    Color(UIColor.systemFill)
                        .overlay { Image(systemName: "eye.slash").foregroundStyle(.secondary) }
                } else if !camera.isReady {
                    Color(UIColor.systemFill)
                        .overlay { Image(systemName: "camera.fill").foregroundStyle(.secondary) }
                }
            }
            .overlay {
                if isFeedEnabled, camera.isReady, markingStyle != .hidden {
                    CreateObjectRegionsOverlay(regions: camera.saliencyRegions, style: markingStyle)
                }
            }
            // Markierungen liegen unter dem Leuchteffekt und werden an denselben Feed-Ecken beschnitten.
            .clipShape(RoundedRectangle(cornerRadius: 52 * CreateItemPhotoLayout.height / 393, style: .continuous))
            .modifier(AppleIntelligenceFeedGlow(isActive: isAutomaticActive))
            .frame(width: CreateItemPhotoLayout.height, height: CreateItemPhotoLayout.height)
            .accessibilityLabel("Kameravorschau")
            .allowsHitTesting(false)
    }
}

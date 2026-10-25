import SwiftUI

/// Shared dimensions keep the preview exactly as high as two thumbnails and their spacing.
enum CreateItemPhotoLayout {
    static let thumbnail: CGFloat = 84
    static let spacing: CGFloat = 8
    static let height = thumbnail * 2 + spacing
}

/// The fixed preview sits left of the two-row photo rail.
struct CreateItemPhotoPanel: View {
    @ObservedObject var camera: EmbeddedItemCamera
    let isFeedEnabled: Bool
    var isAutomaticActive = false
    var isAutomaticRunning = false
    var referenceFeedback: CameraReferenceFeedbackState = .hidden
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(FeedObjectMarkingStyle.storageKey) private var markingStyle = FeedObjectMarkingStyle.hidden
    let toggleDiagnostics: () -> Void
    @State private var diagnosticsTaps = FeedDiagnosticsTapSequence()
    let images: [UIImage]
    let openGallery: () -> Void
    let openCamera: () -> Void
    let toggleFeed: () -> Void
    let rotateFeed: () -> Void
    let removeImage: (Int) -> Void
    private let rows = [GridItem(.fixed(CreateItemPhotoLayout.thumbnail), spacing: CreateItemPhotoLayout.spacing),
                        GridItem(.fixed(CreateItemPhotoLayout.thumbnail), spacing: CreateItemPhotoLayout.spacing)]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            CreateCameraFeedTile(camera: camera, isFeedEnabled: isFeedEnabled, isAutomaticActive: isAutomaticActive, markingStyle: markingStyle)
                .overlay {
                    // Eigene Tippfläche über der nicht interaktiven Kameravorschau.
                    // Die später aufgelegten Feed-Buttons behalten ihre eigenen Aktionen.
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture {
                            let togglesDiagnostics = diagnosticsTaps.record(at: ProcessInfo.processInfo.systemUptime)
                            // Die Auswahl bleibt auch nach Pausen, Formularwechseln
                            // und einem App-Neustart für beide Kamerafeeds erhalten.
                            markingStyle = markingStyle.next
                            if togglesDiagnostics { toggleDiagnostics() }
                        }
                }
                .overlay {
                    if referenceFeedback != .hidden { CreateCameraReferenceFeedback(state: referenceFeedback) }
                }
                .overlay(alignment: .bottom) {
                    // Gleich breite Tippbereiche verteilen die kleineren Buttons gleichmäßig im Feed.
                    HStack(spacing: 0) {
                        sourceButton("photo.fill", label: "Fotos hinzufügen", action: openGallery)
                        sourceButton("camera.fill", label: "Popup-Kamera öffnen", action: openCamera)
                        sourceButton(isFeedEnabled ? "eye" : "eye.slash",
                                     label: isFeedEnabled ? "Live-Kamera ausschalten" : "Live-Kamera einschalten",
                                     action: toggleFeed)
                        sourceButton("arrow.clockwise", label: "Live-Feed für zukünftige Kamerafotos um 90 Grad drehen",
                                     action: rotateFeed)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                    // Bereits während der Referenzaufnahme ausblenden und unsichtbare
                    // Aktionen für Touch und VoiceOver sperren.
                    .opacity(isAutomaticRunning ? 0 : 1)
                    .allowsHitTesting(!isAutomaticRunning)
                    .accessibilityHidden(isAutomaticRunning)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isAutomaticRunning)
                }
            ScrollView(.horizontal) {
                LazyHGrid(rows: rows, spacing: 8) {
                    if images.isEmpty {
                        ForEach(0..<4) { _ in
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(UIColor.systemFill))
                                .frame(width: CreateItemPhotoLayout.thumbnail, height: CreateItemPhotoLayout.thumbnail)
                        }
                    } else {
                        ForEach(images.indices, id: \.self) { index in
                            Image(uiImage: images[index])
                                .resizable().scaledToFill()
                                .frame(width: CreateItemPhotoLayout.thumbnail, height: CreateItemPhotoLayout.thumbnail)
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
            .frame(height: CreateItemPhotoLayout.height)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }

    private func sourceButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 32, height: 32)
                .foregroundStyle(.white)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

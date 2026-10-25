import Foundation
import UIKit

/// The worker creates immutable photos; only the receiving view changes UI state.
struct CreateDraftPhotos: @unchecked Sendable {
    let images: [UIImage]
    let locationPhoto: UIImage?
}

enum CreateDraftImageLoader {
    static func load(imageURLs: [URL], locationURL: URL? = nil) async -> CreateDraftPhotos {
        await Task.detached(priority: .userInitiated) {
            func loadPhoto(_ url: URL) -> UIImage? {
                guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
                // Decode before returning so the first photo-row layout does not do the work on main.
                return image.preparingForDisplay() ?? image
            }
            return CreateDraftPhotos(images: imageURLs.compactMap(loadPhoto),
                                     locationPhoto: locationURL.flatMap(loadPhoto))
        }.value
    }
}

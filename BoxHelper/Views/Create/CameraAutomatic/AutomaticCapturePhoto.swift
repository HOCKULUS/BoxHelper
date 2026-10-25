import UIKit

/// Ein unveränderliches Foto darf zum Verkleinern und JPEG-Kodieren auf den Worker wechseln.
struct AutomaticCapturePhoto: @unchecked Sendable {
    let image: UIImage
    let data: Data

    private struct Input: @unchecked Sendable { let image: UIImage }

    static func prepare(_ photo: UIImage) async -> Self? {
        let input = Input(image: photo)
        return await Task.detached(priority: .userInitiated) {
            let storedSize = UserDefaults.standard.object(forKey: "sliderValue2") as? Double ?? 500
            let size = storedSize.isFinite && storedSize > 0 ? storedSize : 500
            guard let image = input.image.resizeImage(targetSize: CGSize(width: size, height: size)),
                  let data = image.compressImage() else { return nil }
            return Self(image: image, data: data)
        }.value
    }
}

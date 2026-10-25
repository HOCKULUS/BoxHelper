import CoreImage
import CoreVideo
import ImageIO
import Vision

/// Nur auf der Kamera-Queue verwenden. Vision erhält einen begrenzten Ausschnitt;
/// weder Kamera-Puffer noch vollständige Fotos werden als Referenzen gehalten.
final class FeedObjectFinder {
    private let context = CIContext(options: [.cacheIntermediates: false])
    // Nur kleine normalisierte Rechtecke verlassen die Kamera-Queue, keine Vision-Bilder.

    enum SamplingError: Error { case invalidFrame, missingObservation }

    func regions(in buffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> [CGRect] {
        return try autoreleasepool {
            let image = CIImage(cvPixelBuffer: buffer)
            let side = min(image.extent.width, image.extent.height)
            guard side > 0 else { throw SamplingError.invalidFrame }
            let crop = CGRect(x: image.extent.midX - side / 2, y: image.extent.midY - side / 2,
                              width: side, height: side)
            // Derselbe mittlere quadratische Ausschnitt wie die aspectFill-Vorschau.
            // Die 256-Pixel-Eingabe begrenzt Arbeit und temporären GPU-Speicher.
            let input = image.cropped(to: crop)
                .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
                .transformed(by: CGAffineTransform(scaleX: 256 / side, y: 256 / side))
            guard let thumbnail = context.createCGImage(input, from: CGRect(x: 0, y: 0, width: 256, height: 256)) else {
                throw SamplingError.invalidFrame
            }
            let request = VNGenerateObjectnessBasedSaliencyImageRequest()
            request.revision = VNGenerateObjectnessBasedSaliencyImageRequestRevision2
            request.preferBackgroundProcessing = true
            try VNImageRequestHandler(cgImage: thumbnail, orientation: orientation).perform([request])
            guard let observation = request.results?.first else { throw SamplingError.missingObservation }
            return (observation.salientObjects ?? []).compactMap { FeedSaliencyRegionGeometry.normalized($0.boundingBox) }
        }
    }
}

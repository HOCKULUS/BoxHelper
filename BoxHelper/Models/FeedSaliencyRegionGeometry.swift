import Foundation
import CoreGraphics

/// Vision nutzt normalisierte Koordinaten mit Ursprung unten links; die Vorschau
/// zeigt denselben quadratischen Ausschnitt mit Ursprung oben links.
enum FeedSaliencyRegionGeometry {
    static func normalized(_ region: CGRect) -> CGRect? {
        guard [region.origin.x, region.origin.y, region.width, region.height].allSatisfy(\.isFinite),
              region.width > 0, region.height > 0 else { return nil }
        let clipped = region.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        return clipped.isNull || clipped.isEmpty ? nil : clipped
    }

    static func previewRect(_ region: CGRect, size: CGSize) -> CGRect? {
        guard let region = normalized(region) else { return nil }
        return CGRect(x: region.minX * size.width, y: (1 - region.maxY) * size.height,
                      width: region.width * size.width, height: region.height * size.height)
    }
}

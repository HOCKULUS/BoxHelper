import UIKit

/// Die QR-Bilder werden einmal je Kiste erzeugt und in der PDF mehrfach gezeichnet.
/// So wächst der Bildspeicher nicht mit der Anzahl der Kopien.
enum BoxBatchPrintDocument {
    enum RenderingError: Error { case missingCode }

    static func render(boxes: [MovingBox], locations: [Locations], settings: BoxBatchPrintSettings) throws -> Data {
        let images = try boxes.map { box -> UIImage in
            let location = locations.first { $0.id == box.location_uuid }
            guard let image = generateQRCodeForBoxPreview(box.id, text: box.name, standort: location?.name ?? "",
                dynamicQRCode: settings.dynamic, showQRCodeLogo: settings.logo,
                showQRCodeLocation: settings.location, showQRCodeName: settings.name,
                showQRCodeLocationColor: settings.locationColor, showTinyQRCode: settings.tiny,
                horizontalQRCodeLayout: settings.horizontal, useShortURL: settings.shortURL,
                standortColor: location.flatMap { stringToColor($0.color).map { UIColor($0) } }) else {
                throw RenderingError.missingCode
            }
            return image
        }
        let entries = images.indices.flatMap { Array(repeating: $0, count: settings.copies) }
        let slots = QRBatchPrintLayout.slots(perPage: settings.perPage)
        let pages = QRBatchPrintLayout.pages(of: entries, perPage: settings.perPage)
        return UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: QRBatchPrintLayout.pageSize)).pdfData { context in
            for page in pages {
                context.beginPage()
                for (slot, index) in zip(slots, page) {
                    draw(images[index], in: slot, rotate: settings.perPage == 2 || settings.perPage == 8)
                }
            }
        }
    }

    private static func draw(_ image: UIImage, in slot: CGRect, rotate: Bool) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: slot.midX, y: slot.midY)
        if rotate { context.rotate(by: .pi / 2) }
        let available = rotate ? CGSize(width: slot.height, height: slot.width) : slot.size
        let scale = min(available.width / image.size.width, available.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
    }
}

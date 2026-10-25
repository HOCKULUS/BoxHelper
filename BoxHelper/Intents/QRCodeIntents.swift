import AppIntents
import UIKit
import UniformTypeIdentifiers

/// Use the same layout and QR settings as the app's printing screen.
@MainActor
private enum IntentQRCodeExport {
    static func file(for box: MovingBox) throws -> IntentFile {
        let location = try InventoryPersistence.loadLocations().first { $0.id == box.location_uuid }
        let color = location.flatMap { stringToColor($0.color) }.map { UIColor($0) }
        guard let image = generateQRCodeForBox(box.id, text: box.name, standort: location?.name ?? "", standortColor: color),
              let data = image.pngData() else { throw IntentInventoryError.invalidImage }
        return IntentFile(data: data, filename: "\(box.id.uuidString)-QRCode.png", type: .png)
    }
}

struct GetBoxQRCodeIntent: AppIntent {
    static let title = LocalizedStringResource("Get box QR code")
    static let description = IntentDescription("Generate a box QR code as a PNG file using the app's QR settings. The file can be saved, shared, or printed.")
    @Parameter(title: "Name or ID") var boxReference: String

    static var parameterSummary: some ParameterSummary {
        Summary("Get QR code of box \(\.$boxReference)")
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<IntentFile> {
        let box = try IntentInventoryLookup.resolve(boxReference, in: try InventoryPersistence.loadBoxes(), name: { $0.name })
        return .result(value: try IntentQRCodeExport.file(for: box))
    }
}

struct GetBoxQRCodesIntent: AppIntent {
    static let title = LocalizedStringResource("Get box QR codes")
    static let description = IntentDescription("Generate PNG QR codes for multiple boxes. Returns image files for saving, sharing, or printing.")
    @Parameter(title: "Box names or IDs") var boxReferences: [String]

    static var parameterSummary: some ParameterSummary {
        Summary("Get QR codes of boxes \(\.$boxReferences)")
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<[IntentFile]> {
        let boxes = try InventoryPersistence.loadBoxes()
        // Validate the entire selection before generating any output.
        let selected = try boxReferences.map {
            try IntentInventoryLookup.resolve($0, in: boxes, name: { $0.name })
        }
        return .result(value: try selected.map { try IntentQRCodeExport.file(for: $0) })
    }
}

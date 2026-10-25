import CoreVideo

/// Nur 64 × 64 Helligkeitswerte kopieren; Kamera-Puffer werden sofort wieder freigegeben.
enum FeedLuminanceSampler {
    static func sample(_ buffer: CVPixelBuffer) -> [UInt8]? {
        guard CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let format = CVPixelBufferGetPixelFormatType(buffer)
        let planar = format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            || format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        guard planar || format == kCVPixelFormatType_32BGRA else { return nil }
        let width = planar ? CVPixelBufferGetWidthOfPlane(buffer, 0) : CVPixelBufferGetWidth(buffer)
        let height = planar ? CVPixelBufferGetHeightOfPlane(buffer, 0) : CVPixelBufferGetHeight(buffer)
        let stride = planar ? CVPixelBufferGetBytesPerRowOfPlane(buffer, 0) : CVPixelBufferGetBytesPerRow(buffer)
        guard width > 0, height > 0,
              let address = planar ? CVPixelBufferGetBaseAddressOfPlane(buffer, 0) : CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let bytes = address.assumingMemoryBound(to: UInt8.self)
        // Die quadratische Vorschau nutzt aspectFill: nur den sichtbaren mittleren Ausschnitt vergleichen.
        let side = min(width, height)
        let left = (width - side) / 2
        let top = (height - side) / 2
        var result: [UInt8] = []
        result.reserveCapacity(4096)
        for row in 0..<64 {
            let y = top + min(side - 1, (row * 2 + 1) * side / 128)
            for column in 0..<64 {
                let x = left + min(side - 1, (column * 2 + 1) * side / 128)
                if planar {
                    let value = Int(bytes[y * stride + x])
                    result.append(format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                                  ? UInt8(min(255, max(0, (value - 16) * 255 / 219))) : UInt8(value))
                } else {
                    let pixel = y * stride + x * 4
                    result.append(UInt8((Int(bytes[pixel + 2]) * 77 + Int(bytes[pixel + 1]) * 150 + Int(bytes[pixel]) * 29) / 256))
                }
            }
        }
        return result
    }
}

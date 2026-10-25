import Foundation
import CoreGraphics

/// Ein durchgehender Auftrag, unabhängig von den Grenzen einzelner Kisten.
/// Vorschau und PDF verwenden dieselben Seiten und Positionen.
enum QRBatchPrintLayout {
    static let pageSize = CGSize(width: 595, height: 842)

    static func pages<T>(of entries: [T], perPage: Int) -> [[T]] {
        let count = max(1, perPage)
        return stride(from: 0, to: entries.count, by: count).map {
            Array(entries[$0..<min(entries.count, $0 + count)])
        }
    }

    static func slots(perPage: Int) -> [CGRect] {
        let count = max(1, perPage)
        let margin = 28.35, spacing = 20.0
        let width = Double(pageSize.width) - 2 * margin
        let height = Double(pageSize.height) - 2 * margin
        if count == 8 {
            // Dieselben Etikettenmaße wie in den bestehenden QR-Layout-Einstellungen.
            return (0..<8).map { index in
                CGRect(x: 45.84 + Double(index % 2) * (97 * 2.3 + 60.08),
                       y: 55 + Double(index / 2) * (67.7 * 2.3 + 37),
                       width: 97 * 2.3, height: 67.7 * 2.3)
            }
        }
        let columns = count == 2 ? 1 : Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(columns)))
        let cellWidth = (width - Double(columns - 1) * spacing) / Double(columns)
        let cellHeight = (height - Double(rows - 1) * spacing) / Double(rows)
        return (0..<count).map { index in
            CGRect(x: margin + Double(index % columns) * (cellWidth + spacing),
                   y: margin + Double(index / columns) * (cellHeight + spacing),
                   width: cellWidth, height: cellHeight)
        }
    }
}

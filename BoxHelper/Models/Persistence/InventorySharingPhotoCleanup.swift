import CryptoKit
import Foundation

/// Geteilte Fotos erst nach dem bestätigten Inventar-Commit entfernen. Die alte
/// Prüfsumme beweist, welche Dateiversion zur gelöschten Freigabe gehört hat.
enum InventorySharingPhotoCleanup {
    struct Candidate: Codable, Sendable {
        let filename: String
        let digest: String
    }

    static func prepare(_ candidates: [Candidate], retaining references: Set<String>,
                        documents: URL) throws -> InventoryPhotoTransaction? {
        var changes: [InventoryPhotoTransaction.Change] = []
        for candidate in candidates where !references.contains(candidate.filename) {
            try Task.checkCancellation()
            let url = try InventorySharingPreparation.photoURL(candidate.filename, documents: documents)
            guard let bytes = try InventoryPhotoFileCoordinator.read(url).data else { continue }
            // Eine zwischenzeitlich bearbeitete oder private gleichnamige Datei gehört
            // nicht mehr zu diesem Löschauftrag und bleibt auf dem Gerät erhalten.
            let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            guard digest == candidate.digest else { continue }
            changes.append(.init(url: url, original: bytes, replacement: nil))
        }
        return changes.isEmpty ? nil : try InventoryPhotoTransaction.prepare(changes)
    }
}

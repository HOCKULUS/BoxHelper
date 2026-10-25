import Foundation

/// Gemeinsame Auflösung eingehender QR-Links, unabhängig von Navigation und Speicherung.
struct IncomingBoxURLResolution {
    let resolvedUUIDString: String?
    let matchingBoxes: [MovingBox]
    let usedShortURL: Bool

    var hasMultipleMatches: Bool {
        matchingBoxes.count > 1
    }
}

private enum IncomingBoxIdentifier {
    case fullUUID(String)
    case shortPrefix(String)
}

// Unterstützt alte Links (boxhelper://box/<UUID>) und neue ShortURLs (b0xh://<PREFIX>).
func resolveIncomingBoxURL(_ url: URL, boxes: [MovingBox]) -> IncomingBoxURLResolution {
    guard let identifier = extractBoxIdentifier(from: url) else {
        return IncomingBoxURLResolution(resolvedUUIDString: nil, matchingBoxes: [], usedShortURL: false)
    }

    switch identifier {
    case .fullUUID(let uuidString):
        guard let uuid = UUID(uuidString: uuidString) else {
            return IncomingBoxURLResolution(resolvedUUIDString: nil, matchingBoxes: [], usedShortURL: false)
        }
        return IncomingBoxURLResolution(resolvedUUIDString: uuid.uuidString, matchingBoxes: [], usedShortURL: false)

    case .shortPrefix(let prefix):
        let normalizedPrefix = prefix.uppercased()
        let matches = boxes.filter { box in
            box.id.uuidString.uppercased().hasPrefix(normalizedPrefix)
        }

        let resolvedUUIDString: String?
        // Kamera und eingehende Links verwenden dieselbe Wiederverwendung:
        // unbekannte Präfixe bekommen eine neue UUID, Kollisionen bleiben offen.
        switch FeedBoxQRCode.shortID(normalizedPrefix).resolve(existingIDs: boxes.map(\.id)) {
        case .existing(let id), .missing(let id):
            resolvedUUIDString = id.uuidString
        case .ambiguous:
            resolvedUUIDString = nil
        }

        return IncomingBoxURLResolution(
            resolvedUUIDString: resolvedUUIDString,
            matchingBoxes: matches,
            usedShortURL: true
        )
    }
}

// Funktion zum Extrahieren der Box-ID aus der URL
func extractBoxID(from url: URL) -> String? {
    guard let identifier = extractBoxIdentifier(from: url) else { return nil }
    switch identifier {
    case .fullUUID(let value), .shortPrefix(let value):
        return value
    }
}

private func extractBoxIdentifier(from url: URL) -> IncomingBoxIdentifier? {
    let scheme = url.scheme?.lowercased() ?? ""

    if scheme == "boxhelper" {
        if let fullUUID = extractLegacyUUID(from: url.absoluteString) {
            return .fullUUID(fullUUID)
        }
        return nil
    }

    if scheme == "b0xh" {
        let rawPrefix: String
        if let host = url.host, !host.isEmpty {
            rawPrefix = host
        } else {
            rawPrefix = String(url.path.drop(while: { $0 == "/" }))
        }

        let normalizedPrefix = rawPrefix
            .uppercased()
            .filter { "0123456789ABCDEF".contains($0) }

        guard normalizedPrefix.count == 8 else { return nil }
        return .shortPrefix(normalizedPrefix)
    }

    return nil
}

private func extractLegacyUUID(from urlString: String) -> String? {
    guard let lastSlashIndex = urlString.lastIndex(of: "/") else { return nil }
    let boxIDString = String(urlString[urlString.index(after: lastSlashIndex)...])
    return boxIDString
}

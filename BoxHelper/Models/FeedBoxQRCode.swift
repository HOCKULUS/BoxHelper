import Foundation

/// Nur die beiden von BoxHelper erzeugten Formate dürfen die Kistenauswahl ändern.
enum FeedBoxQRCode: Equatable, Sendable {
    case fullID(UUID)
    case shortID(String)

    init?(payload: String) {
        guard let url = URLComponents(string: payload), url.user == nil, url.password == nil,
              url.port == nil, url.query == nil, url.fragment == nil else { return nil }
        switch url.scheme?.lowercased() {
        case "boxhelper":
            guard url.host?.lowercased() == "box", url.path.hasPrefix("/"),
                  let id = UUID(uuidString: String(url.path.dropFirst())) else { return nil }
            self = .fullID(id)
        case "b0xh":
            guard url.path.isEmpty, let prefix = url.host?.uppercased(), prefix.count == 8,
                  prefix.allSatisfy({ "0123456789ABCDEF".contains($0) }) else { return nil }
            self = .shortID(prefix)
        default:
            return nil
        }
    }

    /// Mehrdeutige Kurzlinks dürfen keine beliebige vorhandene Kiste auswählen.
    func resolve(existingIDs: [UUID]) -> Resolution {
        switch self {
        case .fullID(let id):
            return existingIDs.contains(id) ? .existing(id) : .missing(id)
        case .shortID(let prefix):
            let matches = existingIDs.filter { $0.uuidString.hasPrefix(prefix) }
            if matches.count > 1 { return .ambiguous }
            if let id = matches.first { return .existing(id) }
            // Die ursprüngliche UUID lässt sich nicht rekonstruieren. Eine neue
            // UUID mit demselben Präfix macht das alte Etikett wieder nutzbar.
            let replacement = prefix + String(UUID().uuidString.dropFirst(8))
            return .missing(UUID(uuidString: replacement)!)
        }
    }

    /// Wiederholungen und bestehende Kisten im Kistenformular bleiben vollständig ohne Wirkung.
    /// Bei Kurzlinks vor der Auflösung vergleichen: ein noch nicht gespeicherter Entwurf
    /// würde sonst bei jedem Scan eine andere Ersatz-UUID bekommen.
    func target(existingIDs: [UUID], currentID: UUID?, allowExisting: Bool) -> Resolution? {
        if let currentID {
            switch self {
            case .fullID(let id) where id == currentID: return nil
            case .shortID(let prefix) where currentID.uuidString.hasPrefix(prefix): return nil
            default: break
            }
        }
        switch resolve(existingIDs: existingIDs) {
        case .existing(let id): return allowExisting ? .existing(id) : nil
        case .missing(let id): return .missing(id)
        case .ambiguous: return nil
        }
    }

    enum Resolution: Equatable {
        case existing(UUID)
        case missing(UUID)
        case ambiguous
    }

    static func fallbackName(for id: UUID) -> String {
        String(id.uuidString.prefix(6))
    }
}

/// Ein Code wird erst nach Verlassen des Bildes erneut gemeldet; einzelne
/// erfolglose Frames lassen den Hinweis nicht flackern oder erneut erscheinen.
struct FeedBoxQRCodePresence {
    private(set) var visibleCode: FeedBoxQRCode?
    private var lastSeenAt = -Double.infinity

    mutating func update(codes: [FeedBoxQRCode], at now: Double) -> Bool {
        if let visibleCode, codes.contains(visibleCode) {
            lastSeenAt = now
            return false
        }
        if let code = codes.first {
            visibleCode = code
            lastSeenAt = now
            return true
        }
        if now - lastSeenAt >= 0.8 { visibleCode = nil }
        return false
    }
}

struct FeedBoxQRCodeEvent: Equatable, Sendable {
    let id = UUID()
    let code: FeedBoxQRCode
}

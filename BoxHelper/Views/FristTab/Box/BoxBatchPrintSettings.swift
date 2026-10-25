import Foundation

/// Eine lokale Kopie der QR-Einstellungen. Änderungen werden absichtlich
/// nicht in UserDefaults zurückgeschrieben.
struct BoxBatchPrintSettings: Equatable {
    var perPage: Int
    var copies: Int
    var dynamic: Bool
    var logo: Bool
    var name: Bool
    var location: Bool
    var locationColor: Bool
    var shortURL: Bool
    var tiny: Bool
    var horizontal: Bool

    init(defaults: UserDefaults = .standard) {
        func flag(_ key: String, fallback: Bool = true) -> Bool { defaults.object(forKey: key) as? Bool ?? fallback }
        let layout = defaults.integer(forKey: "qrCodeNumber")
        perPage = [1, 2, 4, 8, 9, 16].contains(layout) ? layout : 1
        copies = min(99, max(1, defaults.integer(forKey: "qrCodeCopies")))
        dynamic = flag("dynamicQRCode")
        logo = flag("showQRCodeLogo")
        name = flag("showQRCodeName")
        location = flag("showQRCodeLocation")
        locationColor = flag("showQRCodeLocationColor")
        shortURL = flag("useShortQRCodeURL")
        tiny = flag("tinyQRCode", fallback: false)
        horizontal = flag("horizontalQRCodeLayout", fallback: false)
    }
}

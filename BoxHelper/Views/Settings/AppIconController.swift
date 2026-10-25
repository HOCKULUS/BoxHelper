import Darwin
import SwiftUI
import UIKit

/// Serialize public UIKit requests across all settings screens and ignore the already selected icon.
@MainActor
final class AppIconController: ObservableObject {
    static let shared = AppIconController()
    @Published private(set) var isChanging = false
    @Published private(set) var errorMessage: String?
    private var requestPending = false

    private init() {}

    func changeIcon(to requestedName: String?) {
        // Reserve synchronously without publishing; UIKit/SwiftUI may still be updating the button row.
        guard !requestPending, !isChanging else { return }
        requestPending = true
        DispatchQueue.main.async {
            self.requestPending = false
            self.beginIconChange(to: requestedName)
        }
    }

    func dismissError() {
        let displayedError = errorMessage
        // Alert bindings may be written during presentation updates. Notify observers on the next turn.
        DispatchQueue.main.async {
            if self.errorMessage == displayedError { self.errorMessage = nil }
        }
    }

    private func beginIconChange(to requestedName: String?) {
        let name = requestedName == "AppIcon" ? nil : requestedName
        let application = UIApplication.shared
        guard !isChanging, application.alternateIconName != name else { return }
        guard application.supportsAlternateIcons else {
            errorMessage = NSLocalizedString("This device does not support alternate app icons.", comment: "Icon change error")
            return
        }
        guard application.applicationState == .active else { return }
        if let name {
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any]
            let alternatives = icons?["CFBundleAlternateIcons"] as? [String: Any]
            guard alternatives?[name] != nil else {
                errorMessage = NSLocalizedString("The selected icon is not included in this app version.", comment: "Icon change error")
                return
            }
        }
        isChanging = true
        errorMessage = nil
        Task {
            defer { isChanging = false }
            do {
                do {
                    try await application.setAlternateIconName(name)
                } catch {
                    // A busy icon service can recover once the previous system interaction has ended.
                    guard Self.isTemporarilyUnavailable(error), application.alternateIconName != name else {
                        if application.alternateIconName == name { return }
                        throw error
                    }
                    try await Task.sleep(for: .milliseconds(500))
                    guard application.applicationState == .active else { throw error }
                    try await application.setAlternateIconName(name)
                }
            } catch {
                if Self.isTemporarilyUnavailable(error) {
                    errorMessage = NSLocalizedString("The system cannot change the app icon right now. Please try again later.", comment: "Temporary system icon error")
                } else {
                    errorMessage = error.localizedDescription
                }
                let details = error as NSError
                // Include system diagnostics to distinguish an icon asset error from a failing alert service.
                print("Iconwechsel fehlgeschlagen: \(details.domain) (\(details.code)): \(details.localizedDescription); Systemdetails: \(details.userInfo); iOS: \(UIDevice.current.systemVersion)")
            }
        }
    }

    private static func isTemporarilyUnavailable(_ error: Error) -> Bool {
        let error = error as NSError
        if error.domain == NSPOSIXErrorDomain && error.code == Int(EAGAIN) { return true }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return underlying.domain == NSPOSIXErrorDomain && underlying.code == Int(EAGAIN)
        }
        return false
    }
}

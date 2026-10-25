import Foundation

/// Die Sync-Wahl ist gerätelokal: Ein Backup oder ein anderes Gerät darf sie nicht ändern.
enum CloudSyncPreferences {
    static let enabledKey = "inventoryICloudSyncEnabled"
    static let containerIdentifier = "iCloud.de.hockulus.boxhelper"

    /// Unsigned Simulator-/Test-Builds besitzen keine CloudKit-Entitlements. Schon das
    /// Anlegen eines CKContainer kann dort abstürzen, deshalb prüfen wir vor jedem Zugriff.
    static var supportsCloudKit: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "BoxHelperCloudKitSigningEnabled") as? String)?
            .uppercased() == "YES"
    }
}

enum InventoryCloudSyncError: LocalizedError {
    case noAccount, couldNotDetermine, restricted, temporarilyUnavailable
    case unsupportedBuild, changing, settingsChanged

    var errorDescription: String? {
        switch self {
        case .noAccount: "Bitte melde dich in den Systemeinstellungen bei iCloud an."
        case .couldNotDetermine: "Der iCloud-Account konnte nicht geprüft werden. Bitte versuche es erneut."
        case .restricted: "iCloud ist für diesen Account eingeschränkt."
        case .temporarilyUnavailable: "iCloud ist vorübergehend nicht verfügbar. Bitte versuche es später erneut."
        case .unsupportedBuild: "Dieser App-Build unterstützt iCloud nicht. Für den Sync wird ein mit iCloud-Berechtigung signierter Build benötigt."
        case .changing: "Die iCloud-Einstellung wird bereits geändert."
        case .settingsChanged: "Die Einstellungen wurden während der iCloud-Umstellung zurückgesetzt. Bitte versuche es erneut."
        }
    }
}

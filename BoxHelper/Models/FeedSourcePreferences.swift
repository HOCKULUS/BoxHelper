import Foundation

/// Einmalige Umstellung exklusiver Modi auf zwei kombinierbare Quellen.
/// Danach bleiben auch bewusst abgeschaltete Quellen über Neustarts erhalten.
enum FeedSourcePreferences {
    static let migrationKey = "feedCombinedSourcesMigrated"

    @discardableResult
    static func prepare(in defaults: UserDefaults = .standard) -> Bool {
        guard !defaults.bool(forKey: migrationKey) else { return false }
        defaults.set(true, forKey: FeedMonitoringConfiguration.imageReferenceKey)
        defaults.set(true, forKey: FeedMonitoringConfiguration.objectnessKey)
        for key in ["feedMonitoringAttentionSaliency", "feedMonitoringDepthPro", "feedMonitoringHardwareDepth"] {
            defaults.removeObject(forKey: key)
        }
        defaults.set(true, forKey: migrationKey)
        return true
    }
}

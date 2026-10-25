import CloudKit
import Foundation

/// CloudKit-Sammelfehler und Core-Data-Hüllen enthalten die Ursache in userInfo.
/// Datensatz-IDs werden nicht angezeigt; für die Diagnose reichen Fehlertext und Code.
enum InventoryCloudErrorMessage {
    nonisolated static func describe(_ error: Error) -> String {
        let root = error as NSError
        var visited: Set<ObjectIdentifier> = []
        var causes: [NSError] = []
        var containsCloudError = false
        var containsPartialFailure = false

        // Begrenzung schützt auch vor zyklischen oder sehr großen Fehlerbäumen.
        func collect(_ current: NSError, depth: Int) {
            guard depth < 8, visited.count < 64,
                  visited.insert(ObjectIdentifier(current)).inserted else { return }
            let isCloudError = current.domain == CKErrorDomain
            containsCloudError = containsCloudError || isCloudError
            containsPartialFailure = containsPartialFailure ||
                (isCloudError && current.code == CKError.Code.partialFailure.rawValue)

            var children: [NSError] = []
            if let partial = current.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
                children += partial.values.map { $0 as NSError }
            }
            if let underlying = current.userInfo[NSUnderlyingErrorKey] as? Error {
                children.append(underlying as NSError)
            }
            if let underlying = current.userInfo[NSMultipleUnderlyingErrorsKey] as? [Error] {
                children += underlying.map { $0 as NSError }
            }
            if children.isEmpty { causes.append(current) }
            else { children.forEach { collect($0, depth: depth + 1) } }
        }

        collect(root, depth: 0)
        guard containsCloudError else { return error.localizedDescription }

        // Ein atomarer Batch meldet Folgefehler für sonst gültige Datensätze.
        // Sobald eine konkrete Ursache vorliegt, verdecken diese sie nicht.
        let actionable = causes.filter {
            !($0.domain == CKErrorDomain && $0.code == CKError.Code.batchRequestFailed.rawValue)
        }
        let selected = actionable.isEmpty ? causes : actionable
        let details = Set(selected.filter {
            !($0.domain == CKErrorDomain && $0.code == CKError.Code.partialFailure.rawValue)
        }.map { cause in
            var description = cause.localizedDescription
            if let reason = cause.localizedFailureReason, !description.contains(reason) {
                description += " \(reason)"
            }
            return "\(description) [\(cause.domain), Code \(cause.code)]"
        }).sorted()

        if containsPartialFailure && details.isEmpty {
            return "iCloud konnte einen Teil der Daten nicht synchronisieren (CloudKit, Code 2). Die Einzelfehler sind nur im Geräteprotokoll verfügbar."
        }
        let prefix = containsPartialFailure
            ? "iCloud konnte einen Teil der Daten nicht synchronisieren."
            : "iCloud-Synchronisierung fehlgeschlagen."
        return ([prefix] + Array(details.prefix(5))).joined(separator: "\n")
    }
}

import CryptoKit
import Foundation
import SwiftData

/// Frühere V3-Zwischenstände enthielten Formular und Fotos in einem JSON-Paket.
/// Die Schemaübernahme erhält dieses Paket; erst dieser Commit trennt seine Assets.
@MainActor
enum InventoryLegacyDraftUpgrade {
    private struct Package: Decodable { let form: Data; let photos: [String: Data] }

    static func migrate(in context: ModelContext) throws -> Bool {
        context.autosaveEnabled = false
        // Nur die maßgebliche Kopie konvertieren. Ältere Cloud-Duplikate dürfen beim
        // Upgrade keine neueren Fotos erzeugen oder einen aktuellen Entwurf überholen.
        var winners: [UUID: StoredFormDraft] = [:]
        let deletions = try InventoryDeletionLedger.states(in: context, kind: "draft")
        for record in try context.fetch(FetchDescriptor<StoredFormDraft>()) {
            if let old = winners[record.id], old.updatedAt > record.updatedAt
                || (old.updatedAt == record.updatedAt && (old.isTombstoned
                    || (old.payload ?? Data()).lexicographicallyPrecedes(record.payload ?? Data()))) { continue }
            winners[record.id] = record
        }
        for record in winners.values where !record.isTombstoned
            && deletions[record.id.uuidString]?.isDeleted != true
            && record.updatedAt > (deletions[record.id.uuidString]?.deletedAt ?? .distantPast) {
            guard let data = record.payload, let package = try? JSONDecoder().decode(Package.self, from: data),
                  let form = (try? JSONSerialization.jsonObject(with: package.form)) as? [String: Any],
                  form[record.kind == "box" ? "boxName" : "title"] is String else { continue }
            var names = form["imageFileNames"] as? [String] ?? []
            names += [form["locationImageFileName"], form["pendingNewItemImageFileName"]].compactMap { $0 as? String }
            for item in form["items"] as? [[String: Any]] ?? [] { names += item["images"] as? [String] ?? [] }
            let uniqueNames = Set(names)
            // Beschädigte alte Pakete bleiben vollständig erhalten. Sie dürfen weder das
            // Inventar blockieren noch beim Upgrade ihre bisher gespeicherten Fotos verlieren.
            guard uniqueNames.isSubset(of: Set(package.photos.keys)), package.photos.keys.allSatisfy({
                !$0.isEmpty && $0 != "." && $0 != ".." && URL(fileURLWithPath: $0).lastPathComponent == $0
            }) else { continue }
            // Die Reihenfolge mehrerer Cloud-Kopien derselben ID muss erhalten bleiben.
            let version = record.updatedAt.addingTimeInterval(0.001)
            // Auch derzeit unreferenzierte Paketfotos behalten; nur referenzierte Namen
            // werden später im Formular materialisiert.
            for (name, photo) in package.photos.sorted(by: { $0.key < $1.key }) {
                let digest = SHA256.hash(data: photo).map { String(format: "%02x", $0) }.joined()
                context.insert(StoredDraftPhoto(draftID: record.id, filename: name, data: photo, digest: digest, updatedAt: version))
            }
            record.payload = try JSONSerialization.data(withJSONObject: form, options: .sortedKeys)
            record.photoNames = uniqueNames.sorted()
            record.updatedAt = version
        }
        guard context.hasChanges else { return false }
        do { try context.save() } catch { context.rollback(); throw error }
        return true
    }
}

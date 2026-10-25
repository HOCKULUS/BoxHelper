import Foundation

/// Der Stream besitzt eigene Fotobytes. Das spätere Entfernen lokaler Entwurfsdateien
/// kann deshalb eine bereits begonnene Übertragung nicht nachträglich beschädigen.
enum InventoryHandoffMedia {
    static func capture(_ form: InventoryHandoffPayload.NormalizedForm, id: UUID, kind: String,
                        documents: URL) throws -> InventoryHandoffPayload.Form {
        guard form.data.count <= InventoryHandoffPayload.maximumFormBytes, form.names.count <= InventoryHandoffPayload.maximumPhotoCount else {
            throw InventoryHandoffError.tooLarge
        }
        var photos: [InventoryHandoffPayload.Photo] = []
        var total = 0
        for name in form.names.sorted() {
            try Task.checkCancellation()
            let url = try photoURL(name, kind: kind, documents: documents)
            let (snapshot, data) = try InventoryPhotoFileCoordinator.read(url)
            guard snapshot.identity != nil, let data else { throw InventoryHandoffError.invalidPhotos }
            total += data.count
            guard total <= InventoryHandoffPayload.maximumCombinedPhotoBytes else { throw InventoryHandoffError.tooLarge }
            try InventoryHandoffPayload.validatePhoto(data)
            photos.append(.init(name: name, data: data))
        }
        return .init(id: id, kind: kind, data: form.data, photos: photos)
    }

    static func materialize(_ payload: InventoryHandoffPayload.Form, documents: URL,
                            commit: (@MainActor @Sendable () throws -> Void)? = nil) async throws {
        let staging = Task.detached(priority: .utility) {
            _ = try payload.validate()
            var changes: [InventoryPhotoTransaction.Change] = []
            for photo in payload.photos {
                try Task.checkCancellation()
                let url = try photoURL(photo.name, kind: payload.kind, documents: documents)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                // Nach dem mkdir erneut prüfen: Auch Ordner-Symlinks dürfen keine
                // übertragene Datei außerhalb des temporären Formularbereichs ablegen.
                _ = try photoURL(photo.name, kind: payload.kind, documents: documents)
                let (_, original) = try InventoryPhotoFileCoordinator.read(url)
                changes.append(.init(url: url, original: original, replacement: photo.data))
            }
            return try InventoryPhotoTransaction.prepare(changes)
        }
        let transaction = try await withTaskCancellationHandler {
            try await staging.value
        } onCancel: { staging.cancel() }
        // apply übernimmt auch die Bereinigung eines bereits fertig vorbereiteten
        // Plans, wenn sein Aufrufer inzwischen abgebrochen wurde.
        try await transaction.apply(finalCommit: commit)
    }

    static func photoURL(_ name: String, kind: String, documents: URL) throws -> URL {
        try InventoryHandoffPayload.validateName(name, kind: kind)
        let root = documents.resolvingSymlinksInPath().standardizedFileURL
        var folder = root
        if kind != "box" {
            for component in ["CreateFormDrafts", kind] {
                folder.appendPathComponent(component, isDirectory: true)
                // resolvingSymlinksInPath kann bei noch fehlenden Unterordnern
                // einen vorhandenen Eltern-Symlink übersehen. Vor mkdir einzeln prüfen.
                if (try? FileManager.default.destinationOfSymbolicLink(atPath: folder.path)) != nil {
                    throw InventoryHandoffError.invalidPhotos
                }
            }
        }
        let url = folder.appendingPathComponent(name)
        guard url.resolvingSymlinksInPath().standardizedFileURL == url.standardizedFileURL else {
            throw InventoryHandoffError.invalidPhotos
        }
        return url
    }
}

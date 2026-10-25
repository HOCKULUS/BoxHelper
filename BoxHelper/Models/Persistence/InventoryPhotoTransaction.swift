import Foundation

/// Hintergrundvorbereitung einer Fotoübernahme. Nach dem bytegenauen Vergleich liegen
/// Ersatz und Rollback schon auf demselben Volume; die UI übernimmt nur kurze Renames.
struct InventoryPhotoTransaction: Sendable {
    struct Change: Sendable {
        let url: URL
        let original: Data?
        let replacement: Data?
    }

    private struct Staged: Sendable {
        let url: URL
        let expected: InventoryPhotoFileCoordinator.Snapshot
        let replacement: URL?
        let rollback: URL?
    }

    private let files: [Staged]
    private let directories: [URL]

    /// `lastCommit` ist das Receipt: Es wird erst nach allen bestätigten Fotodateien
    /// übernommen. Fehler stellen ausschließlich noch unveränderte Cloud-Dateien zurück.
    static func prepare(_ changes: [Change], lastCommit: Change? = nil) throws -> InventoryPhotoTransaction {
        var directories: [URL: URL] = [:]
        var staged: [Staged] = []
        do {
            for change in changes + (lastCommit.map { [$0] } ?? []) {
                try Task.checkCancellation()
                let current = try InventoryPhotoFileCoordinator.read(change.url)
                guard current.data == change.original else { throw InventoryPhotoFileCoordinator.Failure.changed(change.url.lastPathComponent) }
                let parent = change.url.deletingLastPathComponent()
                let directory: URL
                if let existing = directories[parent] { directory = existing }
                else {
                    directory = parent.appendingPathComponent(".cloud-photo-stage-\(UUID().uuidString)", isDirectory: true)
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    directories[parent] = directory
                }
                let replacement = try stage(change.replacement, in: directory)
                let rollback = try stage(change.original, in: directory)
                staged.append(Staged(url: change.url, expected: current.snapshot, replacement: replacement, rollback: rollback))
            }
            return InventoryPhotoTransaction(files: staged, directories: Array(directories.values))
        } catch {
            directories.values.forEach { try? FileManager.default.removeItem(at: $0) }
            throw error
        }
    }

    /// Ein einzelner Rename kann mit Formularen/Imports serialisiert werden, ohne große
    /// Fotos auf dem MainActor zu lesen oder zu schreiben. Zwischen Dateien bleibt UI-Zeit.
    /// Der optionale Hook simuliert in isolierten Tests lokale Änderungen zwischen
    /// zwei atomaren Commits. Der produktive Abgleich benötigt ihn nicht.
    func apply(beforeCommit: (@MainActor @Sendable (URL) throws -> Void)? = nil,
               afterCommit: (@MainActor @Sendable (URL) throws -> Void)? = nil,
               commitTrace: (@Sendable (Duration, Bool) -> Void)? = nil,
               finalCommit: (@MainActor @Sendable () throws -> Void)? = nil) async throws {
        var completed: [(Staged, InventoryPhotoFileCoordinator.Snapshot)] = []
        do {
            for file in files {
                try Task.checkCancellation()
                let committed = try await MainActor.run {
                    // Ein Löschplan darf nach einem Worker-Wait keine inzwischen neu
                    // zugeordnete Datei entfernen. Prüfung und Rename laufen zusammen.
                    try beforeCommit?(file.url)
                    let started = ContinuousClock.now
                    let snapshot = try InventoryPhotoFileCoordinator.commit(file.replacement, to: file.url, expected: file.expected)
                    commitTrace?(ContinuousClock.now - started, Thread.isMainThread)
                    return snapshot
                }
                completed.append((file, committed))
                if let afterCommit { try await MainActor.run { try afterCommit(file.url) } }
                await Task.yield()
            }
            // Handoff übernimmt seine Formularmetadaten erst nach sämtlichen Fotos.
            // Bis zu diesem kurzen finalen Commit bleiben die Rollback-Dateien erhalten.
            try Task.checkCancellation()
            if let finalCommit {
                try await MainActor.run {
                    try Task.checkCancellation()
                    try finalCommit()
                }
            }
            await cleanup()
        } catch {
            // Das Rollback ignoriert Task-Cancellation, aber niemals eine jüngere lokale
            // Dateiversion. Ein zwischenzeitlich bearbeitetes Foto bleibt daher erhalten.
            for (file, committed) in completed.reversed() {
                try? await MainActor.run {
                    _ = try InventoryPhotoFileCoordinator.commit(file.rollback, to: file.url, expected: committed)
                }
            }
            await cleanup()
            throw error
        }
    }

    /// Synchroner Adapter ausschließlich für die bestehenden isolierten Store-Prüfungen.
    /// Der produktive Cloud-Worker nutzt apply() und die Hintergrundvorbereitung.
    @MainActor
    func applySynchronously() throws {
        var completed: [(Staged, InventoryPhotoFileCoordinator.Snapshot)] = []
        defer { cleanupSynchronously() }
        do {
            for file in files {
                let committed = try InventoryPhotoFileCoordinator.commit(file.replacement, to: file.url, expected: file.expected)
                completed.append((file, committed))
            }
        } catch {
            for (file, committed) in completed.reversed() {
                _ = try? InventoryPhotoFileCoordinator.commit(file.rollback, to: file.url, expected: committed)
            }
            throw error
        }
    }

    private static func stage(_ data: Data?, in directory: URL) throws -> URL? {
        guard let data else { return nil }
        let url = directory.appendingPathComponent(UUID().uuidString)
        try data.write(to: url)
        return url
    }

    private func cleanup() async {
        let directories = directories
        await Task.detached(priority: .utility) {
            directories.forEach { try? FileManager.default.removeItem(at: $0) }
        }.value
    }

    private func cleanupSynchronously() {
        directories.forEach { try? FileManager.default.removeItem(at: $0) }
    }
}

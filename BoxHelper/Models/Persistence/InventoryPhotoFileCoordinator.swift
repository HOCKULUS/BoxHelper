import Darwin
import Foundation

/// Große Dateiinhalte werden außerhalb des Gates gelesen/geschrieben. Das Gate schützt
/// ausschließlich Versionsprüfung und atomaren Rename/Unlink einer einzelnen Datei.
enum InventoryPhotoFileCoordinator {
    struct Identity: Equatable, Sendable {
        let number: UInt64
        let size: UInt64
        let modifiedAt: Date

        static func read(_ url: URL) throws -> Identity? {
            let attributes: [FileAttributeKey: Any]
            do { attributes = try FileManager.default.attributesOfItem(atPath: url.path) }
            catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError { return nil }
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  let number = attributes[.systemFileNumber] as? NSNumber,
                  let size = attributes[.size] as? NSNumber,
                  let date = attributes[.modificationDate] as? Date else { throw Failure.unsafeFile(url.lastPathComponent) }
            return Identity(number: number.uint64Value, size: size.uint64Value, modifiedAt: date)
        }
    }

    struct Snapshot: Equatable, Sendable {
        let generation: UInt64
        let identity: Identity?
    }

    enum Failure: LocalizedError {
        case changed(String), unsafeFile(String)
        var errorDescription: String? {
            switch self {
            case .changed(let name): "Das Foto \(name) wurde zwischenzeitlich lokal geändert."
            case .unsafeFile(let name): "\(name) ist keine reguläre Bilddatei."
            }
        }
    }

    /// Ein Snapshot wird im Hintergrund erstellt. Die abschließende Prüfung fängt
    /// auch lokale Schreibvorgänge ab, die während des umfangreichen Lesens beginnen.
    static func read(_ url: URL) throws -> (snapshot: Snapshot, data: Data?) {
        let generation = try state.generation(for: url)
        let identity = try Identity.read(url)
        let data = identity == nil ? nil : try Data(contentsOf: url)
        guard try Identity.read(url) == identity, state.isCurrent(url, generation: generation) else {
            throw Failure.changed(url.lastPathComponent)
        }
        return (Snapshot(generation: generation, identity: identity), data)
    }

    @MainActor
    static func commit(_ staged: URL?, to url: URL, expected: Snapshot) throws -> Snapshot {
        try state.commit(staged, to: url, expected: expected)
    }

    /// Bestehende lokale Foto-Schreibpfade reservieren ihre Version vor der Dateiarbeit.
    /// Ein älterer Cloud-Plan darf weder einen laufenden noch einen fertigen Import ersetzen.
    static func write(_ data: Data, to url: URL) throws {
        try localMutation(url) { staged in try data.write(to: staged) }
    }

    static func copy(from source: URL, to url: URL) throws {
        try localMutation(url) { staged in try FileManager.default.copyItem(at: source, to: staged) }
    }

    static func remove(_ url: URL) throws {
        let token = state.beginLocal(url)
        defer { state.endLocal(url, token: token) }
        try state.commitLocal(nil, to: url, token: token)
    }

    private static func localMutation(_ url: URL, stage: (URL) throws -> Void) throws {
        let token = state.beginLocal(url)
        let staged = url.deletingLastPathComponent().appendingPathComponent(".photo-local-\(UUID().uuidString).tmp")
        defer {
            state.endLocal(url, token: token)
            try? FileManager.default.removeItem(at: staged)
        }
        try stage(staged)
        try state.commitLocal(staged, to: url, token: token)
    }

    private static let state = State()

    /// NSLock schützt nur kleine In-Memory-Einträge und einzelne Rename/Unlink-Aufrufe.
    /// Kein Foto-Hash, Data(contentsOf:), Data.write oder ganzer Batch läuft unter Lock.
    private final class State: @unchecked Sendable {
        private struct Entry {
            var generation: UInt64 = 0
            var latestLocal: UUID?
            var activeLocal: Set<UUID> = []
        }
        private let lock = NSLock()
        private var entries: [String: Entry] = [:]
        private func key(_ url: URL) -> String { url.standardizedFileURL.path }

        func generation(for url: URL) throws -> UInt64 {
            try lock.withLock {
                let entry = entries[key(url)] ?? Entry()
                guard entry.activeLocal.isEmpty else { throw Failure.changed(url.lastPathComponent) }
                return entry.generation
            }
        }

        func isCurrent(_ url: URL, generation: UInt64) -> Bool {
            lock.withLock {
                let entry = entries[key(url)] ?? Entry()
                return entry.generation == generation && entry.activeLocal.isEmpty
            }
        }

        func beginLocal(_ url: URL) -> UUID {
            lock.withLock {
                let token = UUID(), path = key(url)
                var entry = entries[path] ?? Entry()
                entry.generation &+= 1
                entry.latestLocal = token
                entry.activeLocal.insert(token)
                entries[path] = entry
                return token
            }
        }

        func endLocal(_ url: URL, token: UUID) {
            lock.withLock {
                let path = key(url)
                entries[path]?.activeLocal.remove(token)
            }
        }

        func commitLocal(_ staged: URL?, to url: URL, token: UUID) throws {
            try lock.withLock {
                guard entries[key(url)]?.latestLocal == token else { throw Failure.changed(url.lastPathComponent) }
                try renameOrRemove(staged, to: url)
            }
        }

        func commit(_ staged: URL?, to url: URL, expected: Snapshot) throws -> Snapshot {
            try lock.withLock {
                let path = key(url)
                var entry = entries[path] ?? Entry()
                guard entry.generation == expected.generation, entry.activeLocal.isEmpty,
                      try Identity.read(url) == expected.identity else { throw Failure.changed(url.lastPathComponent) }
                try renameOrRemove(staged, to: url)
                entry.generation &+= 1
                entries[path] = entry
                return Snapshot(generation: entry.generation, identity: try Identity.read(url))
            }
        }

        private func renameOrRemove(_ staged: URL?, to url: URL) throws {
            let result: Int32
            if let staged { result = staged.path.withCString { source in url.path.withCString { rename(source, $0) } } }
            else {
                result = url.path.withCString { unlink($0) }
                if result != 0 && errno == ENOENT { return }
            }
            guard result == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        }
    }
}

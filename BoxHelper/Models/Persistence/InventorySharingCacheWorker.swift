import Darwin
import Foundation

/// JSON und vollständige Schreibzugriffe bleiben auf einem eigenen seriellen Executor.
/// Die UI veröffentlicht erst danach die fertige Datei mit einem kurzen atomaren Rename.
actor InventorySharingCacheWorker {
    private let beforeStage: (@Sendable (Data) async throws -> Void)?

    init() { beforeStage = nil }

    /// Isolierte Tests können eine lokale Änderung genau während eines Checkpoints auslösen.
    init(beforeStage: @escaping @Sendable (Data) async throws -> Void) { self.beforeStage = beforeStage }

    struct Stage: Sendable {
        let temporary: URL
        let destination: URL

        /// Der Service prüft unmittelbar davor seine Cache-Revision auf dem MainActor.
        /// So kann eine verspätete Stage keinen neueren lokalen Checkpoint überschreiben.
        func publish() throws {
            guard rename(temporary.path, destination.path) == 0 else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
        }

        func discard() { try? FileManager.default.removeItem(at: temporary) }
    }

    func read<Value: Decodable & Sendable>(_ type: Value.Type, at url: URL) throws -> Value? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    func stage<Value: Encodable & Sendable>(_ value: Value, at destination: URL) async throws -> Stage {
        let bytes = try InventoryShareMerge.encode(value)
        try await beforeStage?(bytes)
        return try stageData(bytes, at: destination)
    }

    func stageData(_ data: Data, at destination: URL) throws -> Stage {
        try Task.checkCancellation()
        let directory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appendingPathComponent(".\(destination.lastPathComponent).\(UUID()).stage")
        do {
            try data.write(to: temporary, options: .atomic)
            try Task.checkCancellation()
            return Stage(temporary: temporary, destination: destination)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }
}

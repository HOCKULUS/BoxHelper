import Foundation

/// Eine System-Assertion gehört genau einem Auftrag. Abbruch endet erst nach dem
/// Worker; bei Ablauf fordert das System dagegen das sofortige Freigeben an.
@MainActor
final class InventoryBackgroundLease {
    private var end: (() -> Void)?
    private var cancel: (() -> Void)?
    private var isFinished = false
    private(set) var isExpired = false

    func installEnd(_ end: @escaping () -> Void) {
        // Auch ein synchroner Ablauf-Callback des injizierten Treibers bleibt sicher.
        if isFinished { end() } else { self.end = end }
    }

    func expire() {
        guard !isFinished else { return }
        isExpired = true
        cancel?()
        finish()
    }

    func finish() {
        guard !isFinished else { return }
        isFinished = true
        let completion = end
        end = nil
        cancel = nil
        completion?()
    }

    /// Der geschützte Auftrag umfasst auch detached Worker, deren Rückkehr und
    /// eventuelles Foto-Rollback. Task.cancel allein gibt noch keine SQLite-Sperre frei.
    func perform<Value: Sendable>(
        _ operation: @escaping @MainActor @Sendable () async throws -> Value
    ) async throws -> Value {
        defer { finish() }
        try Task.checkCancellation()
        guard !isExpired, !isFinished else { throw CancellationError() }
        let work = Task { @MainActor in
            try Task.checkCancellation()
            let result = try await operation()
            try Task.checkCancellation()
            return result
        }
        cancel = { work.cancel() }
        return try await withTaskCancellationHandler {
            try await work.value
        } onCancel: {
            work.cancel()
        }
    }
}

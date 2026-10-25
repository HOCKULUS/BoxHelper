import Foundation

/// Erfasst auch unabhängige Hintergrundleser (etwa Foto-Löschungen). Ein Wechsel
/// wartet auf ihre Contexts, bevor der bisherige ModelContainer freigegeben wird.
@MainActor
final class InventoryStoreAccess {
    static let shared = InventoryStoreAccess()

    private var isPaused = false
    private var activeOperations = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func perform<Value: Sendable>(_ operation: @MainActor () async throws -> Value) async throws -> Value {
        guard !isPaused else { throw CancellationError() }
        activeOperations += 1
        defer {
            activeOperations -= 1
            if activeOperations == 0 {
                let pending = waiters
                waiters.removeAll()
                pending.forEach { $0.resume() }
            }
        }
        return try await operation()
    }

    func pause() { isPaused = true }
    func resume() { isPaused = false }

    func waitUntilIdle() async {
        guard activeOperations > 0 else { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}

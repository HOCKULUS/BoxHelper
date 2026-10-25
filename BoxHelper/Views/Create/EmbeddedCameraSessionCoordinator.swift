import Foundation

/// Alle Formular-Kameras teilen die Hardware und deshalb dieselbe serielle Queue.
/// Auch bei umgekehrter Reihenfolge der SwiftUI-Tasks stoppt der bisherige Besitzer zuerst.
final class EmbeddedCameraSessionCoordinator: @unchecked Sendable {
    static let shared = EmbeddedCameraSessionCoordinator()
    let queue = DispatchQueue(label: "BoxHelper.itemCamera")
    private weak var owner: AnyObject?
    private var stopOwner: (@Sendable () -> Void)?

    /// Ausschließlich auf der Capture-Queue aufrufen; Stop muss synchron fertig werden.
    func claim(_ newOwner: AnyObject, stop: @escaping @Sendable () -> Void) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard owner !== newOwner else { return }
        stopOwner?()
        owner = newOwner
        stopOwner = stop
    }

    func release(_ previousOwner: AnyObject) {
        dispatchPrecondition(condition: .onQueue(queue))
        // Ein verspäteter Stop des alten Formulars darf den neuen Besitzer nicht freigeben.
        guard owner === previousOwner else { return }
        owner = nil
        stopOwner = nil
    }
}

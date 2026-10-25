import Foundation

/// Der Delegate besitzt keine View und keinen ModelContext. Ein Callback übernimmt
/// eine unveränderliche Wertkopie; spätere Saves/Clears ändern diese Übertragung nicht.
final class InventoryHandoffActivityDelegate: NSObject, NSUserActivityDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: InventoryHandoffPayload.Form
    private var title: String
    private let report: @Sendable (String) -> Void

    init(snapshot: InventoryHandoffPayload.Form, title: String, report: @escaping @Sendable (String) -> Void) {
        self.snapshot = snapshot; self.title = title; self.report = report
    }

    func update(snapshot: InventoryHandoffPayload.Form, title: String) {
        lock.withLock { self.snapshot = snapshot; self.title = title }
    }

    func userActivityWillSave(_ userActivity: NSUserActivity) {
        let state = lock.withLock { (snapshot.id, snapshot.kind, snapshot.revision, title) }
        userActivity.userInfo = Self.descriptor(id: state.0, kind: state.1, revision: state.2)
        userActivity.title = state.3
    }

    func userActivity(_ userActivity: NSUserActivity, didReceive inputStream: InputStream, outputStream: OutputStream) {
        let packet = lock.withLock { snapshot }
        let streams = InventoryHandoffStreamTransport.Streams(input: inputStream, output: outputStream)
        let report = self.report
        DispatchQueue.global(qos: .utility).async {
            do { try InventoryHandoffStreamTransport.send(packet, through: streams) }
            catch { report(error.localizedDescription) }
        }
    }

    static func descriptor(id: UUID, kind: String, revision: UUID) -> [AnyHashable: Any] {
        ["version": InventoryHandoffPayload.version, "formID": id.uuidString, "kind": kind, "revision": revision.uuidString]
    }
}

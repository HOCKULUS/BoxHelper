import Foundation

/// Längenbegrenztes Frame mit Bestätigung: Ein EOF ist niemals ein vollständiges
/// Formular. Alle Streamzugriffe bleiben auf genau einem Hintergrundthread.
enum InventoryHandoffStreamTransport {
    private static let magic = Data([0x42, 0x48, 0x48, 0x31]) // BHH1
    private static let acknowledgment: UInt8 = 0xA5
    static let timeout: TimeInterval = 30

    /// Foundation-Streams sind nicht Sendable. Diese Hülle übergibt das exklusive
    /// Eigentum einmalig an den Worker; danach greift kein anderer Thread darauf zu.
    final class Streams: @unchecked Sendable {
        let input: InputStream
        let output: OutputStream
        init(input: InputStream, output: OutputStream) { self.input = input; self.output = output }
    }

    @MainActor
    static func receive(activity: NSUserActivity) async throws -> Data {
        let gate = CompletionGate()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                gate.install(continuation)
                guard !gate.isFinished else { return }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) { [weak gate] in
                    gate?.finish(.failure(InventoryHandoffError.timedOut))
                }
                activity.getContinuationStreams { input, output, error in
                    if let error { gate.finish(.failure(error)); return }
                    guard let input, let output else { gate.finish(.failure(InventoryHandoffError.unavailable)); return }
                    let streams = Streams(input: input, output: output)
                    DispatchQueue.global(qos: .utility).async {
                        do {
                            let data = try read(streams, cancelled: { gate.isFinished })
                            gate.finish(.success(data))
                        } catch { gate.finish(.failure(error)) }
                    }
                }
            }
        } onCancel: { gate.finish(.failure(CancellationError())) }
    }

    static func read(_ streams: Streams, cancelled: () -> Bool = { false }) throws -> Data {
        try withOpened(streams) { deadline in
            let data = try readFrame(from: streams.input, deadline: deadline, cancelled: cancelled)
            try write(Data([acknowledgment]), to: streams.output, deadline: deadline, cancelled: cancelled)
            return data
        }
    }

    static func send(_ payload: InventoryHandoffPayload.Form, through streams: Streams) throws {
        try withOpened(streams) { deadline in
            let data = try JSONEncoder().encode(payload)
            guard data.count <= InventoryHandoffPayload.maximumFrameBytes else { throw InventoryHandoffError.tooLarge }
            try write(header(length: data.count), to: streams.output, deadline: deadline)
            try write(data, to: streams.output, deadline: deadline)
            let reply = try readExactly(1, from: streams.input, deadline: deadline)
            guard reply.first == acknowledgment else { throw InventoryHandoffError.incomplete }
        }
    }

    /// Kleine reine Seams prüfen dasselbe produktive Format ohne Netzwerk oder Handoff-Geräte.
    static func header(length: Int) throws -> Data {
        guard length > 0, length <= InventoryHandoffPayload.maximumFrameBytes else { throw InventoryHandoffError.tooLarge }
        var data = magic
        var size = UInt64(length).bigEndian
        withUnsafeBytes(of: &size) { data.append(contentsOf: $0) }
        return data
    }

    static func payloadLength(in header: Data) throws -> Int {
        guard header.count == 12, header.prefix(4) == magic else { throw InventoryHandoffError.incomplete }
        let size = header.dropFirst(4).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        guard size > 0, size <= UInt64(InventoryHandoffPayload.maximumFrameBytes) else { throw InventoryHandoffError.tooLarge }
        return Int(size)
    }

    private static func withOpened<Value>(_ streams: Streams, operation: (ContinuousClock.Instant) throws -> Value) throws -> Value {
        let runLoop = RunLoop.current
        streams.input.schedule(in: runLoop, forMode: .default)
        streams.output.schedule(in: runLoop, forMode: .default)
        streams.input.open()
        streams.output.open()
        defer {
            streams.input.close(); streams.output.close()
            streams.input.remove(from: runLoop, forMode: .default)
            streams.output.remove(from: runLoop, forMode: .default)
        }
        return try operation(ContinuousClock.now.advanced(by: .seconds(timeout)))
    }

    private static func readFrame(from stream: InputStream, deadline: ContinuousClock.Instant,
                                  cancelled: () -> Bool) throws -> Data {
        let length = try payloadLength(in: readExactly(12, from: stream, deadline: deadline, cancelled: cancelled))
        return try readExactly(length, from: stream, deadline: deadline, cancelled: cancelled)
    }

    private static func readExactly(_ count: Int, from stream: InputStream, deadline: ContinuousClock.Instant,
                                    cancelled: () -> Bool = { false }) throws -> Data {
        var result = Data()
        result.reserveCapacity(count)
        var buffer = [UInt8](repeating: 0, count: min(count, 16_384))
        while result.count < count {
            try check(stream, deadline: deadline, cancelled: cancelled)
            guard stream.hasBytesAvailable else { try waitForEvent(stream, deadline: deadline, cancelled: cancelled); continue }
            let remaining = min(buffer.count, count - result.count)
            let read = stream.read(&buffer, maxLength: remaining)
            guard read > 0 else { throw stream.streamError ?? InventoryHandoffError.incomplete }
            result.append(contentsOf: buffer.prefix(read))
        }
        return result
    }

    private static func write(_ data: Data, to stream: OutputStream, deadline: ContinuousClock.Instant,
                              cancelled: () -> Bool = { false }) throws {
        try data.withUnsafeBytes { raw in
            guard let bytes = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            var offset = 0
            while offset < data.count {
                try check(stream, deadline: deadline, cancelled: cancelled)
                guard stream.hasSpaceAvailable else { try waitForEvent(stream, deadline: deadline, cancelled: cancelled); continue }
                let written = stream.write(bytes.advanced(by: offset), maxLength: min(16_384, data.count - offset))
                guard written > 0 else { throw stream.streamError ?? InventoryHandoffError.incomplete }
                offset += written
            }
        }
    }

    private static func check(_ stream: Stream, deadline: ContinuousClock.Instant, cancelled: () -> Bool) throws {
        if cancelled() { throw CancellationError() }
        guard ContinuousClock.now < deadline else { throw InventoryHandoffError.timedOut }
        if let error = stream.streamError { throw error }
        if stream.streamStatus == .atEnd || stream.streamStatus == .closed { throw InventoryHandoffError.incomplete }
    }

    private static func waitForEvent(_ stream: Stream, deadline: ContinuousClock.Instant, cancelled: () -> Bool) throws {
        try check(stream, deadline: deadline, cancelled: cancelled)
        // Scheduled Foundation-Streams benötigen ihre RunLoop. Der MainActor wartet
        // dabei weder auf Netzwerklatenz noch auf einen blockierenden read/write-Aufruf.
        let until = Date().addingTimeInterval(0.01)
        if !RunLoop.current.run(mode: .default, before: until) { Thread.sleep(forTimeInterval: 0.001) }
    }

    private final class CompletionGate: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Data, Error>?
        private var result: Result<Data, Error>?
        var isFinished: Bool { lock.withLock { result != nil } }

        func install(_ continuation: CheckedContinuation<Data, Error>) {
            let completed = lock.withLock { () -> Result<Data, Error>? in
                if let result { return result }
                self.continuation = continuation
                return nil
            }
            if let completed { continuation.resume(with: completed) }
        }

        func finish(_ result: Result<Data, Error>) {
            let pending = lock.withLock { () -> CheckedContinuation<Data, Error>? in
                guard self.result == nil else { return nil }
                self.result = result
                let pending = continuation
                continuation = nil
                return pending
            }
            pending?.resume(with: result)
        }
    }
}

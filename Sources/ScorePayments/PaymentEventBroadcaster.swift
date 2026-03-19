import Foundation

/// Manages multi-consumer event fanout using `AsyncStream`.
///
/// Each call to `makeStream()` returns an independent stream.
/// When events are broadcast, every active stream receives a copy.
/// Streams are cleaned up automatically when their consumer task is cancelled.
final class PaymentEventBroadcaster: Sendable {

    private let state = LockedState()

    /// Creates a new independent event stream.
    func makeStream() -> AsyncStream<PaymentEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            state.addContinuation(id: id, continuation: continuation)
            continuation.onTermination = { @Sendable _ in
                self.state.removeContinuation(id: id)
            }
        }
    }

    /// Sends an event to all active consumers.
    func broadcast(_ event: PaymentEvent) {
        for continuation in state.allContinuations {
            continuation.yield(event)
        }
    }

    /// Finishes all active streams.
    func finish() {
        for continuation in state.allContinuations {
            continuation.finish()
        }
    }
}

/// Thread-safe storage for stream continuations, keyed by UUID.
private final class LockedState: Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var _continuations: [UUID: AsyncStream<PaymentEvent>.Continuation] = [:]

    var allContinuations: [AsyncStream<PaymentEvent>.Continuation] {
        lock.withLock { Array(_continuations.values) }
    }

    func addContinuation(id: UUID, continuation: AsyncStream<PaymentEvent>.Continuation) {
        lock.withLock { _continuations[id] = continuation }
    }

    func removeContinuation(id: UUID) {
        lock.withLock { _continuations.removeValue(forKey: id) }
    }
}

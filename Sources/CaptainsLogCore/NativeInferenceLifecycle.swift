import Foundation

/// Keeps process termination from racing native model/context teardown. Shutdown
/// rejects new work and drains the current native call, without finishing a pipeline.
public final class NativeInferenceLifecycle: @unchecked Sendable {
    public static let shared = NativeInferenceLifecycle()
    private let lock = NSLock()
    private var stopping = false
    private var activeOperations = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init() {}

    func beginOperation() throws {
        try Task.checkCancellation()
        try lock.withLock {
            guard !stopping else { throw CancellationError() }
            activeOperations += 1
        }
    }

    func endOperation() {
        let ready = lock.withLock {
            activeOperations -= 1
            guard activeOperations == 0 else { return [CheckedContinuation<Void, Never>]() }
            let ready = waiters
            waiters.removeAll()
            return ready
        }
        for waiter in ready { waiter.resume() }
    }

    func checkCancellation() throws {
        try Task.checkCancellation()
        if lock.withLock({ stopping }) { throw CancellationError() }
    }

    /// Llama's abort callback supports CPU only. Let any in-flight Metal decode
    /// return and release its context before AppKit begins process teardown.
    public func stopAndWait() async {
        await withCheckedContinuation { continuation in
            let idle = lock.withLock {
                stopping = true
                if activeOperations == 0 { return true }
                waiters.append(continuation)
                return false
            }
            if idle { continuation.resume() }
        }
    }
}

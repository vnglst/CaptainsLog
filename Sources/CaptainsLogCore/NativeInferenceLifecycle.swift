import Foundation

/// Keeps process termination from racing native model/context teardown. Shutdown
/// rejects new work and drains the current native call, without finishing a pipeline.
public final class NativeInferenceLifecycle: @unchecked Sendable {
    public static let shared = NativeInferenceLifecycle()
    private let lock = NSCondition()
    private var stopping = false
    private var activeOperations = 0
    private var retainedResources = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init() {}

    func beginOperation(onlyIfIdle: Bool = false) throws {
        try Task.checkCancellation()
        try lock.withLock {
            while activeOperations > 0 && !stopping {
                if onlyIfIdle { throw NativeInferenceBusy() }
                _ = lock.wait(until: Date().addingTimeInterval(0.1))
                try Task.checkCancellation()
            }
            guard !stopping else { throw CancellationError() }
            activeOperations += 1
        }
    }

    func endOperation() {
        let ready = lock.withLock {
            activeOperations -= 1
            lock.broadcast()
            guard activeOperations == 0, retainedResources == 0 else { return [CheckedContinuation<Void, Never>]() }
            let ready = waiters
            waiters.removeAll()
            return ready
        }
        for waiter in ready { waiter.resume() }
    }

    func beginResource() throws {
        try lock.withLock {
            guard !stopping else { throw CancellationError() }
            retainedResources += 1
        }
    }

    func endResource() {
        let ready = lock.withLock {
            retainedResources -= 1
            guard activeOperations == 0, retainedResources == 0 else { return [CheckedContinuation<Void, Never>]() }
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
                lock.broadcast()
                if activeOperations == 0, retainedResources == 0 { return true }
                waiters.append(continuation)
                return false
            }
            if idle { continuation.resume() }
        }
    }
}

struct NativeInferenceBusy: Error {}

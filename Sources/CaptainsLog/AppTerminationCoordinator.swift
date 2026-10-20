import Foundation

/// Prefer graceful native teardown, but do not leave Quit waiting indefinitely
/// for an uninterruptible model call. Audio must be closed before either exit.
public final class AppTerminationCoordinator: @unchecked Sendable {
    private let lock = NSLock()
    private var started = false
    private var finished = false
    private let waitForDeadline: @Sendable () async -> Void

    public init() {
        waitForDeadline = { try? await Task.sleep(for: .seconds(2)) }
    }

    init(waitForDeadline: @escaping @Sendable () async -> Void) {
        self.waitForDeadline = waitForDeadline
    }

    public func begin(
        prepare: @escaping @Sendable () async -> Void,
        waitForAudio: @escaping @Sendable () async -> Void,
        onGraceful: @escaping @Sendable () -> Void,
        onDeadline: @escaping @Sendable () -> Void
    ) {
        guard lock.withLock({
            guard !started else { return false }
            started = true
            return true
        }) else { return }

        // Unstructured tasks are intentional: a task group would still wait for
        // its uninterruptible native child after the deadline won the race.
        Task.detached { [self] in
            await prepare()
            if claimCompletion() { onGraceful() }
        }
        Task.detached { [self] in
            await waitForDeadline()
            await waitForAudio()
            if claimCompletion() { onDeadline() }
        }
    }

    private func claimCompletion() -> Bool {
        lock.withLock {
            guard !finished else { return false }
            finished = true
            return true
        }
    }
}

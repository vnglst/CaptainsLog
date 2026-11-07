import CaptainsLogCore
import Foundation

/// One serial worker owns pipeline writes; all entry points submit to its queue.
@MainActor
@Observable
public final class ProcessingCoordinator {
    typealias PipelineResume = @Sendable (
        _ stem: String, _ dataDir: String, _ fromStage: Pipeline.Stage?,
        _ progress: (@Sendable (Pipeline.Progress) -> Void)?
    ) async throws -> Pipeline.Result

    let lifecycle = AppLifecycle()
    public var stage: AppStage {
        get { lifecycle.processingStage }
        set { lifecycle.send(.processingStage(newValue)) }
    }
    public var statusMessage: String {
        get { lifecycle.processingMessage }
        set { lifecycle.send(.processingMessage(newValue)) }
    }
    public var errorMessage: String? {
        get { lifecycle.processingError }
        set { lifecycle.send(.processingError(newValue)) }
    }
    public var processingStem: String? {
        get { lifecycle.processingStem }
        set { lifecycle.send(.processingStem(newValue)) }
    }
    var failedEntries: [String: String] { lifecycle.failedEntries }

    private struct Context {
        let dataDir: String
        let onProgress: () -> Void
        let onError: (Error) -> Void
        var refreshOnError = false
    }
    private struct Request {
        let stem: String
        let fromStage: Pipeline.Stage?
        var context: Context?
    }

    private var processingTask: Task<Void, Never>?
    // Unlike the visible processingStem, ownership survives Pause until native work returns.
    private var ownedStem: String? { lifecycle.ownedStem }
    private var cleanupAfterCancellation: (() -> Void)?
    private var requests: [String: Request] = [:]
    private var drainCallbacks: [() -> Void] = []
    private var isStopping: Bool { lifecycle.isTerminating }
    private let resumePipeline: PipelineResume

    var hasScheduledWork: Bool { lifecycle.hasScheduledWork }
    public var isProcessing: Bool { lifecycle.isProcessing }

    var processingStage: Pipeline.Stage {
        switch stage {
        case .transcribing: return .transcribing
        case .cleaning: return .cleaning
        case .categorizing: return .categorizing
        case .naming: return .naming
        case .enriching: return .enriching
        case .done: return .done
        default: return .transcribing
        }
    }

    public init() {
        resumePipeline = { stem, dataDir, fromStage, progress in
            try await Pipeline.resume(stem: stem, dataDir: dataDir, fromStage: fromStage, progress: progress)
        }
    }
    init(resumePipeline: @escaping PipelineResume) { self.resumePipeline = resumePipeline }

    func failureMessage(for stem: String) -> String? { failedEntries[stem] }
    func isQueued(stem: String) -> Bool { lifecycle.queue.contains { $0.stem == stem } }
    func ownsEntry(stem: String) -> Bool { ownedStem == stem || processingStem == stem || isQueued(stem: stem) }

    func canQueueReprocessing(stem: String) -> Bool { lifecycle.canQueue(stem: stem) }

    @discardableResult
    private func enqueue(_ request: Request) -> Bool {
        guard lifecycle.enqueue(stem: request.stem, prepared: request.context != nil) else { return false }
        requests[request.stem] = request
        return true
    }

    /// Recordings may wait for model readiness; startProcessing supplies their context.
    func queueProcessing(stem: String) {
        enqueue(Request(stem: stem, fromStage: .transcribing, context: nil))
    }

    func startProcessing(
        dataDir: String, isRecording: Bool,
        onProgress: @escaping () -> Void, onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        guard !isStopping else { return }
        let context = Context(dataDir: dataDir, onProgress: onProgress, onError: onError, refreshOnError: true)
        var configured = false
        for item in lifecycle.queue where !item.isPrepared {
            requests[item.stem]?.context = context
            lifecycle.prepareQueued(stem: item.stem)
            configured = true
        }
        if configured { drainCallbacks.append(onComplete) }
        startWorker()
    }

    public func pauseProcessing() {
        requests.removeAll()
        drainCallbacks.removeAll()
        processingTask?.cancel()
        lifecycle.send(.processingPaused)
    }

    public func stopForTermination() async {
        lifecycle.send(.terminating)
        let task = processingTask
        pauseProcessing()
        await task?.value
    }

    func resumeEntry(
        stem: String, fromStage: Pipeline.Stage? = nil, dataDir: String,
        modelsReady: Bool = true,
        onComplete: @escaping () -> Void, onError: @escaping (Error) -> Void
    ) {
        let context = Context(dataDir: dataDir, onProgress: onComplete, onError: onError)
        enqueue(Request(stem: stem, fromStage: fromStage, context: modelsReady ? context : nil))
        startWorker()
    }

    /// Delete synchronously; only inference waits in the serial queue.
    @discardableResult
    func reprocessEntry(
        stem: String, dataDir: String, modelsReady: Bool = true,
        prepare: @escaping () throws -> Void,
        onComplete: @escaping () -> Void, onError: @escaping (Error) -> Void
    ) -> Bool {
        guard canQueueReprocessing(stem: stem) else { return false }
        do { try prepare() }
        catch {
            recordPreparationFailure(error, for: stem)
            onError(error)
            return false
        }
        if ownedStem == stem {
            // A cancelled native call can finish an in-flight write. Invalidation
            // survives Pause/Quit even when the queued restart is discarded.
            cleanupAfterCancellation = { [self] in
                do { try prepare() }
                catch {
                    requests.removeValue(forKey: stem)
                    lifecycle.discardQueued(stem: stem)
                    recordPreparationFailure(error, for: stem)
                    onError(error)
                }
            }
        }
        let context = Context(dataDir: dataDir, onProgress: onComplete, onError: onError)
        enqueue(Request(stem: stem, fromStage: .transcribing, context: modelsReady ? context : nil))
        startWorker()
        return true
    }

    func batchResumePending(
        pendingEntries: [LogEntry], dataDir: String, modelsReady: Bool = true,
        onProgress: @escaping () -> Void, onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        let context = Context(dataDir: dataDir, onProgress: onProgress, onError: onError, refreshOnError: true)
        var added = false
        for entry in pendingEntries {
            if enqueue(Request(stem: entry.stem, fromStage: nil, context: modelsReady ? context : nil)) { added = true }
        }
        if added { drainCallbacks.append(onComplete) }
        startWorker()
    }

    private func startWorker() {
        guard !isStopping, processingTask == nil, lifecycle.queue.contains(where: \.isPrepared) else { return }
        lifecycle.send(.workerStarted)
        processingTask = Task { [self] in
            let activity = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiatedAllowingIdleSystemSleep, .idleSystemSleepDisabled],
                reason: "Processing CaptainsLog recordings"
            )
            defer { ProcessInfo.processInfo.endActivity(activity) }
            while !Task.isCancelled, let item = lifecycle.queue.first(where: \.isPrepared) {
                guard let request = requests.removeValue(forKey: item.stem),
                      let context = request.context else {
                    lifecycle.discardQueued(stem: item.stem)
                    continue
                }
                lifecycle.send(.processingStarted(request.stem))
                do {
                    let detected: Pipeline.Stage
                    if let requested = request.fromStage {
                        detected = requested
                    } else {
                        let stem = request.stem, dataDir = context.dataDir
                        detected = await Task.detached(priority: .utility) {
                            Pipeline.detectNextStage(stem: stem, dataDir: dataDir)
                        }.value
                    }
                    try Task.checkCancellation()
                    lifecycle.send(.processingProgress(request.stem, detected))
                    if detected != .done {
                        _ = try await runPipeline(stem: request.stem, dataDir: context.dataDir, fromStage: detected)
                    }
                    try Task.checkCancellation()
                    lifecycle.send(.processingCompleted(request.stem))
                    context.onProgress()
                } catch {
                    guard !Task.isCancelled else { break }
                    recordFailure(error, for: request.stem)
                    if context.refreshOnError { context.onProgress() }
                    context.onError(error)
                }
            }
            let cleanup = cleanupAfterCancellation
            cleanupAfterCancellation = nil
            cleanup?()
            lifecycle.send(.workerDrained)
            processingTask = nil
            guard !Task.isCancelled else {
                // Resume, batch, reprocess and new recordings all use this handoff.
                startWorker()
                return
            }
            let callbacks = drainCallbacks
            drainCallbacks.removeAll()
            if !callbacks.isEmpty { lifecycle.send(.queueCompleted) }
            for callback in callbacks { callback() }
        }
    }

    func resetAfterDeletingOutputs() {
        guard !hasScheduledWork else { return }
        lifecycle.send(.outputsDeleted)
    }

    /// Consume progress in order before reporting completion. Unawaited UI-update tasks
    /// can otherwise outlive the pipeline or a cancelled attempt for the same stem.
    private func runPipeline(
        stem: String,
        dataDir: String,
        fromStage: Pipeline.Stage?
    ) async throws -> Pipeline.Result {
        let (updates, continuation) = AsyncStream<Pipeline.Progress>.makeStream()
        let resumePipeline = resumePipeline
        let task = Task {
            defer { continuation.finish() }
            return try await resumePipeline(stem, dataDir, fromStage) { progress in
                continuation.yield(progress)
            }
        }
        return try await withTaskCancellationHandler {
            for await progress in updates {
                guard !Task.isCancelled, processingStem == progress.stem else { continue }
                lifecycle.send(.processingProgress(progress.stem, progress.stage))
            }
            let result = try await task.value
            try Task.checkCancellation()
            return result
        } onCancel: {
            task.cancel()
            continuation.finish()
        }
    }

    private func recordFailure(_ error: Error, for stem: String) {
        if Task.isCancelled || error.isNetworkCancellation {
            lifecycle.send(.processingInterrupted)
        } else {
            #if DEBUG
            AppPerformanceTrace.mark("pipeline-failed")
            AppPerformanceTrace.mark("pipeline-error " + error.localizedDescription.replacingOccurrences(of: "\n", with: " "))
            #endif
            lifecycle.send(.processingFailed(stem, error.localizedDescription))
        }
    }

    func recordPreparationFailure(_ error: Error, for stem: String) {
        if hasScheduledWork {
            lifecycle.send(.processingFailed(stem, error.localizedDescription))
            return
        }
        recordFailure(error, for: stem)
    }

}

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

    public var stage: AppStage = .idle
    public var statusMessage = "Ready to record"
    public var errorMessage: String?
    public var processingStem: String?
    private(set) var failedEntries: [String: String] = [:]

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
    private var ownedStem: String?
    private var cleanupAfterCancellation: (() -> Void)?
    private var requests: [Request] = []
    private var drainCallbacks: [() -> Void] = []
    private var isStopping = false
    private let resumePipeline: PipelineResume

    var hasScheduledWork: Bool { processingTask != nil || !requests.isEmpty }
    public var isProcessing: Bool {
        processingTask?.isCancelled == false || requests.contains { $0.context != nil }
            || [.transcribing, .cleaning, .categorizing, .naming, .enriching].contains(stage)
    }

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
    func isQueued(stem: String) -> Bool { requests.contains { $0.stem == stem } }
    func ownsEntry(stem: String) -> Bool { ownedStem == stem || processingStem == stem || isQueued(stem: stem) }

    func canQueueReprocessing(stem: String) -> Bool {
        !isStopping && !isQueued(stem: stem)
            && !(ownedStem == stem && processingTask?.isCancelled == false)
    }

    @discardableResult
    private func enqueue(_ request: Request) -> Bool {
        guard canQueueReprocessing(stem: request.stem) else { return false }
        requests.append(request)
        errorMessage = nil
        failedEntries.removeValue(forKey: request.stem)
        if processingTask?.isCancelled == true, request.context != nil {
            statusMessage = "Waiting for previous processing to stop…"
        }
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
        for index in requests.indices where requests[index].context == nil {
            requests[index].context = context
            configured = true
        }
        if configured { drainCallbacks.append(onComplete) }
        startWorker()
    }

    public func pauseProcessing() {
        requests.removeAll()
        drainCallbacks.removeAll()
        processingTask?.cancel()
        stage = .idle
        statusMessage = "Paused"
        processingStem = nil
    }

    public func stopForTermination() async {
        isStopping = true
        let task = processingTask
        pauseProcessing()
        await task?.value
    }

    func resumeEntry(
        stem: String, fromStage: Pipeline.Stage? = nil, dataDir: String,
        onComplete: @escaping () -> Void, onError: @escaping (Error) -> Void
    ) {
        enqueue(Request(stem: stem, fromStage: fromStage,
                        context: Context(dataDir: dataDir, onProgress: onComplete, onError: onError)))
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
                    requests.removeAll { $0.stem == stem }
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
        pendingEntries: [LogEntry], dataDir: String,
        onProgress: @escaping () -> Void, onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        let context = Context(dataDir: dataDir, onProgress: onProgress, onError: onError, refreshOnError: true)
        var added = false
        for entry in pendingEntries {
            if enqueue(Request(stem: entry.stem, fromStage: nil, context: context)) { added = true }
        }
        if added { drainCallbacks.append(onComplete) }
        startWorker()
    }

    private func startWorker() {
        guard !isStopping, processingTask == nil, requests.contains(where: { $0.context != nil }) else {
            if processingTask?.isCancelled == true, requests.contains(where: { $0.context != nil }) {
                statusMessage = "Waiting for previous processing to stop…"
            }
            return
        }
        processingTask = Task { [self] in
            let activity = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiatedAllowingIdleSystemSleep, .idleSystemSleepDisabled],
                reason: "Processing CaptainsLog recordings"
            )
            defer { ProcessInfo.processInfo.endActivity(activity) }
            while !Task.isCancelled, let index = requests.firstIndex(where: { $0.context != nil }) {
                let request = requests.remove(at: index)
                guard let context = request.context else { continue }
                ownedStem = request.stem
                processingStem = request.stem
                do {
                    let detected = request.fromStage ?? Pipeline.detectNextStage(stem: request.stem, dataDir: context.dataDir)
                    stage = Self.appStage(for: detected)
                    statusMessage = "Processing \(request.stem)..."
                    if detected != .done {
                        _ = try await runPipeline(stem: request.stem, dataDir: context.dataDir, fromStage: detected)
                    }
                    try Task.checkCancellation()
                    failedEntries.removeValue(forKey: request.stem)
                    ownedStem = nil
                    processingStem = nil
                    stage = .done
                    statusMessage = "Done"
                    context.onProgress()
                } catch {
                    guard !Task.isCancelled else { break }
                    ownedStem = nil
                    recordFailure(error, for: request.stem)
                    if context.refreshOnError { context.onProgress() }
                    context.onError(error)
                }
            }
            let cleanup = cleanupAfterCancellation
            cleanupAfterCancellation = nil
            cleanup?()
            ownedStem = nil
            processingTask = nil
            guard !Task.isCancelled else {
                // Resume, batch, reprocess and new recordings all use this handoff.
                startWorker()
                return
            }
            let callbacks = drainCallbacks
            drainCallbacks.removeAll()
            if !callbacks.isEmpty { stage = .done; statusMessage = "Done" }
            for callback in callbacks { callback() }
        }
    }

    func resetAfterDeletingOutputs() {
        guard !hasScheduledWork else { return }
        failedEntries = [:]
        errorMessage = nil
        stage = .idle
        statusMessage = "Ready to process"
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
                stage = Self.appStage(for: progress.stage)
                statusMessage = "\(progress.stage.rawValue.capitalized)..."
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
        processingStem = nil
        if Task.isCancelled || error.isNetworkCancellation {
            stage = .idle
            statusMessage = "Paused"
        } else {
            #if DEBUG
            AppPerformanceTrace.mark("pipeline-failed")
            AppPerformanceTrace.mark("pipeline-error " + error.localizedDescription.replacingOccurrences(of: "\n", with: " "))
            #endif
            failedEntries[stem] = error.localizedDescription
            errorMessage = error.localizedDescription
            stage = .idle
            statusMessage = "Processing failed. Retry available."
        }
    }

    func recordPreparationFailure(_ error: Error, for stem: String) {
        if hasScheduledWork {
            failedEntries[stem] = error.localizedDescription
            errorMessage = error.localizedDescription
            return
        }
        recordFailure(error, for: stem)
    }

    private static func appStage(for s: Pipeline.Stage) -> AppStage {
        switch s {
        case .recording:    return .recording
        case .transcribing: return .transcribing
        case .cleaning:     return .cleaning
        case .categorizing: return .categorizing
        case .naming:       return .naming
        case .enriching:    return .enriching
        case .done:         return .done
        }
    }

}

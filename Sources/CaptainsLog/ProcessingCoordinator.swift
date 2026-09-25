import CaptainsLogCore
import Foundation

/// Coordinates the audio processing pipeline stages (transcribe → cleanup → categorize → naming → enrich).
@MainActor
@Observable
public final class ProcessingCoordinator {
    typealias PipelineResume = @Sendable (
        _ stem: String,
        _ dataDir: String,
        _ fromStage: Pipeline.Stage?,
        _ progress: (@Sendable (Pipeline.Progress) -> Void)?
    ) async throws -> Pipeline.Result

    public var stage: AppStage = .idle
    public var statusMessage = "Ready to record"
    public var errorMessage: String?
    public var processingStem: String?
    private(set) var failedEntries: [String: String] = [:]

    private var processingTask: Task<Void, Never>?
    private var pendingProcessingStems: [String] = []
    private let resumePipeline: PipelineResume

    public var isProcessing: Bool {
        [.transcribing, .cleaning, .categorizing, .naming, .enriching].contains(stage)
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
        self.resumePipeline = { stem, dataDir, fromStage, progress in
            try await Pipeline.resume(
                stem: stem,
                dataDir: dataDir,
                fromStage: fromStage,
                progress: progress
            )
        }
    }

    init(resumePipeline: @escaping PipelineResume) {
        self.resumePipeline = resumePipeline
    }

    func failureMessage(for stem: String) -> String? {
        failedEntries[stem]
    }

    /// Queue a stem for processing (called when recording completes).
    func queueProcessing(stem: String) {
        pendingProcessingStems.append(stem)
    }

    /// Start draining the pending queue.
    func startProcessing(
        dataDir: String,
        isRecording: Bool,
        onProgress: @escaping () -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        guard !pendingProcessingStems.isEmpty, processingTask == nil else { return }

        processingTask = Task { [self] in
            while !pendingProcessingStems.isEmpty {
                guard !Task.isCancelled else { break }
                let stem = pendingProcessingStems.removeFirst()
                processingStem = stem
                failedEntries.removeValue(forKey: stem)
                do {
                    _ = try await resumePipeline(
                        stem,
                        dataDir,
                        .transcribing,
                        { [weak self] p in
                            Task { @MainActor in
                                guard let self else { return }
                                self.stage = Self.appStage(for: p.stage)
                                self.statusMessage = "\(p.stage.rawValue.capitalized)..."
                            }
                        }
                    )
                    failedEntries.removeValue(forKey: stem)
                    onProgress()
                } catch {
                    if Task.isCancelled { break }
                    recordFailure(error, for: stem)
                    onProgress()
                    onError(error)
                    continue
                }
            }
            if !isRecording {
                stage = .done
                statusMessage = "Done"
            }
            processingStem = nil
            processingTask = nil
            onComplete()
        }
    }

    /// Pause/cancel current processing.
    public func pauseProcessing() {
        processingTask?.cancel()
        processingTask = nil
        pendingProcessingStems = []
        stage = .idle
        statusMessage = "Paused"
        processingStem = nil
    }

    /// Resume a specific entry from a given stage.
    func resumeEntry(
        stem: String,
        fromStage: Pipeline.Stage? = nil,
        dataDir: String,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        guard processingTask == nil else { return }
        errorMessage = nil
        failedEntries.removeValue(forKey: stem)
        processingStem = stem
        processingTask = Task {
            await runResume(stem: stem, fromStage: fromStage, dataDir: dataDir, onComplete: onComplete, onError: onError)
        }
    }

    /// Batch resume all pending entries.
    func batchResumePending(
        pendingEntries: [LogEntry],
        dataDir: String,
        onProgress: @escaping () -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        guard processingTask == nil else { return }
        guard !pendingEntries.isEmpty else { return }

        errorMessage = nil
        processingTask = Task { [self] in
            for entry in pendingEntries {
                guard !Task.isCancelled else { break }
                processingStem = entry.stem
                failedEntries.removeValue(forKey: entry.stem)
                do {
                    let detected = Pipeline.detectNextStage(stem: entry.stem, dataDir: dataDir)
                    guard detected != .done else { continue }
                    stage = Self.appStage(for: detected)
                    statusMessage = "Processing \(entry.displayName)..."
                    _ = try await resumePipeline(
                        entry.stem,
                        dataDir,
                        detected,
                        { [weak self] p in
                            Task { @MainActor in
                                guard let self else { return }
                                self.stage = Self.appStage(for: p.stage)
                                self.statusMessage = "\(p.stage.rawValue.capitalized)..."
                            }
                        }
                    )
                    failedEntries.removeValue(forKey: entry.stem)
                    onProgress()
                } catch {
                    if Task.isCancelled { break }
                    recordFailure(error, for: entry.stem)
                    onProgress()
                    onError(error)
                    continue
                }
            }
            stage = .done
            statusMessage = "Done"
            processingStem = nil
            processingTask = nil
            onComplete()
        }
    }

    private func runResume(
        stem: String,
        fromStage: Pipeline.Stage?,
        dataDir: String,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        do {
            let detected = fromStage ?? Pipeline.detectNextStage(stem: stem, dataDir: dataDir)
            stage = Self.appStage(for: detected)
            statusMessage = "Resuming \(detected.rawValue)..."

            _ = try await resumePipeline(
                stem,
                dataDir,
                detected,
                // The Task hop keeps UI updates on the main actor.
                { [weak self] p in
                            Task { @MainActor in
                                guard let self else { return }
                                self.stage = Self.appStage(for: p.stage)
                                self.statusMessage = "\(p.stage.rawValue.capitalized)..."
                            }
                        }
            )
            failedEntries.removeValue(forKey: stem)
            stage = .done
            statusMessage = "Done"
            processingStem = nil
            processingTask = nil
            onComplete()
        } catch {
            processingTask = nil
            recordFailure(error, for: stem)
            onError(error)
        }
    }

    private func recordFailure(_ error: Error, for stem: String) {
        processingStem = nil
        if Task.isCancelled || error.isNetworkCancellation {
            stage = .idle
            statusMessage = "Paused"
        } else {
            failedEntries[stem] = error.localizedDescription
            errorMessage = error.localizedDescription
            stage = .idle
            statusMessage = "Processing failed. Retry available."
        }
    }

    func recordPreparationFailure(_ error: Error, for stem: String) {
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

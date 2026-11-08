import CaptainsLogCore
import Foundation

/// The application has concurrent activities, so its state is a product of regions,
/// rather than one mutually exclusive label. Only this machine owns lifecycle state;
/// managers hold the tasks and perform effects after sending a transition.
@MainActor
@Observable
public final class AppLifecycle {
    enum Recording: Equatable {
        case idle, recording, paused, finishing
        var isActive: Bool { self != .idle }
    }

    struct QueuedProcessing: Equatable {
        let stem: String
        var isPrepared: Bool
    }

    enum Worker: Equatable { case idle, running, draining }

    enum Event {
        case recordingStarted, recordingPaused, recordingResumed, recordingFinishing, recordingStopped
        case recordingFailed(String), recordingError(String?)
        case modelState(ModelState), modelsMissing(Bool)
        case modelDownloadStarted(UUID, String), modelDownloadProgress(UUID, Double), modelDownloadFinished(UUID)
        case processingStage(AppStage), processingMessage(String), processingError(String?)
        case processingStem(String?)
        case workerStarted, processingStarted(String), processingCompleted(String)
        case processingProgress(String, Pipeline.Stage)
        case processingFailed(String, String), processingInterrupted, processingPaused, workerDrained, queueCompleted
        case outputsDeleted
        case updateChecking(Bool), updateInstalling(Bool), updateRestarting(Bool), updateNeedsRestart(Bool)
        case terminating
    }

    private(set) var recording: Recording = .idle
    private(set) var recordingError: String?
    private(set) var modelState: ModelState = .ready
    private(set) var needsModels = false
    private var activeModelDownload: UUID?
    private(set) var processingStage: AppStage = .idle
    private(set) var processingMessage = "Ready to record"
    private(set) var processingError: String?
    private(set) var processingStem: String?
    private(set) var ownedStem: String?
    private(set) var queue: [QueuedProcessing] = []
    private(set) var failedEntries: [String: String] = [:]
    private(set) var worker: Worker = .idle
    private(set) var isTerminating = false
    private(set) var updateChecking = false
    private(set) var updateInstalling = false
    private(set) var updateRestarting = false
    private(set) var updateNeedsRestart = false

    var modelsReady: Bool { modelState == .ready && !needsModels }
    var isRecording: Bool { recording.isActive }
    var isRecordingPaused: Bool { recording == .paused }
    var hasScheduledWork: Bool { worker != .idle || !queue.isEmpty }
    var isProcessing: Bool {
        worker == .running || queue.contains(where: \.isPrepared)
            || [.transcribing, .cleaning, .categorizing, .naming, .enriching].contains(processingStage)
    }
    var canStartWork: Bool { !isTerminating && !updateInstalling && !updateNeedsRestart }
    var canStartRecording: Bool { canStartWork && !isRecording }
    var canInstallUpdate: Bool {
        canStartWork && !updateChecking && !isRecording && !hasScheduledWork && !isProcessing && modelState == .ready
    }
    var canChangeDataDirectory: Bool {
        !isRecording && !hasScheduledWork && !isProcessing && processingStem == nil
    }

    /// A single projection used in Logs, Settings and the menu, including waiting
    /// work. Recording remains visible independently while the pipeline runs.
    var modelStatusMessage: String {
        switch modelState {
        case .ready: return needsModels ? "Local models unavailable" : "Local models ready"
        case .downloading(let model, _):
            return model == "Initializing…" ? "Checking local models…" : "Downloading \(model)"
        case .error(let message): return message
        }
    }

    var showsProgress: Bool {
        if case .downloading = modelState { return true }
        return isProcessing || worker == .draining || updateInstalling || recording == .finishing
    }

    var hasActivity: Bool {
        isRecording || isProcessing || hasScheduledWork || modelState != .ready
            || updateInstalling || updateNeedsRestart
    }

    var statusMessage: String {
        if updateInstalling { return "Installing update…" }
        if updateNeedsRestart { return "Update installed. Restart CaptainsLog." }
        var parts: [String] = []
        if recording == .finishing { parts.append("Saving recording…") }
        else if isRecording { parts.append(isRecordingPaused ? "Recording paused" : "Recording") }
        if modelState != .ready { parts.append(modelStatusMessage) }
        if worker == .draining { parts.append("Waiting for previous processing to stop…") }
        else if let stem = processingStem {
            parts.append("\(processingStage.rawValue.capitalized): \(stem)")
        } else if !queue.isEmpty && !modelsReady { parts.append("Waiting for local models") }
        if !queue.isEmpty { parts.append("\(queue.count) queued") }
        if parts.isEmpty { return processingMessage }
        return parts.joined(separator: " · ")
    }

    func canQueue(stem: String) -> Bool {
        canStartWork && !queue.contains { $0.stem == stem }
            && !(ownedStem == stem && worker == .running)
    }

    @discardableResult
    func enqueue(stem: String, prepared: Bool) -> Bool {
        guard canQueue(stem: stem) else { return false }
        queue.append(QueuedProcessing(stem: stem, isPrepared: prepared))
        processingError = nil
        failedEntries.removeValue(forKey: stem)
        if worker == .draining && prepared { processingMessage = "Waiting for previous processing to stop…" }
        return true
    }

    func prepareQueued(stem: String) {
        guard let index = queue.firstIndex(where: { $0.stem == stem }) else { return }
        queue[index].isPrepared = true
    }

    func discardQueued(stem: String) {
        queue.removeAll { $0.stem == stem }
    }

    func send(_ event: Event) {
        switch event {
        case .recordingStarted:
            guard canStartRecording else { return }
            recording = .recording
            if processingStage == .error && processingError == recordingError {
                processingError = nil
                processingStage = .idle
                processingMessage = "Ready to record"
            }
            recordingError = nil
        case .recordingPaused:
            if recording == .recording { recording = .paused }
        case .recordingResumed:
            if recording == .paused { recording = .recording }
        case .recordingFinishing:
            if isRecording { recording = .finishing }
        case .recordingStopped: recording = .idle
        case .recordingError(let message): recordingError = message
        case .recordingFailed(let message):
            recording = .idle
            recordingError = message
            if !isProcessing {
                processingStage = .error
                processingError = message
                processingMessage = "Error: \(message)"
            }
        case .modelState(let state):
            modelState = state
            if case .downloading = state {} else { activeModelDownload = nil }
        case .modelsMissing(let missing): needsModels = missing
        case .modelDownloadStarted(let id, let name):
            activeModelDownload = id
            modelState = .downloading(model: name, progress: 0)
        case .modelDownloadProgress(let id, let progress):
            guard activeModelDownload == id, case .downloading(let model, _) = modelState else { return }
            modelState = .downloading(model: model, progress: min(1, max(0, progress)))
        case .modelDownloadFinished(let id):
            if activeModelDownload == id { activeModelDownload = nil }
        case .processingStage(let stage): processingStage = stage
        case .processingMessage(let message): processingMessage = message
        case .processingError(let error): processingError = error
        case .processingStem(let stem): processingStem = stem
        case .workerStarted: worker = .running
        case .processingStarted(let stem):
            queue.removeAll { $0.stem == stem }
            ownedStem = stem
            processingStem = stem
        case .processingProgress(let stem, let stage):
            guard worker == .running, processingStem == stem else { return }
            processingStage = Self.appStage(for: stage)
            processingMessage = "\(stage.rawValue.capitalized)..."
        case .processingCompleted(let stem):
            failedEntries.removeValue(forKey: stem)
            ownedStem = nil
            processingStem = nil
            processingStage = .done
            processingMessage = "Done"
        case .processingFailed(let stem, let message):
            failedEntries[stem] = message
            processingError = message
            if ownedStem == stem { ownedStem = nil; processingStem = nil }
            if worker != .running || processingStem == nil {
                processingStage = .idle
                processingMessage = "Processing failed. Retry available."
            }
        case .processingInterrupted:
            ownedStem = nil
            processingStem = nil
            processingStage = .idle
            processingMessage = "Paused"
        case .queueCompleted:
            processingStage = .done
            processingMessage = "Done"
        case .processingPaused:
            queue.removeAll()
            worker = worker == .idle ? .idle : .draining
            processingStage = .idle
            processingStem = nil
            processingMessage = "Paused"
        case .workerDrained:
            worker = .idle
            ownedStem = nil
        case .outputsDeleted:
            guard !hasScheduledWork else { return }
            failedEntries = [:]
            processingError = nil
            processingStage = .idle
            processingMessage = "Ready to process"
        case .updateChecking(let value): updateChecking = value
        case .updateInstalling(let value): updateInstalling = value
        case .updateRestarting(let value): updateRestarting = value
        case .updateNeedsRestart(let value): updateNeedsRestart = value
        case .terminating: isTerminating = true
        }
    }

    static func appStage(for stage: Pipeline.Stage) -> AppStage {
        switch stage {
        case .recording: return .recording
        case .transcribing: return .transcribing
        case .cleaning: return .cleaning
        case .categorizing: return .categorizing
        case .naming: return .naming
        case .enriching: return .enriching
        case .done: return .done
        }
    }
}

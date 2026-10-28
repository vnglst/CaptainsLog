import CaptainsLogCore
import Foundation

extension AppState {
    /// Keep eligibility beside the operation so every caller observes the same
    /// recording, queue, search and update exclusions.
    var canDeleteModels: Bool {
        guard ProcessInfo.processInfo.environment["CAPTAINSLOG_DEMO_MODE"] != "1",
              !isRecording, !isProcessing, !processing.hasScheduledWork,
              !search.isActive, !updates.isInstalling else { return false }
        if case .downloading = modelState { return false }
        return true
    }

    func deleteModel(_ model: ModelStorage.Model) throws {
        guard canDeleteModels else { throw ModelDeletionError.busy }
        defer {
            let saved = CaptainsLogConfig.load()
            config.whisperModelFolder = saved.whisperModelFolder ?? ""
            config.qwenModelFolder = saved.qwenModelFolder ?? ""
        }
        if model == .embeddings { search.releaseModel() }
        // This synchronous main-actor operation cannot yield between checking
        // eligibility and deleting files to another recording or processing action.
        models.didDeleteModel(model)
        try ModelStorage.delete(model)
    }
}

private enum ModelDeletionError: LocalizedError {
    case busy

    var errorDescription: String? {
        "Wait for recording, processing, search and model setup to finish before deleting a model."
    }
}

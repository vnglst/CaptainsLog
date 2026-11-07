import CaptainsLogCore
import Foundation

public enum ModelState: Equatable {
    case downloading(model: String, progress: Double)
    case ready
    case error(String)
}

/// Manages ML model downloads and readiness state.
@MainActor
@Observable
public final class ModelManager {
    typealias DownloadOperation = @Sendable (
        _ progress: @escaping @Sendable (Progress) -> Void
    ) async throws -> Void

    struct Dependencies: Sendable {
        let clearStaleConfig: @Sendable () -> Void
        let cleanCorruptedMetadata: @Sendable () -> Void
        let whisperIsDownloaded: @Sendable () -> Bool
        let qwenIsDownloaded: @Sendable () -> Bool
        let downloadWhisper: DownloadOperation
        let downloadQwen: DownloadOperation
    }

    public var modelState: ModelState = .ready
    private let dependencies: Dependencies
    private var activeDownloadID: UUID?
    private var readyCallbacks: [@MainActor () -> Void] = []

    public private(set) var needsDownload = false
    public var modelsReady: Bool { modelState == .ready && !needsDownload }

    func didDeleteModel(_ model: ModelStorage.Model) {
        if model != .embeddings {
            needsDownload = true
            modelState = .ready
        }
    }

    public init() {
        self.dependencies = Dependencies(
            clearStaleConfig: { Self.clearStaleModelConfig() },
            cleanCorruptedMetadata: { Self.cleanCorruptedModelMetadata() },
            whisperIsDownloaded: { Self.whisperModelIsDownloaded() },
            qwenIsDownloaded: { Self.qwenModelIsDownloaded() },
            downloadWhisper: { progress in try await Transcriber.download(progressCallback: progress) },
            downloadQwen: { progress in try await LLM.download(progressHandler: progress) }
        )
    }

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func ensureModelsDownloaded(onReady: (@MainActor () -> Void)? = nil) {
        if let onReady { readyCallbacks.append(onReady) }
        if case .downloading = modelState { return }
        modelState = .downloading(model: "Initializing…", progress: 0)
        Task {
            await downloadModelsIfNeeded()
            let callbacks = readyCallbacks
            readyCallbacks.removeAll()
            if modelsReady { callbacks.forEach { $0() } }
        }
    }

    func downloadModelsIfNeeded() async {
        modelState = .downloading(model: "Initializing…", progress: 0)
        // These checks walk model and Core ML cache directories. Running them on
        // the main actor used to make the freshly-rendered record dock unresponsive.
        let dependencies = dependencies
        let availability = await Task.detached(priority: .utility) {
            dependencies.clearStaleConfig()
            // Recovery scans CoreML's temporary cache and download sidecars. A
            // prepared model needs only its availability check on normal launch.
            var whisper = dependencies.whisperIsDownloaded()
            let qwen = dependencies.qwenIsDownloaded()
            if !whisper {
                dependencies.cleanCorruptedMetadata()
                whisper = dependencies.whisperIsDownloaded()
            }
            return (whisper: whisper, qwen: qwen)
        }.value

        needsDownload = !availability.whisper || !availability.qwen
        if !needsDownload {
            modelState = .ready
            return
        }
        do {
            if !availability.whisper {
                try await downloadModel("Whisper (speech-to-text)", operation: dependencies.downloadWhisper)
            }

            if !availability.qwen {
                try await downloadModel("Qwen 3.5 (text processing)", operation: dependencies.downloadQwen)
            }

            needsDownload = false
            modelState = .ready
        } catch {
            if error is CancellationError || error.isNetworkCancellation {
                modelState = .error("Model download was interrupted. Check your connection and try again.")
            } else {
                let msg = error.localizedDescription
                if msg.contains("metadata") || msg.contains("corrupted") {
                    try? CaptainsLogConfig.update {
                        $0.whisperModelFolder = nil
                        $0.whisperModel = nil
                    }
                }
                modelState = .error(msg)
            }
        }
    }

    private func downloadModel(_ name: String, operation: DownloadOperation) async throws {
        let downloadID = UUID()
        activeDownloadID = downloadID
        defer { activeDownloadID = nil }
        modelState = .downloading(model: name, progress: 0)
        try await operation { [weak self] progress in
            let fraction = progress.fractionCompleted
            Task { @MainActor [weak self] in
                // Download libraries can deliver a final callback after returning or
                // failing. It must not hide an error, readiness, or the next model.
                guard let self, self.activeDownloadID == downloadID else { return }
                self.modelState = .downloading(model: name, progress: min(1, max(0, fraction)))
            }
        }
    }

    nonisolated static func whisperModelIsDownloaded(
        config: CaptainsLogConfig = CaptainsLogConfig.load()
    ) -> Bool {
        guard let folder = config.whisperModelFolder,
              (try? URL(fileURLWithPath: folder).resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        else { return false }
        // A directory can survive a partial download. The mel transform may have
        // no learned weights; encoder/decoder weights and all component bundles
        // are bounded integrity checks before the healthy startup fast path.
        let root = URL(fileURLWithPath: folder)
        let bundlesExist = ["MelSpectrogram", "AudioEncoder", "TextDecoder"].allSatisfy { component in
            (try? root.appendingPathComponent("\(component).mlmodelc")
                .resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        return bundlesExist && ["AudioEncoder", "TextDecoder"].allSatisfy { component in
            FileManager.default.fileExists(atPath: root
                .appendingPathComponent("\(component).mlmodelc/weights/weight.bin").path)
        }
    }

    nonisolated static func qwenModelIsDownloaded(
        config: CaptainsLogConfig = CaptainsLogConfig.load()
    ) -> Bool {
        guard let folder = config.qwenModelFolder,
              (try? URL(fileURLWithPath: folder).resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        else { return false }
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: folder),
              files.contains(where: { $0.hasSuffix(".gguf") })
        else { return false }
        return true
    }

    /// If the saved whisperModelFolder no longer exists on disk, wipe it so WhisperKit
    /// picks a fresh download location rather than trying to use the stale path.
    nonisolated private static func clearStaleModelConfig() {
        let config = CaptainsLogConfig.load()
        guard let folder = config.whisperModelFolder,
              !FileManager.default.fileExists(atPath: folder)
        else { return }
        try? CaptainsLogConfig.update {
            $0.whisperModelFolder = nil
        }
    }

    /// Recovery is needed only before a missing-model download. Genuine model
    /// initialization failures recover in shared Core, after a healthy fast path.
    nonisolated private static func cleanCorruptedModelMetadata() {
        WhisperModelRecovery.prepareDownload()
    }

    nonisolated static func removeDownloadMetadata(in whisperRoot: URL, fileManager: FileManager = .default) {
        WhisperModelRecovery.removeDownloadMetadata(in: whisperRoot, fileManager: fileManager)
    }
}

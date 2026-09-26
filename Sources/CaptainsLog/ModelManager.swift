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

    public var modelsReady: Bool { modelState == .ready }

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
        Task {
            await downloadModelsIfNeeded()
            if modelsReady {
                onReady?()
            }
        }
    }

    func downloadModelsIfNeeded() async {
        modelState = .downloading(model: "Initializing…", progress: 0)
        // These checks walk model and Core ML cache directories. Running them on
        // the main actor used to make the freshly-rendered record dock unresponsive.
        let dependencies = dependencies
        let availability = await Task.detached(priority: .utility) {
            dependencies.clearStaleConfig()
            dependencies.cleanCorruptedMetadata()
            return (
                whisper: dependencies.whisperIsDownloaded(),
                qwen: dependencies.qwenIsDownloaded()
            )
        }.value

        if availability.whisper && availability.qwen {
            modelState = .ready
            return
        }
        do {
            if !availability.whisper {
                modelState = .downloading(model: "Whisper (speech-to-text)", progress: 0)
                try await dependencies.downloadWhisper { progress in
                    Task { @MainActor in
                        let fraction = progress.fractionCompleted
                        if fraction < 1 {
                            self.modelState = .downloading(
                                model: "Whisper (speech-to-text)", progress: fraction)
                        }
                    }
                }
            }

            if !availability.qwen {
                modelState = .downloading(model: "Qwen 3.5 (text processing)", progress: 0)
                try await dependencies.downloadQwen { progress in
                    Task { @MainActor in
                        let fraction = progress.fractionCompleted
                        if fraction < 1 {
                            self.modelState = .downloading(
                                model: "Qwen 3.5 (text processing)", progress: fraction)
                        }
                    }
                }
            }

            modelState = .ready
        } catch is CancellationError {
            modelState = .ready
        } catch {
            if error.isNetworkCancellation {
                modelState = .ready
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

    nonisolated static func whisperModelIsDownloaded(
        config: CaptainsLogConfig = CaptainsLogConfig.load()
    ) -> Bool {
        guard let folder = config.whisperModelFolder,
              (try? URL(fileURLWithPath: folder).resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        else { return false }
        return true
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
            $0.whisperModel = nil
        }
    }

    /// WhisperKit can leave corrupted Hugging Face download metadata behind. The downloader
    /// fails before it can recover when it cannot replace that sidecar, so clear it before
    /// checking or downloading the model.
    ///
    /// WhisperKit can also find a corrupted .mlmodel.metadata file in CoreML's temporary cache.
    /// Delete the entire parent .mlmodelc directory so CoreML can recompile the model cleanly
    /// on next load.
    ///
    /// Also catches incomplete WhisperKit downloads where the pre-compiled .mlmodelc bundle is
    /// missing its weights/weight.bin — in that case the whole model folder is wiped so the
    /// next launch triggers a fresh download.
    nonisolated private static func cleanCorruptedModelMetadata() {
        let fm = FileManager.default

        // Pass 1: metadata corruption in CoreML temp cache
        var mlmodelcDirs: Set<URL> = []
        let tmpRoot = URL(fileURLWithPath: NSTemporaryDirectory())
        if let enumerator = fm.enumerator(at: tmpRoot, includingPropertiesForKeys: nil, options: []) {
            for case let url as URL in enumerator
                where url.lastPathComponent == "model.mlmodel.metadata" {
                let parent = url.deletingLastPathComponent()
                if parent.pathExtension == "mlmodelc" {
                    mlmodelcDirs.insert(parent)
                }
            }
        }
        for dir in mlmodelcDirs {
            try? fm.removeItem(at: dir)
        }

        // Pass 2: incomplete WhisperKit download — .mlmodelc bundles with missing weight.bin.
        // WhisperKit downloads pre-compiled CoreML bundles; a partial download leaves the
        // directory structure intact but omits the binary weight file. Wipe the model config
        // so the next launch re-downloads cleanly.
        guard let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let whisperRoot = caches
            .appendingPathComponent("CaptainsLog/models/whisper", isDirectory: true)

        removeDownloadMetadata(in: whisperRoot, fileManager: fm)

        guard let enumerator = fm.enumerator(
            at: whisperRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for case let url as URL in enumerator where url.pathExtension == "mlmodelc" {
            let weightBin = url.appendingPathComponent("weights/weight.bin")
            if !fm.fileExists(atPath: weightBin.path) {
                try? CaptainsLogConfig.update {
                    $0.whisperModelFolder = nil
                    $0.whisperModel = nil
                }
                return
            }
        }
    }

    nonisolated static func removeDownloadMetadata(in whisperRoot: URL, fileManager: FileManager = .default) {
        guard let enumerator = fileManager.enumerator(
            at: whisperRoot,
            includingPropertiesForKeys: nil,
            options: []
        ) else { return }

        for case let url as URL in enumerator
            where url.lastPathComponent == "config.json.metadata" {
            try? fileManager.removeItem(at: url)
        }
    }
}

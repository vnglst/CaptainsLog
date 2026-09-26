import Foundation
import WhisperKit

public enum Transcriber {

    public static let defaultModel = "openai_whisper-large-v2"

    public typealias CommandOperation = @Sendable (
        _ audioPath: String,
        _ model: String?,
        _ language: String?
    ) async throws -> String

    private static func downloadBaseURL() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches
            .appendingPathComponent("CaptainsLog", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("whisper", isDirectory: true)
    }

    public static func resolveModel(
        _ explicit: String? = nil,
        config: CaptainsLogConfig = CaptainsLogConfig.load()
    ) -> String {
        if let explicit, !explicit.isEmpty {
            return explicit
        }
        if let configured = config.whisperModel, !configured.isEmpty {
            return configured
        }
        return defaultModel
    }

    private static func cachedFolder(
        for requestedModel: String,
        config: CaptainsLogConfig
    ) -> String? {
        guard config.whisperModel == requestedModel,
            let folder = config.whisperModelFolder,
            FileManager.default.fileExists(atPath: folder)
        else {
            return nil
        }
        return folder
    }

    public static func download(
        model: String? = nil,
        progressCallback: (@Sendable (Progress) -> Void)? = nil
    ) async throws {
        let requestedModel = resolveModel(model)
        let url = try await WhisperKit.download(
            variant: requestedModel,
            downloadBase: downloadBaseURL(),
            progressCallback: progressCallback)
        try? CaptainsLogConfig.update {
            $0.whisperModelFolder = url.path
            $0.whisperModel = requestedModel
        }
    }

    public static func transcribe(
        audioPath: String,
        model: String? = nil,
        language: String? = nil
    ) async throws -> String {
        var cfg = CaptainsLogConfig.load()
        let requestedModel = resolveModel(model, config: cfg)
        var cachedFolder = Self.cachedFolder(for: requestedModel, config: cfg)

        if cachedFolder == nil {
            Logger.transcriber.info("No cached Whisper model for \(requestedModel) — downloading once to populate cache...")
            try await download(model: requestedModel)
            cfg = CaptainsLogConfig.load()
            cachedFolder = Self.cachedFolder(for: requestedModel, config: cfg)
        }

        guard let folder = cachedFolder else {
            throw TranscriberError.noModelFolder
        }

        Logger.transcriber.info("Loading WhisperKit from \(folder)...")
        let computeOptions = ModelComputeOptions(
            audioEncoderCompute: .cpuAndGPU,
            textDecoderCompute: .cpuAndGPU
        )
        let whisperConfig = WhisperKitConfig(
            modelFolder: folder,
            computeOptions: computeOptions
        )

        let start = Date()
        let pipe: WhisperKit
        do {
            pipe = try await WhisperKit(whisperConfig)
        } catch {
            // CoreML failed to open the compiled model — likely an incomplete download
            // (e.g. missing weights/weight.bin). Clear the cached folder so the next
            // call triggers a fresh download rather than hitting the same corrupt files.
            try? CaptainsLogConfig.update {
                $0.whisperModelFolder = nil
                $0.whisperModel = nil
            }
            throw error
        }

        let loadTime = Date().timeIntervalSince(start)
        Logger.transcriber.info("WhisperKit loaded in \(String(format: "%.1f", loadTime))s")

        Logger.transcriber.info("Transcribing \(audioPath)...")
        let transcribeStart = Date()

        let result = try await pipe.transcribe(
            audioPath: audioPath,
            decodeOptions: DecodingOptions(
                language: language,
                detectLanguage: language == nil ? true : nil,
                skipSpecialTokens: true
            )
        )

        let transcribeTime = Date().timeIntervalSince(transcribeStart)
        Logger.transcriber.info("Transcribed in \(String(format: "%.1f", transcribeTime))s")

        // `pipe` goes out of scope here, releasing WhisperKit's internal AVAudioEngine
        // so subsequent recordings can acquire the audio session cleanly.
        guard !result.isEmpty else {
            throw TranscriberError.noOutput
        }

        return result.map { $0.text }.joined(separator: " ").trimmingCharacters(in: CharacterSet.whitespaces)
    }

    /// Runs the input validation, transcription, and output part of the transcribe CLI command with injectable inference.
    public static func runCommand(
        inputPath: String,
        outputPath: String? = nil,
        model: String? = nil,
        language: String? = nil,
        operation: CommandOperation
    ) async throws -> String {
        let resolvedOutputPath = outputPath ?? defaultOutputPath(for: inputPath)
        try FileSystemGuard.requireFreeSpaceForTranscription(paths: [
            resolvedOutputPath,
            CaptainsLogConfig.configURL.path,
            NSTemporaryDirectory(),
        ])
        let transcript = try await operation(inputPath, model, language)
        try FileSystemGuard.writeText(transcript, to: resolvedOutputPath)
        print("Transcript saved to \(resolvedOutputPath)")
        return transcript
    }

    private static func defaultOutputPath(for inputPath: String) -> String {
        let url = URL(fileURLWithPath: inputPath)
        return url.deletingPathExtension().appendingPathExtension("md").path
    }

    enum TranscriberError: LocalizedError {
        case noOutput
        case noModelFolder

        var errorDescription: String? {
            switch self {
            case .noOutput: return "Whisper produced no output for the given audio."
            case .noModelFolder: return "No Whisper model folder available — download failed to populate cache."
            }
        }
    }
}

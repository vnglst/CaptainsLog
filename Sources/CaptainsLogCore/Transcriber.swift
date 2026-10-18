import AVFoundation
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

    final class RecordingSession: @unchecked Sendable {
        var pipe: WhisperKit?
        var model: String?
        var language: String?
        init() throws { try NativeInferenceLifecycle.shared.beginResource() }
        deinit {
            pipe = nil
            NativeInferenceLifecycle.shared.endResource()
        }
    }

    public static func transcribe(
        audioPath: String,
        model: String? = nil,
        language: String? = nil
    ) async throws -> String {
        if let prepared = await RecordingTranscription.take(audioPath, model: model, language: language) {
            AppPerformanceTrace.mark("recording-transcript-reused")
            return prepared
        }
        try Task.checkCancellation()
        return try await transcribe(audioPath: audioPath, model: model, language: language, onlyIfIdle: false)
    }

    static func transcribe(
        audioPath: String,
        model: String? = nil,
        language: String? = nil,
        onlyIfIdle: Bool,
        session: RecordingSession? = nil
    ) async throws -> String {
        AppPerformanceTrace.mark("whisper-input-ready")
        let inputURL = URL(fileURLWithPath: audioPath)
        let readableURL = try await prepareAudio(inputURL)
        defer {
            if readableURL != inputURL { try? FileManager.default.removeItem(at: readableURL) }
        }
        AppPerformanceTrace.mark("whisper-audio-ready")
        var cfg = CaptainsLogConfig.load()
        let requestedModel = resolveModel(model, config: cfg)
        var cachedFolder = Self.cachedFolder(for: requestedModel, config: cfg)

        if cachedFolder == nil {
            if onlyIfIdle { throw TranscriberError.noModelFolder }
            Logger.transcriber.info("No cached Whisper model for \(requestedModel) — downloading once to populate cache...")
            try await download(model: requestedModel)
            cfg = CaptainsLogConfig.load()
            cachedFolder = Self.cachedFolder(for: requestedModel, config: cfg)
        }

        guard let folder = cachedFolder else {
            throw TranscriberError.noModelFolder
        }

        Logger.transcriber.info("Loading WhisperKit from \(folder)...")
        // CoreML Metal prediction can abort in MPSGraph tensor shape/stride handling.
        // Exclude GPU from every Whisper component; SIGABRT cannot be caught for retry.

        let lifecycle = NativeInferenceLifecycle.shared
        try lifecycle.beginOperation(onlyIfIdle: onlyIfIdle)
        var pipe: WhisperKit? = session?.model == requestedModel ? session?.pipe : nil
        defer {
            // Recording sessions retain their model between chunks; the recorder drains
            // and releases the session before termination can complete.
            pipe = nil
            lifecycle.endOperation()
        }
        let start = Date()
        if pipe == nil {
            pipe = try await loadWithRecovery(
                lifecycle: lifecycle,
                load: {
                    let computeOptions = ModelComputeOptions(
                        melCompute: .cpuOnly,
                        audioEncoderCompute: .cpuAndNeuralEngine,
                        textDecoderCompute: .cpuAndNeuralEngine
                    )
                    let whisperConfig = WhisperKitConfig(
                        modelFolder: folder,
                        computeOptions: computeOptions
                    )

                    #if DEBUG
                    let traceLoading = ProcessInfo.processInfo.environment["CAPTAINSLOG_PERFORMANCE_TRACE"] != nil
                    if traceLoading {
                        whisperConfig.verbose = true
                        whisperConfig.logLevel = .debug
                        Logging.updateCallback { message in
                            AppPerformanceTrace.mark("whisper-loader " + message.replacingOccurrences(of: "\n", with: " "))
                        }
                    }
                    defer { if traceLoading { Logging.updateCallback(nil) } }
                    #endif
                    return try await WhisperKit(whisperConfig)
                },
                recover: { try WhisperModelRecovery.recover(from: $0) },
                clearConfig: {
                    try? CaptainsLogConfig.update {
                        $0.whisperModelFolder = nil
                        $0.whisperModel = nil
                    }
                }
            )

            session?.pipe = pipe
            session?.model = requestedModel
        }
        let loadTime = Date().timeIntervalSince(start)
        Logger.transcriber.info("WhisperKit loaded in \(String(format: "%.1f", loadTime))s")

        Logger.transcriber.info("Transcribing \(audioPath)...")
        let transcribeStart = Date()

        let result = try await pipe!.transcribe(
            audioPath: readableURL.path,
            decodeOptions: DecodingOptions(
                language: language ?? session?.language,
                detectLanguage: language == nil && session?.language == nil ? true : nil,
                skipSpecialTokens: true
            ),
            callback: { _ in
                #if DEBUG
                AppPerformanceTrace.firstDecode()
                #endif
                return shouldContinueDecoding()
            }
        )
        if session?.language == nil { session?.language = result.first?.language }
        // Whisper's early stop returns partial text, which must never become a
        // completed transcription or advance the remaining pipeline stages.
        try lifecycle.checkCancellation()

        let transcribeTime = Date().timeIntervalSince(transcribeStart)
        Logger.transcriber.info("Transcribed in \(String(format: "%.1f", transcribeTime))s")

        // Ordinary calls release Whisper here. Recording sessions reuse it until
        // their worker finishes; audio capture always belongs to Recorder.
        guard !result.isEmpty else {
            throw TranscriberError.noOutput
        }

        return result.map { $0.text }.joined(separator: " ").trimmingCharacters(in: CharacterSet.whitespaces)
    }

    /// Retry initialization once after targeted cache recovery. Intentional
    /// cancellation never clears model settings or starts cache repair.
    static func loadWithRecovery<Value>(
        lifecycle: NativeInferenceLifecycle,
        load: @Sendable () async throws -> Value,
        recover: @Sendable (Error) throws -> Void,
        clearConfig: @Sendable () -> Void
    ) async throws -> Value {
        try lifecycle.checkCancellation()
        do { return try await load() }
        catch {
            let original = error
            try lifecycle.checkCancellation()
            guard !isLoadCancellation(original) else { throw original }
            do {
                try recover(original)
                try lifecycle.checkCancellation()
                return try await load()
            } catch {
                try lifecycle.checkCancellation()
                guard !isLoadCancellation(error) else { throw error }
                clearConfig()
                throw original
            }
        }
    }

    private static func isLoadCancellation(_ error: Error) -> Bool {
        let ns = error as NSError
        return error is CancellationError || (ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled)
    }

    static func shouldContinueDecoding(lifecycle: NativeInferenceLifecycle = .shared) -> Bool {
        do { try lifecycle.checkCancellation(); return true }
        catch { return false }
    }

    /// WhisperKit reads through AVAudioFile, which cannot open QuickTime containers.
    /// Keep the original recording and export only the temporary transcription input.
    static func prepareAudio(_ input: URL) async throws -> URL {
        guard ["mov", "qt", "qta"].contains(input.pathExtension.lowercased()) else { return input }
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLog-\(UUID().uuidString).m4a")
        let asset = AVURLAsset(url: input)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: input.path])
        }
        do {
            try await exporter.export(to: output, as: .m4a)
            return output
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
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

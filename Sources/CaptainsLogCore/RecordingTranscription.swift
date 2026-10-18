import AVFoundation
import Darwin
import Foundation

/// Opportunistic work uses finalized PCM chunks, never the open AAC recording.
/// Any failed or skipped chunk invalidates the whole attempt; the original audio
/// remains the source of truth for the ordinary transcription path.
final class RecordingTranscription: @unchecked Sendable {
    private struct Identity: Equatable, Sendable {
        let size: UInt64
        let modified: Date
        let model: String
        let folder: String?
        static func read(_ path: String, model: String? = nil) -> Identity? {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  let size = attrs[.size] as? UInt64, let modified = attrs[.modificationDate] as? Date else { return nil }
            let config = CaptainsLogConfig.load()
            return Identity(size: size, modified: modified,
                            model: Transcriber.resolveModel(model, config: config), folder: config.whisperModelFolder)
        }
    }
    private actor Results {
        var value: (path: String, identity: Identity, task: Task<String?, Never>)?
        func put(_ path: String, _ task: Task<String?, Never>) {
            value?.task.cancel()
            guard let identity = Identity.read(path) else { task.cancel(); value = nil; return }
            value = (path, identity, task)
        }
        func take(_ path: String, model: String?, language: String?) async -> String? {
            guard let saved = value, saved.path == path else { return nil }
            value = nil
            guard language == nil, saved.identity == Identity.read(path, model: model) else {
                saved.task.cancel()
                _ = await saved.task.value
                return nil
            }
            let text = await withTaskCancellationHandler { await saved.task.value }
                onCancel: { saved.task.cancel() }
            guard !Task.isCancelled, saved.identity == Identity.read(path, model: model) else { return nil }
            return text
        }
        func discard(_ path: String) async {
            guard let saved = value, saved.path == path else { return }
            value = nil
            saved.task.cancel()
            _ = await saved.task.value
        }
    }

    private static let results = Results()
    static func take(_ path: String, model: String? = nil, language: String? = nil) async -> String? {
        await results.take(path, model: model, language: language)
    }
    static func discard(_ path: String) async { await results.discard(path) }

    static func hasCapacity(load: Double, cores: Int, thermal: ProcessInfo.ThermalState) -> Bool {
        cores > 1 && load < Double(cores) * 0.65 && thermal == .nominal
    }

    private static var hasCapacity: Bool {
        var load = [Double](repeating: 0, count: 3)
        guard getloadavg(&load, 3) == 3 else { return false }
        return hasCapacity(load: load[0], cores: ProcessInfo.processInfo.activeProcessorCount,
                           thermal: ProcessInfo.processInfo.thermalState)
    }

    private let directory: URL
    private let stream: AsyncStream<URL>
    private let continuation: AsyncStream<URL>.Continuation
    private var writer: AVAudioFile?
    private var frames: AVAudioFramePosition = 0
    private var currentURL: URL?
    private var failed = false
    private var worker: Task<String?, Never>?
    private let model: String?
    private let folder: String?

    init(
        requireCachedModel: Bool = true,
        capacity: @escaping @Sendable () -> Bool = { RecordingTranscription.hasCapacity },
        transcribe: (@Sendable (String) async throws -> String)? = nil
    ) throws {
        let config = CaptainsLogConfig.load()
        model = config.whisperModel
        folder = config.whisperModelFolder
        if requireCachedModel {
            guard capacity() else {
                AppPerformanceTrace.mark("recording-admission-refused-capacity")
                throw NativeInferenceBusy()
            }
            guard let folder = config.whisperModelFolder, FileManager.default.fileExists(atPath: folder) else {
                AppPerformanceTrace.mark("recording-admission-refused-model")
                throw NativeInferenceBusy()
            }
        }
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("CaptainsLog-recording-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // CoreML initialization can take over 80 seconds on this Mac. Keep
        // four finalized chunks (at most about 160 seconds) queued while the
        // first chunk loads its session, without allowing unbounded PCM growth.
        (stream, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingOldest(4))
        let stream = stream
        let expectedModel = model
        let expectedFolder = folder
        worker = Task.detached(priority: .utility) {
            guard let session = try? Transcriber.RecordingSession() else {
                for await url in stream { try? FileManager.default.removeItem(at: url) }
                return nil
            }
            defer { session.pipe = nil }
            var texts: [String] = []
            var valid = true
            for await url in stream {
                defer { try? FileManager.default.removeItem(at: url) }
                let currentConfig = CaptainsLogConfig.load()
                guard valid else { continue }
                let refusal: String?
                if Task.isCancelled { refusal = "cancelled" }
                else if !capacity() { refusal = "capacity" }
                else if currentConfig.whisperModel != expectedModel || currentConfig.whisperModelFolder != expectedFolder {
                    refusal = "model-changed"
                } else { refusal = nil }
                if let refusal {
                    AppPerformanceTrace.mark("recording-chunk-refused-" + refusal)
                    valid = false
                    session.pipe = nil
                    continue
                }
                do {
                    AppPerformanceTrace.mark("recording-chunk-start")
                    let text: String
                    if let transcribe { text = try await transcribe(url.path) }
                    else { text = try await Transcriber.transcribe(audioPath: url.path, onlyIfIdle: true, session: session) }
                    try Task.checkCancellation()
                    texts.append(text)
                    AppPerformanceTrace.mark("recording-chunk-complete")
                } catch {
                    if error is NativeInferenceBusy {
                        AppPerformanceTrace.mark("recording-chunk-refused-busy")
                    } else if error is CancellationError {
                        AppPerformanceTrace.mark("recording-chunk-refused-cancelled")
                    } else if let failure = error as? Transcriber.TranscriberError, case .noModelFolder = failure {
                        AppPerformanceTrace.mark("recording-chunk-refused-model")
                    } else {
                        AppPerformanceTrace.mark("recording-chunk-refused-error")
                    }
                    AppPerformanceTrace.mark("recording-transcription-fallback")
                    session.pipe = nil
                    valid = false
                }
            }
            return valid && !texts.isEmpty ? texts.joined(separator: " ") : nil
        }
    }

    /// Called only by the serialized audio tap, including while paused (no data).
    func append(_ buffer: RecorderAudioBuffer) {
        guard !failed, let pcm = buffer.nativeBuffer else { failed = true; return }
        do {
            if writer == nil {
                let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
                writer = try AVAudioFile(forWriting: url, settings: pcm.format.settings)
                currentURL = url
            }
            try writer?.write(from: pcm)
            frames += AVAudioFramePosition(pcm.frameLength)
            let seconds = Double(frames) / pcm.format.sampleRate
            // Prefer silence so a word is not cut at the common chunk boundary.
            if (seconds >= 25 && (buffer.rootMeanSquare ?? 1) < 0.01) || seconds >= 40 { flush() }
        } catch { failed = true; writer = nil }
    }

    private func flush() {
        writer = nil // finalize the file before handing it to Whisper
        if frames > 0, let currentURL {
            switch continuation.yield(currentURL) {
            case .enqueued: break
            case .dropped, .terminated:
                AppPerformanceTrace.mark("recording-chunk-refused-backlog")
                // Never let slow speculative inference fill the disk with PCM.
                failed = true
                worker?.cancel()
                try? FileManager.default.removeItem(at: currentURL)
            @unknown default:
                failed = true
                worker?.cancel()
            }
        }
        frames = 0
        currentURL = nil
    }

    /// Close capture immediately; normal pipeline transcription owns the pending
    /// tail task. Cancellation and native resource leases still drain on shutdown.
    func finish(audioPath: String, cancelled: Bool) async {
        if cancelled || failed { worker?.cancel() }
        flush()
        continuation.finish()
        let worker = worker
        let directory = directory
        let expectedModel = model
        let expectedFolder = folder
        let invalid = cancelled || failed || Task.isCancelled
        let pending = Task.detached(priority: .utility) {
            defer { try? FileManager.default.removeItem(at: directory) }
            let text = await withTaskCancellationHandler { await worker?.value }
                onCancel: { worker?.cancel() }
            let config = CaptainsLogConfig.load()
            guard !invalid, !Task.isCancelled, config.whisperModel == expectedModel,
                  config.whisperModelFolder == expectedFolder else { return nil as String? }
            return text
        }
        if invalid {
            pending.cancel()
            _ = await pending.value
        } else {
            await Self.results.put(audioPath, pending)
        }
    }
}

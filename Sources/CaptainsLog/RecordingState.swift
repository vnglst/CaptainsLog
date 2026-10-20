import AVFoundation
import CaptainsLogCore
import Foundation

/// Manages audio recording state, device selection, and recording lifecycle.
@MainActor
@Observable
public final class RecordingState {
    typealias RecordOperation = @Sendable (
        _ url: URL,
        _ deviceUID: String?,
        _ stopTrigger: AsyncStream<Void>,
        _ levelCallback: (@Sendable (Float) -> Void)?,
        _ isPaused: @Sendable @escaping () -> Bool
    ) async throws -> Void

    struct Dependencies {
        let listInputDevices: @Sendable () -> [AudioDevice]
        let defaultInputDevice: @Sendable () -> AudioDevice?
        let record: RecordOperation
    }

    public var recordingDuration: TimeInterval = 0
    public var inputDevices: [AudioDevice] = []
    private var effectiveDeviceUID: String?
    private var preferredDeviceUID: String?
    private let saveDevicePreference: (String?) throws -> Void
    public var selectedDeviceUID: String? {
        get { effectiveDeviceUID }
        set {
            effectiveDeviceUID = newValue
            preferredDeviceUID = newValue
            do { try saveDevicePreference(newValue) }
            catch { fputs("Warning: Failed to save recording device: \(error.localizedDescription)\n", stderr) }
        }
    }
    public var errorMessage: String?
    /// UI-facing pause state — drives SwiftUI redraws.
    public var isRecordingPaused: Bool = false
    /// Holds the audio level for the audio tap closure.
    private final class AudioLevelBox: @unchecked Sendable { var value: Float = 0 }
    private let audioLevelBox = AudioLevelBox()
    public var audioLevel: Float {
        get { audioLevelBox.value }
        set { audioLevelBox.value = newValue }
    }
    /// Holds the pause flag for the audio tap closure.
    private final class PauseFlag: @unchecked Sendable { var value: Bool = false }
    private let pauseFlag = PauseFlag()
    private var tapPaused: Bool {
        get { pauseFlag.value }
        set { pauseFlag.value = newValue }
    }

    private var stopContinuation: AsyncStream<Void>.Continuation?
    private var recordingTimer: Timer?
    private var recordingTask: Task<Void, Never>?
    private var isStopping = false
    private let dependencies: Dependencies

    public var isRecording: Bool {
        #if DEBUG
        if let fixtureIsRecording { return fixtureIsRecording }
        #endif
        return recordingTask != nil
    }

    #if DEBUG
    private var fixtureIsRecording: Bool?

    func applyDesignFixture(isPaused: Bool, duration: TimeInterval, audioLevel: Float) {
        fixtureIsRecording = true
        isRecordingPaused = isPaused
        recordingDuration = duration
        self.audioLevel = audioLevel
    }
    #endif

    public init() {
        let savedPreference = CaptainsLogConfig.load().preferredRecordingDeviceUID
        preferredDeviceUID = savedPreference
        effectiveDeviceUID = savedPreference
        saveDevicePreference = { uid in
            try CaptainsLogConfig.update { $0.preferredRecordingDeviceUID = uid }
        }
        self.dependencies = Dependencies(
            listInputDevices: { Recorder.listInputDevices() },
            defaultInputDevice: { Recorder.defaultInputDevice() },
            record: { url, deviceUID, stopTrigger, levelCallback, isPaused in
                try await Recorder.record(
                    to: url,
                    deviceUID: deviceUID,
                    stopTrigger: stopTrigger,
                    levelCallback: levelCallback,
                    isPaused: isPaused,
                    earlyTranscription: true
                )
            }
        )
    }

    init(
        dependencies: Dependencies,
        preferredDeviceUID: String? = nil,
        saveDevicePreference: @escaping (String?) throws -> Void = { _ in }
    ) {
        self.dependencies = dependencies
        self.preferredDeviceUID = preferredDeviceUID
        self.effectiveDeviceUID = preferredDeviceUID
        self.saveDevicePreference = saveDevicePreference
    }

    private func applyDevices(_ devices: [AudioDevice], defaultUID: String?) {
        inputDevices = devices
        effectiveDeviceUID = [preferredDeviceUID, defaultUID]
            .compactMap { $0 }
            .first { uid in devices.contains { $0.uid == uid } }
            ?? devices.first?.uid
    }

    func refreshDevices() {
        applyDevices(dependencies.listInputDevices(), defaultUID: dependencies.defaultInputDevice()?.uid)
    }

    func refreshDevicesInBackground() async {
        let dependencies = dependencies
        let result = await Task.detached(priority: .utility) {
            let devices = dependencies.listInputDevices()
            return (devices, dependencies.defaultInputDevice()?.uid)
        }.value
        applyDevices(result.0, defaultUID: result.1)
    }

    func startRecording(
        dataDir: String,
        onComplete: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        guard !isStopping, recordingTask == nil else { return }
        recordingDuration = 0
        audioLevel = 0
        errorMessage = nil

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 0.1
            }
        }

        let (stopTrigger, continuation) = AsyncStream<Void>.makeStream()
        stopContinuation = continuation
        recordingTask = Task {
            await doRecord(
                dataDir: dataDir,
                stopTrigger: stopTrigger,
                onComplete: onComplete,
                onError: onError
            )
        }
    }

    public func stopRecording() {
        isRecordingPaused = false
        tapPaused = false
        stopContinuation?.yield()
        stopContinuation?.finish()
        stopContinuation = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    public func pauseRecording() {
        guard isRecording, !isRecordingPaused else { return }
        isRecordingPaused = true
        tapPaused = true
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    public func resumeRecording() {
        guard isRecording, isRecordingPaused else { return }
        isRecordingPaused = false
        tapPaused = false
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 0.1
            }
        }
    }

    private func doRecord(
        dataDir: String,
        stopTrigger: AsyncStream<Void>,
        onComplete: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        let stem = URL(fileURLWithPath: Recorder.defaultOutputPath()).deletingPathExtension().lastPathComponent
        let dataDirURL = URL(fileURLWithPath: dataDir)
        let audioURL = dataDirURL
            .appendingPathComponent(Pipeline.Directory.audio.path)
            .appendingPathComponent("\(stem).m4a")

        do {
            try FileManager.default.createDirectory(
                at: audioURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let box = audioLevelBox
            let flag = pauseFlag
            try await dependencies.record(
                audioURL,
                selectedDeviceUID,
                stopTrigger,
                { @Sendable level in
                    box.value = level
                },
                { @Sendable in flag.value }
            )

            guard !Task.isCancelled else {
                stopRecording()
                audioLevel = 0
                recordingTask = nil
                return
            }

            stopRecording()
            audioLevel = 0
            recordingTask = nil
            onComplete(stem)

        } catch {
            stopRecording()
            audioLevel = 0
            recordingTask = nil
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            onError(error)
        }
    }

    /// Close the active audio file without scheduling processing, before app exit.
    public func stopForTermination() async {
        isStopping = true
        let task = recordingTask
        stopRecording()
        task?.cancel()
        await task?.value
    }

    /// Cancel any ongoing recording without invoking completion handlers.
    public func cancelRecording() {
        stopRecording()
        recordingTask?.cancel()
        recordingTask = nil
    }
}

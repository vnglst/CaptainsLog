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
        var outputFilename: @Sendable () -> String = { Recorder.defaultOutputPath() }
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
    var lifecycle = AppLifecycle()
    public var errorMessage: String? {
        get { lifecycle.recordingError }
        set { lifecycle.send(.recordingError(newValue)) }
    }
    public var isRecordingPaused: Bool {
        get { lifecycle.isRecordingPaused }
        set { lifecycle.send(newValue ? .recordingPaused : .recordingResumed) }
    }

    func useLifecycle(_ shared: AppLifecycle) {
        let state = lifecycle.recording
        let error = lifecycle.recordingError
        lifecycle = shared
        if state.isActive {
            lifecycle.send(.recordingStarted)
            if state == .paused { lifecycle.send(.recordingPaused) }
            if state == .finishing { lifecycle.send(.recordingFinishing) }
        }
        if let error { lifecycle.send(.recordingFailed(error)) }
    }
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
    private let dependencies: Dependencies

    public var isRecording: Bool { lifecycle.isRecording }

    #if DEBUG
    func applyDesignFixture(isPaused: Bool, duration: TimeInterval, audioLevel: Float) {
        lifecycle.send(.recordingStarted)
        if isPaused { lifecycle.send(.recordingPaused) }
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
        guard recordingTask == nil, lifecycle.canStartRecording else { return }
        recordingDuration = 0
        audioLevel = 0
        lifecycle.send(.recordingStarted)

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
        lifecycle.send(.recordingFinishing)
        tapPaused = false
        stopContinuation?.yield()
        stopContinuation?.finish()
        stopContinuation = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    public func pauseRecording() {
        guard lifecycle.recording == .recording else { return }
        lifecycle.send(.recordingPaused)
        tapPaused = true
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    public func resumeRecording() {
        guard lifecycle.recording == .paused else { return }
        lifecycle.send(.recordingResumed)
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
        let baseStem = URL(fileURLWithPath: dependencies.outputFilename()).deletingPathExtension().lastPathComponent
        let audioDirectory = URL(fileURLWithPath: dataDir)
            .appendingPathComponent(Pipeline.Directory.audio.path)

        do {
            try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
            // Every audio extension shares the same processing stem. Reserve imported
            // recordings too, so a new capture cannot reuse an existing log's identity.
            let existingStems = Set(try FileManager.default.contentsOfDirectory(atPath: audioDirectory.path)
                .map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent })
            var stem = baseStem
            var suffix = 2
            while existingStems.contains(stem) {
                stem = "\(baseStem)-\(suffix)"
                suffix += 1
            }
            let audioURL = audioDirectory.appendingPathComponent("\(stem).m4a")
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
                lifecycle.send(.recordingStopped)
                return
            }

            stopRecording()
            audioLevel = 0
            recordingTask = nil
            lifecycle.send(.recordingStopped)
            onComplete(stem)

        } catch {
            stopRecording()
            audioLevel = 0
            recordingTask = nil
            lifecycle.send(.recordingStopped)
            guard !Task.isCancelled else { return }
            lifecycle.send(.recordingFailed(error.localizedDescription))
            onError(error)
        }
    }

    /// Close the active audio file without scheduling processing, before app exit.
    public func stopForTermination() async {
        lifecycle.send(.terminating)
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
        lifecycle.send(.recordingStopped)
    }
}

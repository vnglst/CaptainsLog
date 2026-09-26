import AVFoundation
import Foundation

public struct AudioDevice: Identifiable, Hashable, Sendable {
    public let id: AudioDeviceID
    public let name: String
    public let uid: String

    public init(id: AudioDeviceID, name: String, uid: String) {
        self.id = id
        self.name = name
        self.uid = uid
    }
}

private final class AVRecorderAudioEngine: RecorderAudioEngine, @unchecked Sendable {
    private let engine: AVAudioEngine

    init(engine: AVAudioEngine) {
        self.engine = engine
    }

    var inputFormat: RecorderAudioFormat {
        let format = engine.inputNode.outputFormat(forBus: 0)
        return RecorderAudioFormat(sampleRate: format.sampleRate, channelCount: format.channelCount)
    }

    func installTap(
        bufferSize: UInt32,
        handler: @escaping @Sendable (RecorderAudioBuffer) -> Void
    ) throws {
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, _ in
            let frames = Int(buffer.frameLength)
            var rms: Float?
            if let data = buffer.floatChannelData?[0], frames > 0 {
                rms = AudioLevel.rootMeanSquare(
                    of: UnsafeBufferPointer(start: data, count: frames)
                )
            }
            handler(RecorderAudioBuffer(
                frameLength: frames,
                rootMeanSquare: rms,
                nativeBuffer: buffer
            ))
        }
    }

    func start() throws { try engine.start() }
    func stop() { engine.stop() }
    func removeTap() { engine.inputNode.removeTap(onBus: 0) }
}

private final class AVRecorderAudioWriter: RecorderAudioWriter, @unchecked Sendable {
    private let file: AVAudioFile

    init(file: AVAudioFile) { self.file = file }

    func write(from buffer: RecorderAudioBuffer) throws {
        guard let nativeBuffer = buffer.nativeBuffer else {
            throw Recorder.RecorderError.missingNativeAudioBuffer
        }
        try file.write(from: nativeBuffer)
    }
}

extension RecorderOperations {
    static let live = RecorderOperations(
        listInputDevices: { Recorder.listInputDevices() },
        makeEngine: { selectedDevice in
            let engine = AVAudioEngine()
            if let selectedDevice, let audioUnit = engine.inputNode.audioUnit {
                var deviceID = selectedDevice.id
                let status = AudioUnitSetProperty(
                    audioUnit,
                    kAudioOutputUnitProperty_CurrentDevice,
                    kAudioUnitScope_Global,
                    0,
                    &deviceID,
                    UInt32(MemoryLayout<AudioDeviceID>.size)
                )
                if status != noErr {
                    Logger.recorder.warning("Could not set input device (status \(status)), using default")
                }
            } else if selectedDevice != nil {
                Logger.recorder.warning("Audio unit unavailable, using default input device")
            }
            return AVRecorderAudioEngine(engine: engine)
        },
        makeWriter: { url, format in
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            return AVRecorderAudioWriter(file: try AVAudioFile(forWriting: url, settings: settings))
        },
        waitForManualStop: { duration in
            let stopSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
            signal(SIGINT, SIG_IGN)

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                var resumed = false

                stopSource.setEventHandler {
                    guard !resumed else { return }
                    resumed = true
                    print("\nStopping recording...")
                    continuation.resume()
                }
                stopSource.resume()

                if let duration {
                    Task {
                        try? await Task.sleep(for: .seconds(duration))
                        guard !resumed else { return }
                        resumed = true
                        continuation.resume()
                    }
                }
            }

            stopSource.cancel()
            signal(SIGINT, SIG_DFL)
        }
    )
}

public enum Recorder {

    public static func listInputDevices() -> [AudioDevice] {
        var propSize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propSize)
        let count = Int(propSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propSize, &deviceIDs)

        var results: [AudioDevice] = []
        for deviceID in deviceIDs {
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var bufSize: UInt32 = 0
            AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, nil, &bufSize)
            let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufferList.deallocate() }
            AudioObjectGetPropertyData(deviceID, &inputAddress, 0, nil, &bufSize, bufferList)
            let channelCount = (0..<Int(bufferList.pointee.mNumberBuffers)).reduce(0) { total, i in
                total + Int(
                    UnsafeMutableAudioBufferListPointer(bufferList)[i].mNumberChannels)
            }
            guard channelCount > 0 else { continue }

            let name = getDeviceString(deviceID, selector: kAudioDevicePropertyDeviceNameCFString)
            let uid = getDeviceString(deviceID, selector: kAudioDevicePropertyDeviceUID)
            guard let name, let uid else { continue }

            results.append(AudioDevice(id: deviceID, name: name, uid: uid))
        }
        return results
    }

    public static func defaultInputDevice() -> AudioDevice? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        guard status == noErr else { return nil }
        return listInputDevices().first { $0.id == deviceID }
    }

    public static func record(
        to url: URL,
        duration: TimeInterval? = nil,
        deviceUID: String? = nil,
        stopTrigger: AsyncStream<Void>? = nil,
        levelCallback: (@Sendable (Float) -> Void)? = nil,
        isPaused: @Sendable @escaping () -> Bool = { false }
    ) async throws {
        try await record(
            to: url,
            duration: duration,
            deviceUID: deviceUID,
            stopTrigger: stopTrigger,
            levelCallback: levelCallback,
            isPaused: isPaused,
            operations: .live
        )
    }

    private static func getDeviceString(
        _ deviceID: AudioDeviceID, selector: AudioObjectPropertySelector
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        guard status == noErr, let cf = value?.takeRetainedValue() else { return nil }
        return cf as String
    }

    public static func defaultOutputPath() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "\(formatter.string(from: Date())).m4a"
    }

    public enum RecorderError: LocalizedError {
        case engineStartFailed(Error)
        case missingNativeAudioBuffer

        public var errorDescription: String? {
            switch self {
            case .engineStartFailed(let underlying):
                return "Failed to start audio engine: \(underlying.localizedDescription)"
            case .missingNativeAudioBuffer:
                return "Audio buffer is unavailable to the native file writer."
            }
        }
    }
}

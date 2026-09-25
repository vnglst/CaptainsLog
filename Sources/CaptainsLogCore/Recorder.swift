import AVFoundation
import Foundation

public struct AudioDevice: Identifiable, Hashable, Sendable {
    public let id: AudioDeviceID
    public let name: String
    public let uid: String
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
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let engine = AVAudioEngine()

        if let uid = deviceUID {
            let devices = listInputDevices()
            if let device = devices.first(where: { $0.uid == uid }) {
                var deviceID = device.id
                if let audioUnit = engine.inputNode.audioUnit {
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
                } else {
                    Logger.recorder.warning("Audio unit unavailable, using default input device")
                }
            }
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: inputFormat.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let outputFile = try AVAudioFile(forWriting: url, settings: outputSettings)

        // Capture write errors from the audio tap closure (runs on audio thread).
        // Read only after engine.stop() + removeTap(), when the closure is guaranteed done.
        class ErrorBox { var value: Error? }
        let tapError = ErrorBox()

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            guard !isPaused() else { return }
            do { try outputFile.write(from: buffer) }
            catch { tapError.value = error }

            if let callback = levelCallback {
                let channelData = buffer.floatChannelData?[0]
                let frames = Int(buffer.frameLength)
                if let data = channelData, frames > 0 {
                    var sum: Float = 0
                    for i in 0..<frames { sum += data[i] * data[i] }
                    let rms = sqrt(sum / Float(frames))
                    callback(rms)
                }
            }
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw RecorderError.engineStartFailed(error)
        }

        if stopTrigger == nil {
            if let duration {
                print("Recording for \(Int(duration))s... (Ctrl+C to stop early)")
            } else {
                print("Recording... (Ctrl+C to stop)")
            }
        }

        if let stopTrigger {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                Task {
                    for await _ in stopTrigger {
                        continuation.resume()
                        return
                    }
                    continuation.resume()
                }
            }
        } else {
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

        engine.stop()
        inputNode.removeTap(onBus: 0)

        if let err = tapError.value { throw err }

        if stopTrigger == nil {
            print("Saved to \(url.path)")
        }
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

        public var errorDescription: String? {
            switch self {
            case .engineStartFailed(let underlying):
                return "Failed to start audio engine: \(underlying.localizedDescription)"
            }
        }
    }
}

import AVFoundation
import Foundation

struct RecorderAudioFormat: Sendable {
    let sampleRate: Double
    let channelCount: UInt32
}

final class RecorderAudioBuffer: @unchecked Sendable {
    let frameLength: Int
    let rootMeanSquare: Float?
    let nativeBuffer: AVAudioPCMBuffer?

    init(frameLength: Int, rootMeanSquare: Float?, nativeBuffer: AVAudioPCMBuffer? = nil) {
        self.frameLength = frameLength
        self.rootMeanSquare = rootMeanSquare
        self.nativeBuffer = nativeBuffer
    }
}

protocol RecorderAudioEngine: AnyObject, Sendable {
    var inputFormat: RecorderAudioFormat { get }
    func installTap(
        bufferSize: UInt32,
        handler: @escaping @Sendable (RecorderAudioBuffer) -> Void
    ) throws
    func start() throws
    func stop()
    func removeTap()
}

protocol RecorderAudioWriter: AnyObject, Sendable {
    func write(from buffer: RecorderAudioBuffer) throws
}

struct RecorderOperations: Sendable {
    var listInputDevices: @Sendable () -> [AudioDevice]
    var makeEngine: @Sendable (AudioDevice?) throws -> any RecorderAudioEngine
    var makeWriter: @Sendable (URL, RecorderAudioFormat) throws -> any RecorderAudioWriter
    var waitForManualStop: @Sendable (TimeInterval?) async -> Void
}

private final class RecorderErrorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedError: Error?

    var value: Error? {
        get { lock.withLock { storedError } }
        set { lock.withLock { storedError = newValue } }
    }
}

extension Recorder {
    static func record(
        to url: URL,
        duration: TimeInterval?,
        deviceUID: String?,
        stopTrigger: AsyncStream<Void>?,
        levelCallback: (@Sendable (Float) -> Void)?,
        isPaused: @Sendable @escaping () -> Bool,
        operations: RecorderOperations
    ) async throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let selectedDevice = deviceUID.flatMap { uid in
            operations.listInputDevices().first { $0.uid == uid }
        }
        let engine = try operations.makeEngine(selectedDevice)
        let writer = try operations.makeWriter(url, engine.inputFormat)

        // The audio callback is finished after stopping the engine and removing the tap.
        let tapError = RecorderErrorBox()
        do {
            try engine.installTap(bufferSize: 4096) { buffer in
                guard !isPaused() else { return }
                do { try writer.write(from: buffer) }
                catch { tapError.value = error }

                if let levelCallback, let rms = buffer.rootMeanSquare {
                    levelCallback(rms)
                }
            }
        } catch {
            engine.stop()
            engine.removeTap()
            throw error
        }

        do {
            try engine.start()
        } catch {
            engine.stop()
            engine.removeTap()
            throw Recorder.RecorderError.engineStartFailed(error)
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
            await operations.waitForManualStop(duration)
        }

        engine.stop()
        engine.removeTap()

        if let error = tapError.value { throw error }
        if stopTrigger == nil { print("Saved to \(url.path)") }
    }
}

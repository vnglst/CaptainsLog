#if DEBUG
import AVFoundation
import Foundation

/// Replays fixture buffers through the real recorder tap without an input device.
final class FixtureRecordingEngine: RecorderAudioEngine, @unchecked Sendable {
    private let queue = DispatchQueue(label: "CaptainsLog.fixture-recording")
    private let file: AVAudioFile
    private var timer: DispatchSourceTimer?
    private var handler: (@Sendable (RecorderAudioBuffer) -> Void)?

    static func configured() throws -> FixtureRecordingEngine? {
        let env = ProcessInfo.processInfo.environment
        guard env["CAPTAINS_LOG_CONFIG_PATH"] != nil,
              let path = env["CAPTAINSLOG_RECORDING_FIXTURE_PATH"] else { return nil }
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let repository = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fixtureRoot = repository.appendingPathComponent("eval/transcribe/audio").resolvingSymlinksInPath()
        guard FileManager.default.fileExists(atPath: repository.appendingPathComponent("Package.swift").path),
              url.path.hasPrefix(fixtureRoot.path + "/") else { throw CocoaError(.fileReadNoPermission) }
        return try FixtureRecordingEngine(url: url)
    }
    init(url: URL) throws { file = try AVAudioFile(forReading: url) }
    var inputFormat: RecorderAudioFormat {
        RecorderAudioFormat(sampleRate: file.processingFormat.sampleRate, channelCount: file.processingFormat.channelCount)
    }
    func installTap(bufferSize: UInt32, handler: @escaping @Sendable (RecorderAudioBuffer) -> Void) throws {
        queue.sync { self.handler = handler }
    }
    func start() throws {
        queue.sync {
            let source = DispatchSource.makeTimerSource(queue: queue)
            source.schedule(deadline: .now(), repeating: Double(4096) / file.processingFormat.sampleRate)
            source.setEventHandler { [weak self] in
                guard let self, let pcm = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096) else { return }
                do {
                    try file.read(into: pcm)
                    guard pcm.frameLength > 0 else { self.timer?.cancel(); return }
                    var rms: Float?
                    if let samples = pcm.floatChannelData?[0] {
                        rms = AudioLevel.rootMeanSquare(of: UnsafeBufferPointer(start: samples, count: Int(pcm.frameLength)))
                    }
                    handler?(RecorderAudioBuffer(frameLength: Int(pcm.frameLength), rootMeanSquare: rms, nativeBuffer: pcm))
                } catch { self.timer?.cancel() }
            }
            timer = source
            source.resume()
        }
    }
    func stop() {
        queue.sync {
            timer?.cancel()
            timer?.setEventHandler {}
            timer = nil
        }
    }
    func removeTap() { queue.sync { handler = nil } }
}
#endif

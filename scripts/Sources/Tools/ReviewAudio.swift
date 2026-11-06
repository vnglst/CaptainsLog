import AVFoundation
import Foundation

struct ReviewSplice: Sendable {
    let passageID: String
    let takeID: String
    let start: Double
    let end: Double
    let file: URL
}
struct ReviewAudioResult: Sendable {
    let audio: URL
    let map: URL
}
private final class ReviewAudioJob: @unchecked Sendable {
    let done = DispatchSemaphore(value: 0)
    var result: Result<ReviewAudioResult, Error>?
}
extension Tools {
    /// Called on a review HTTP worker, never on the native app's main thread.
    func consolidateReviewAudio(source: URL, splices: [ReviewSplice], destination: URL) throws -> ReviewAudioResult {
        let job = ReviewAudioJob()
        Task.detached { @Sendable [job, source, splices, destination] in
            do { job.result = .success(try await Tools.exportReviewAudio(source: source, splices: splices, destination: destination)) }
            catch { job.result = .failure(error) }
            job.done.signal()
        }
        job.done.wait()
        return try job.result!.get()
    }
    private static func exportReviewAudio(source: URL, splices: [ReviewSplice], destination: URL) async throws -> ReviewAudioResult {
        let sourceAsset = AVURLAsset(url: source)
        guard let sourceTrack = try await sourceAsset.loadTracks(withMediaType: .audio).first else { throw ToolFailure("The source recording has no audio track") }
        let sourceDuration = try await sourceAsset.load(.duration).seconds
        let ordered = splices.sorted { $0.start < $1.start }
        guard !ordered.isEmpty else { throw ToolFailure("Select at least one replacement take") }
        var previous = 0.0
        for splice in ordered {
            guard splice.start.isFinite, splice.end.isFinite, splice.start >= previous, splice.start >= 0, splice.end > splice.start, splice.end <= sourceDuration + 0.1 else { throw ToolFailure("Replacement ranges overlap or fall outside the recording. Adjust their start/end times before combining.") }
            previous = splice.end
        }
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw ToolFailure("Could not create the corrected audio track") }
        var cursor = CMTime.zero, original = 0.0, edits: [[String: Any]] = []
        func insertOriginal(_ end: Double) throws {
            if end <= original { return }
            let duration = CMTime(seconds: end - original, preferredTimescale: 48_000)
            try track.insertTimeRange(CMTimeRange(start: CMTime(seconds: original, preferredTimescale: 48_000), duration: duration), of: sourceTrack, at: cursor)
            edits.append(["kind": "original", "original_start": original, "original_end": end, "corrected_start": cursor.seconds, "corrected_end": (cursor + duration).seconds])
            cursor = cursor + duration
        }
        let tools = Tools()
        for splice in ordered {
            try insertOriginal(splice.start)
            let asset = AVURLAsset(url: splice.file)
            guard let replacement = try await asset.loadTracks(withMediaType: .audio).first else { throw ToolFailure("A replacement has no audio track") }
            let duration = try await asset.load(.duration)
            guard duration.seconds.isFinite && duration.seconds > 0 else { throw ToolFailure("A replacement is empty") }
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: replacement, at: cursor)
            edits.append(["kind": "replacement", "passage_id": splice.passageID, "take_id": splice.takeID, "replacement_sha256": try tools.hash(splice.file), "original_start": splice.start, "original_end": splice.end, "corrected_start": cursor.seconds, "corrected_end": (cursor + duration).seconds])
            cursor = cursor + duration; original = splice.end
        }
        try insertOriginal(sourceDuration)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else { throw ToolFailure("Could not create corrected recording exporter") }
        try await exporter.export(to: destination, as: .m4a)
        let map = destination.deletingPathExtension().appendingPathExtension("json")
        try tools.json(map, ["version": 1, "source_sha256": try tools.hash(source), "corrected_sha256": try tools.hash(destination), "original_duration": sourceDuration, "corrected_duration": cursor.seconds, "edits": edits])
        return ReviewAudioResult(audio: destination, map: map)
    }
}

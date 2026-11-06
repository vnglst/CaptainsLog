import AVFoundation
import Foundation

extension Tools {
    func testReviewAudio() throws {
        let dir = try temporary("captainslog-review-audio-"); defer { try? fm.removeItem(at: dir) }
        let source = dir.appendingPathComponent("assets/audio/original.m4a")
        let fixture = path("eval/audio-formats/review-original.wav"), retake = path("eval/audio-formats/review-retake.wav")
        _ = try consolidateReviewAudio(source: fixture, splices: [ReviewSplice(passageID: "seed", takeID: "seed", start: 0.4, end: 0.6, file: retake)], destination: source)
        let originalHash = try hash(source)
        let context1: EvalItem = ["audio_sha256": originalHash, "reference_sha256": "synthetic-reference", "start_seconds": 0.1, "end_seconds": 0.5]
        let context2: EvalItem = ["audio_sha256": originalHash, "reference_sha256": "synthetic-reference", "start_seconds": 0.4, "end_seconds": 0.8]
        try json(dir.appendingPathComponent("recordings.json"), ["recordings": [["id": "synthetic", "audio": "assets/audio/original.m4a", "audio_sha256": originalHash, "reference_sha256": "synthetic-reference", "passages": [["id": "first", "context": context1], ["id": "second", "context": context2]]]]])
        let server = try EvalReviewServer(root: dir, port: 0); defer { server.stop() }
        let headers = ["host": "127.0.0.1:\(server.port)", "content-type": "application/json"]
        func send(_ route: String, _ value: EvalItem) throws -> ReviewResponse {
            try server.response(method: "POST", path: route, headers: headers, body: JSONSerialization.data(withJSONObject: value))
        }
        func decode(_ response: ReviewResponse) throws -> EvalItem { try JSONSerialization.jsonObject(with: response.body) as! EvalItem }
        let payload: EvalItem = ["id": "first", "context": context1, "audio_base64": try Data(contentsOf: retake).base64EncodedString(), "replace_start_seconds": 0.1, "replace_end_seconds": 0.5]
        var bad = payload; bad["audio_base64"] = Data("not WAV audio".utf8).base64EncodedString()
        try require(send("/api/retakes", bad).status == 400, "Invalid replacement bytes accepted")
        bad = payload; bad["context"] = ["changed": true]
        try require(send("/api/retakes", bad).status == 409, "Stale replacement context accepted")
        let saved = try send("/api/retakes", payload); try require(saved.status == 200, "Replacement save failed: \(String(decoding: saved.body, as: UTF8.self))")
        let entry = try decode(saved), take = (entry["retakes"] as! [EvalItem])[0], takeID = take["id"] as! String
        let firstFile = dir.appendingPathComponent(take["audio"] as! String)
        try require(entry["audio_issue"] as? Bool == true && entry["status"] as? String == "uncertain" && hash(firstFile) == hash(retake), "Replacement did not preserve actual audio and mark the original issue")
        var update: EvalItem = ["id": "first", "context": context1, "status": "uncertain", "words": "", "notes": "synthetic test", "audio_issue": true, "accepted_take_id": takeID]
        try require(send("/api/state", update).status == 200, "Take approval failed")
        update["retake_ranges"] = [takeID: ["start": 0.12, "end": 0.48]]
        try require(send("/api/state", update).status == 200, "Replacement range edit failed")
        update["retake_ranges"] = [takeID: ["start": 0.0, "end": 0.9]]
        try require(send("/api/state", update).status == 400, "Out-of-passage replacement range accepted")
        // Exercise the real HTTP reader beyond the old 100 KB review-state limit.
        var longWav = try Data(contentsOf: retake)
        let samples = Data(longWav.dropFirst(44))
        for _ in 1..<20 { longWav.append(samples) }
        for i in 0..<4 { longWav[4 + i] = UInt8(((longWav.count - 8) >> (i * 8)) & 255); longWav[40 + i] = UInt8(((longWav.count - 44) >> (i * 8)) & 255) }
        var largePayload = payload; largePayload["audio_base64"] = longWav.base64EncodedString()
        let posted = dir.appendingPathComponent("retake-post.json"), reply = dir.appendingPathComponent("retake-reply.json")
        try json(posted, largePayload)
        DispatchQueue.global().async { try? server.serve() }
        try run(["/usr/bin/curl", "--fail", "--silent", "--max-time", "5", "-H", "Content-Type: application/json", "--data-binary", "@" + posted.path, "--output", reply.path, "http://127.0.0.1:\(server.port)/api/retakes"], quiet: true)
        try require(((try json(reply) as? EvalItem)?["retakes"] as? [EvalItem])?.count == 2, "HTTP retake upload larger than 100 KB failed")
        let secondPayload: EvalItem = ["id": "second", "context": context2, "audio_base64": try Data(contentsOf: retake).base64EncodedString(), "replace_start_seconds": 0.4, "replace_end_seconds": 0.8]
        let secondEntry = try decode(send("/api/retakes", secondPayload)), secondTake = (secondEntry["retakes"] as! [EvalItem])[0], secondID = secondTake["id"] as! String
        try require(send("/api/state", ["id": "second", "context": context2, "status": "uncertain", "words": "", "notes": "", "accepted_take_id": secondID]).status == 200, "Second take approval failed")
        let overlap = try send("/api/consolidate", ["recording_id": "synthetic", "selections": ["first": takeID, "second": secondID]])
        try require(overlap.status == 400 && String(decoding: overlap.body, as: UTF8.self).contains("overlap"), "Overlapping replacements were silently combined")
        update["retake_ranges"] = [takeID: ["start": 0.12, "end": 0.4]]
        try require(send("/api/state", update).status == 200, "Overlap boundary adjustment failed")
        let combined = try send("/api/consolidate", ["recording_id": "synthetic", "selections": ["first": takeID, "second": secondID]])
        try require(combined.status == 200, "Native audio consolidation failed: \(String(decoding: combined.body, as: UTF8.self))")
        let result = try decode(combined), audio = dir.appendingPathComponent(result["audio"] as! String), map = try json(dir.appendingPathComponent(result["edit_map"] as! String)) as! EvalItem
        let originalDuration = map["original_duration"] as! Double, duration = map["corrected_duration"] as! Double
        try require(abs(duration - (originalDuration - 0.68 + 0.4)) < 0.001, "Replacement durations did not shift the consolidated timeline correctly")
        let decoded = try AVAudioFile(forReading: audio), actual = Double(decoded.length) / decoded.processingFormat.sampleRate
        try require(abs(actual - duration) < 0.1, "Exported M4A duration disagrees with the edit map")
        let edits = map["edits"] as! [EvalItem]
        try require(edits.filter { $0["kind"] as? String == "replacement" }.count == 2 && edits.contains { $0["kind"] as? String == "original" }, "Edit map omitted original or replacement spans")
        try require(hash(source) == originalHash && hash(firstFile) == hash(retake), "Consolidation mutated original or retake audio")
        let state = try json(dir.appendingPathComponent("review-state.json")) as! EvalItem
        try require((state["consolidations"] as? [EvalItem])?.count == 1, "Corrected recording history was not persisted")
        func reviewIsComplete() throws -> Bool {
            let overview = try decode(server.response(method: "GET", path: "/api/reviews", headers: headers, body: Data()))
            return (overview["reviews"] as? [EvalItem])?.first?["complete"] as? Bool == true
        }
        try require(reviewIsComplete(), "Exported replacements did not resolve the review")
        update["retake_ranges"] = [takeID: ["start": 0.15, "end": 0.4]]
        try require(send("/api/state", update).status == 200 && !reviewIsComplete(), "Editing an exported replacement range must reopen the review")
        print("PASS: synthetic WAV retakes, approvals, editable ranges, overlap rejection, native M4A consolidation, edit-map timing and original preservation")
    }
}

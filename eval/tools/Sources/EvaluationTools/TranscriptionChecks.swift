import ToolSupport
import Foundation

extension Tools {
    func testTranscriptionScoring() throws {
        var checks = 0
        func check(_ reference: String, _ hypothesis: String, _ s: Int, _ d: Int, _ i: Int) throws {
            let score = try TranscriptionScore(reference: reference, hypothesis: hypothesis)
            try require(score.substitutions == s && score.deletions == d && score.insertions == i,
                        "Incorrect WER alignment: \(reference) → \(hypothesis): \(score.summary)")
            checks += 1
        }
        try check("Café, Klingon-schip z’n tweeën", "CAFE\u{301} Klingon schip z'n tweeën!", 0, 0, 0)
        try check("one two three four", "one changed three extra four", 1, 0, 1)
        try check("a b c d e f g", "a g", 0, 5, 0)
        try check("a b", "", 0, 2, 0)
        try check("a", "a b c d", 0, 0, 3)
        try check("één twaalf", "een 12", 2, 0, 0)
        try check("a a b", "a b", 0, 1, 0)
        try check("a b", "b a", 2, 0, 0)
        do { _ = try TranscriptionScore(reference: "...", hypothesis: "a"); throw ToolFailure("empty WER reference accepted") }
        catch { try require(String(describing: error).contains("requires a nonempty"), "Wrong empty-reference error") }
        // Independently compute edit distance over every short binary word sequence.
        let sequences = (1...4).flatMap { length in (0..<(1 << length)).map { bits in (0..<length).map { bits & (1 << $0) == 0 ? "a" : "b" } } }
        func distance(_ a: ArraySlice<String>, _ b: ArraySlice<String>) -> Int {
            if a.isEmpty { return b.count }; if b.isEmpty { return a.count }
            return min(distance(a.dropFirst(), b.dropFirst()) + (a.first == b.first ? 0 : 1),
                       distance(a.dropFirst(), b) + 1, distance(a, b.dropFirst()) + 1)
        }
        for r in sequences {
            for h in sequences + [[]] {
                let score = try TranscriptionScore(reference: r.joined(separator: " "), hypothesis: h.joined(separator: " "))
                try require(score.errors == distance(r[...], h[...]), "WER did not find a minimum alignment")
                try require(score.referenceWords == r.count && score.hypothesisWords == h.count, "WER denominator changed")
                try require(score.edits.count == score.errors, "WER edit report lost errors")
                try require(score.referenceBoundaries.count == r.count + 1 && score.referenceBoundaries.first == 0 && score.referenceBoundaries.last == h.count && score.referenceBoundaries == score.referenceBoundaries.sorted(), "Review boundary map is not complete and monotonic")
                checks += 1
            }
        }
        let dir = try temporary("transcription-score-tests-"); defer { try? fm.removeItem(at: dir) }
        let eval = Evaluator(self)
        var item: EvalItem = ["stage": "transcribe", "name": "fixture", "input": dir.appendingPathComponent("input.m4a").path,
                              "expected": dir.appendingPathComponent("expected.md").path, "output": dir.appendingPathComponent("output.md").path,
                              "reference_status": "script-unverified"]
        try write(eval.file(item, "input"), "synthetic bytes")
        try write(eval.file(item, "expected"), "one two three four")
        try write(eval.file(item, "output"), "one changed three extra four")
        try require(eval.evidence(dir, [item]), "Valid transcript measurement failed")
        let report = dir.appendingPathComponent("review/suites/transcribe/fixture")
        let score = try json(report.appendingPathComponent("wer.json")) as! EvalItem
        try require(score["wer"] as? Double == 0.5 && score["provisional"] as? Bool == true, "Provisional WER evidence missing")
        let aggregate = try json(dir.appendingPathComponent("transcription-scores.json")) as! EvalItem
        try require(aggregate["wer"] as? Double == 0.5 && aggregate["reference_words"] as? Int == 4, "Aggregate WER incorrect")
        item["reference_status"] = "audio-reviewed"
        try require(eval.evidence(dir, [item]), "Reviewed transcript measurement failed")
        try require((try json(report.appendingPathComponent("wer.json")) as! EvalItem)["provisional"] as? Bool == false, "Reviewed reference marked provisional")
        try write(eval.file(item, "expected"), "...")
        try require(!eval.evidence(dir, [item]), "Empty normalized reference accepted")
        try require(!fm.fileExists(atPath: report.appendingPathComponent("wer.json").path), "Stale score survived failed revalidation")
        let fixtureRoot = dir.appendingPathComponent("fixture-root"), fixtureTools = Tools(root: fixtureRoot)
        let fixtureAudio = fixtureRoot.appendingPathComponent("eval/suites/transcribe/audio/check.m4a"), fixtureReference = fixtureRoot.appendingPathComponent("eval/suites/transcribe/expected/check.md")
        try write(fixtureAudio, "synthetic fixture bytes"); try write(fixtureReference, "a reference")
        let manifest = fixtureRoot.appendingPathComponent("eval/suites/transcribe/cases.json")
        let entry: EvalItem = ["language": "Dutch", "reference_status": "model-assisted", "audio_sha256": try hash(fixtureAudio), "reference_sha256": try hash(fixtureReference)]
        try json(manifest, ["check": entry])
        try require(Evaluator(fixtureTools).transcriptionCases().count == 1, "Pinned transcription case rejected")
        func rejectManifest(_ entries: [String: EvalItem], _ message: String) throws {
            try json(manifest, entries)
            do { _ = try Evaluator(fixtureTools).transcriptionCases(); throw ToolFailure("Invalid transcription manifest accepted") }
            catch { try require(String(describing: error).contains(message), "Unexpected manifest error: \(error)") }
        }
        try rejectManifest([:], "must cover every audio fixture")
        var wrong = entry; wrong["reference_status"] = "verified-by-model"
        try rejectManifest(["check": wrong], "Invalid reference status")
        wrong = entry; wrong["reference_sha256"] = "wrong"
        try rejectManifest(["check": wrong], "fixture hash mismatch")
        wrong = entry; wrong["audio_sha256"] = "wrong"
        try rejectManifest(["check": wrong], "fixture hash mismatch")
        print("PASS: \(checks) WER alignments, reference status, aggregate evidence and invalid-reference checks")
    }
}

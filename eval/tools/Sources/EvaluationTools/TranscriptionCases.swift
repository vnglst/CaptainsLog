import ToolSupport
import Foundation

extension Evaluator {
    /// Require explicit provenance for every active recording and pin both sides
    /// of the comparison. A script is not automatically a verbatim transcript.
    func transcriptionCases(includingArchived: Bool = false) throws -> [String: EvalItem] {
        let manifest = tools.path("eval/transcribe/cases.json")
        guard let entries = try tools.json(manifest) as? [String: EvalItem] else { throw ToolFailure("Invalid transcription cases manifest") }
        let names = Set(tools.files(tools.path("eval/transcribe/audio")).filter { $0.pathExtension == "m4a" }.map { $0.deletingPathExtension().lastPathComponent })
        try tools.require(Set(entries.keys) == names, "Transcription manifest must cover every audio fixture exactly")
        for (name, entry) in entries {
            try tools.require(["script-unverified", "reference-unverified", "model-assisted", "audio-reviewed"].contains(entry["reference_status"] as? String ?? ""), "Invalid reference status: \(name)")
            try tools.require(!(entry["language"] as? String ?? "").isEmpty, "Missing language: \(name)")
            for (key, relative) in [("audio_sha256", "audio/\(name).m4a"), ("reference_sha256", "expected/\(name).md")] {
                try tools.require(entry[key] as? String == tools.hash(tools.path("eval/transcribe/" + relative)), "Transcription fixture hash mismatch: \(relative)")
            }
        }
        if includingArchived {
            let archive = tools.path("eval/transcribe/history")
            if let historical = (try? tools.json(archive.appendingPathComponent("cases.json"))) as? [String: EvalItem] {
                for (name, entry) in historical where entries[name] == nil {
                    try tools.require(entry["audio_sha256"] as? String == tools.hash(archive.appendingPathComponent("audio/\(name).m4a")), "Archived recording hash mismatch: \(name)")
                    try tools.require(entry["reference_sha256"] as? String == tools.hash(archive.appendingPathComponent("expected/\(name).md")), "Archived reference hash mismatch: \(name)")
                }
                return entries.merging(historical) { active, _ in active }
            }
        }
        return entries
    }
    func transcriptionEvidence(_ item: EvalItem, _ folder: URL) throws -> (TranscriptionScore, EvalItem) {
        let score = try TranscriptionScore(reference: tools.read(file(item, "expected")), hypothesis: tools.read(file(item, "output")))
        var measurement = score.json
        let status = string(item, "reference_status", "reference-unverified")
        measurement["reference_status"] = status
        measurement["provisional"] = status != "audio-reviewed"
        measurement["reference_sha256"] = try tools.hash(file(item, "expected"))
        measurement["hypothesis_sha256"] = try tools.hash(file(item, "output"))
        measurement["audio_sha256"] = try tools.hash(file(item, "input"))
        try tools.json(folder.appendingPathComponent("wer.json"), measurement)
        try tools.write(folder.appendingPathComponent("wer.md"), score.markdown)
        return (score, measurement)
    }
}

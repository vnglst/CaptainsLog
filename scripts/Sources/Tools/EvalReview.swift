import AVFoundation
import Foundation

struct ReviewText {
    let text: String
    let ranges: [NSRange]
    init(_ value: String) {
        text = value.precomposedStringWithCanonicalMapping
        let regex = try! NSRegularExpression(pattern: "[\\p{L}\\p{M}\\p{N}]+(?:['’‘][\\p{L}\\p{M}\\p{N}]+)*")
        ranges = regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)).map(\.range)
    }
    func excerpt(_ start: Int, _ end: Int) -> String {
        guard start >= 0, start < end, end <= ranges.count else { return "" }
        return (text as NSString).substring(with: NSRange(location: ranges[start].location, length: NSMaxRange(ranges[end - 1]) - ranges[start].location))
    }

}

extension Tools {
    /// Materialize an isolated review app from the selected saved run, never from
    /// a machine-specific glob of unrelated generated files or personal audio.
    @discardableResult
    func prepareEvalReview(_ run: URL, items supplied: [EvalItem]? = nil, comparison requestedComparison: URL? = nil, differencesOnly: Bool = false) throws -> URL? {
        let evaluator = Evaluator(self)
        let items = try supplied ?? (json(run.appendingPathComponent("manifest.json")) as? [EvalItem] ?? [])
        let audioCases = items.filter { evaluator.string($0, "stage") == "transcribe" }
        guard !audioCases.isEmpty else { return nil }
        let catalog = try evaluator.transcriptionCases(includingArchived: true)
        let app = run.appendingPathComponent("review-app"), assets = app.appendingPathComponent("assets/audio")
        try mkdir(assets)
        let previousFile = app.appendingPathComponent("recordings.json")
        let previousData = fm.fileExists(atPath: previousFile.path) ? try json(previousFile) as? EvalItem : nil
        let timestampedComparison = requestedComparison.map { folder in
            audioCases.allSatisfy { item in
                let name = evaluator.string(item, "name")
                return fm.fileExists(atPath: folder.appendingPathComponent(name + ".json").path)
                    && fm.fileExists(atPath: folder.appendingPathComponent(name + ".run.json").path)
            }
        } ?? false
        let generateDifferences = differencesOnly || timestampedComparison || previousData?["selection"] as? String == "aligned-differences"
        let comparison = requestedComparison ?? (generateDifferences ? (previousData?["comparison_source"] as? String).map(path) : nil)
        let previousRecordings = previousData?["recordings"] as? [EvalItem] ?? []
        guard let source = Bundle.module.url(forResource: "EvalReview", withExtension: nil) else { throw ToolFailure("Missing evaluation review app resources") }
        for name in ["index.html", "style.css", "app.js", "audio-capture.mjs", "review-passages.mjs"] { try copy(source.appendingPathComponent(name), app.appendingPathComponent(name)) }
        func requireRunFile(_ url: URL) throws {
            let resolved = url.resolvingSymlinksInPath().standardizedFileURL.path
            let roots = [path("eval"), path("tmp"), run] + (comparison.map { [$0] } ?? [])
            try require(roots.contains { resolved.hasPrefix($0.resolvingSymlinksInPath().standardizedFileURL.path + "/") }, "Review files must belong to an evaluation run: \(url.path)")
        }
        func admittedText(_ url: URL) throws -> String { try requireRunFile(url); return try read(url) }
        var recordings: [EvalItem] = []
        for (index, item) in audioCases.enumerated() {
            let name = evaluator.string(item, "name")
            let scope = evaluator.string(item, "scope", "suites")
            try require(["pipeline", "suites"].contains(scope), "Unknown review scope: \(scope)")
            let snapshot = run.appendingPathComponent("review/\(scope)/transcribe/\(name)")
            func savedFile(_ key: String, _ fallback: String) -> URL {
                let original = evaluator.file(item, key)
                return fm.fileExists(atPath: original.path) ? original : snapshot.appendingPathComponent(fallback)
            }
            let input = savedFile("input", "input.m4a")
            guard let fixture = catalog[name] else { throw ToolFailure("Unknown synthetic review recording: \(name)") }
            try requireRunFile(input)
            let audioHash = try hash(input)
            try require(audioHash == fixture["audio_sha256"] as? String, "Review audio does not match the synthetic fixture: \(name)")
            let audioFile = try AVAudioFile(forReading: input)
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            try require(duration.isFinite && duration > 0, "Empty review recording: \(name)")
            let referenceURL = savedFile("expected", "expected.md"), reference = try admittedText(referenceURL), referenceHash = try hash(referenceURL)
            let output = savedFile("output", "output.md")
            let transcript = fm.fileExists(atPath: output.path) ? try admittedText(output) : nil
            let liveDefinition = path("eval/transcribe/review/\(name).json")
            let definitionURL = fm.fileExists(atPath: liveDefinition.path) ? liveDefinition : path("eval/transcribe/history/review/\(name).json")
            let definition = fm.fileExists(atPath: definitionURL.path) ? try json(definitionURL) as? EvalItem : nil
            let duplicate = audioCases.filter { evaluator.string($0, "name") == name }.count > 1
            let baseID = evaluator.string(definition ?? [:], "id", "recording-\(index)")
            let identifier = baseID + (duplicate ? "-\(scope)" : "")
            let title = evaluator.string(definition ?? [:], "title", name) + (duplicate ? " (\(scope))" : "")
            let audioPath = "assets/audio/\(index).\(input.pathExtension.lowercased())"
            let destination = app.appendingPathComponent(audioPath)
            if try !fm.fileExists(atPath: destination.path) || hash(destination) != audioHash { try copy(input, destination) }
            let previous = previousRecordings.first { evaluator.string($0, "id") == identifier && evaluator.string($0, "audio_sha256") == audioHash }
            var second = previous?["second_transcript"] as? String
            var comparisonLabel = evaluator.string(previous ?? [:], "comparison_label", "No comparison selected")
            if let comparison {
                try require(fm.fileExists(atPath: comparison.path), "Missing comparison run: \(comparison.path)", status: 2)
                second = nil
                let manifest = comparison.appendingPathComponent("manifest.json")
                if fm.fileExists(atPath: manifest.path), let previous = try json(manifest) as? [EvalItem],
                   let selected = previous.first(where: { evaluator.string($0, "stage") == "transcribe" && evaluator.string($0, "name") == name && evaluator.string($0, "scope", "suites") == scope }) {
                    let url = evaluator.file(selected, "output")
                    if fm.fileExists(atPath: url.path) { second = try admittedText(url); comparisonLabel = "Comparison run: " + comparison.lastPathComponent }
                } else {
                    let url = comparison.appendingPathComponent(name + ".txt")
                    if fm.fileExists(atPath: url.path) { second = try admittedText(url); comparisonLabel = "Imported transcript: " + comparison.lastPathComponent }
                }
            }
            let ref = ReviewText(reference), generated = transcript.map(ReviewText.init), compared = second.map(ReviewText.init)
            let generatedBoundaries = try transcript.map { try TranscriptionScore(reference: reference, hypothesis: $0).referenceBoundaries }
            let comparedBoundaries = try second.map { try TranscriptionScore(reference: reference, hypothesis: $0).referenceBoundaries }
            var definitions: [EvalItem] = []
            if let definition, definition["audio_sha256"] as? String == audioHash, definition["reference_sha256"] as? String == referenceHash {
                definitions = definition["passages"] as? [EvalItem] ?? []
            } else if definition != nil { print("Review passage reference changed for \(name); using the full recording until timings are updated.") }
            if generateDifferences {
                guard let transcript, let second, let comparison else { throw ToolFailure("Difference selection requires both model transcripts and timestamped comparison evidence") }
                let identityURL = comparison.appendingPathComponent(name + ".run.json")
                let timingURL = comparison.appendingPathComponent(name + ".json")
                let identity = try json(identityURL) as? EvalItem ?? [:]
                try require(identity["audio_sha256"] as? String == audioHash, "Comparison used different audio: " + name)
                if let timingHash = identity["timing_sha256"] as? String {
                    try require(timingHash == hash(timingURL), "Comparison timing hash mismatch: " + name)
                }
                let comparisonText = comparison.appendingPathComponent(name + ".txt")
                try require(identity["output_sha256"] as? String == hash(comparisonText), "Comparison transcript hash mismatch: " + name)
                try require(read(comparisonText) == second, "Comparison timing source does not match the selected output")
                definitions = try differencePassages(reference: reference, transcript: transcript, comparison: second,
                    timing: json(timingURL) as? EvalItem ?? [:], identifier: identifier, duration: duration)
                comparisonLabel = "Whisper Large-v3 · timestamped comparison"
            }
            if definitions.isEmpty && !generateDifferences { definitions = [["id": identifier + "-full", "short_id": "Full", "title": "Full recording", "start_seconds": 0.0, "end_seconds": duration, "reference_start_word": 0, "reference_end_word": ref.ranges.count, "check": "Listen to the recording and verify the reference against the spoken words."]] }
            var passages: [EvalItem] = []
            for (offset, p) in definitions.enumerated() {
                guard let start = p["start_seconds"] as? Double, let end = p["end_seconds"] as? Double,
                      let a = p["reference_start_word"] as? Int, let b = p["reference_end_word"] as? Int else { throw ToolFailure("Invalid listening passage: \(name)") }
                try require(start >= 0 && start < end && end <= duration + 0.25 && a >= 0 && (a < b || ref.ranges.isEmpty) && b <= ref.ranges.count, "Invalid listening bounds: \(name)/\(offset)")
                let id = evaluator.string(p, "id", identifier + "-\(offset)") + (duplicate ? "-\(scope)" : "")
                let context: EvalItem = ["audio_sha256": audioHash, "reference_sha256": referenceHash, "start_seconds": start, "end_seconds": end, "reference_start_word": a, "reference_end_word": b]
                passages.append(["id": id, "short_id": evaluator.string(p, "short_id", "\(offset + 1)"), "title": evaluator.string(p, "title", "Passage \(offset + 1)"), "start_seconds": start, "end_seconds": min(end, duration), "clip_start": start, "clip_end": min(end, duration), "audio": audioPath, "reference": ref.excerpt(a, b), "app_transcript": generatedBoundaries.map { generated!.excerpt($0[a], $0[b]) } as Any? ?? NSNull(), "second_transcript": comparedBoundaries.map { compared!.excerpt($0[a], $0[b]) } as Any? ?? NSNull(), "context": context, "model_errors": p["model_errors"] ?? NSNull(), "check": evaluator.string(p, "check", "Listen for the exact words and any restarts. Text alignment is approximate; use the full transcript for context.")])
            }
            var carried: [String] = []
            let provenanceURL = path("eval/transcribe/review/\(name).provenance.json")
            if let sourceName = fixture["reference_check"] as? EvalItem, let parent = sourceName["derived_from"] as? String,
               let provenance = (try? json(provenanceURL)) as? EvalItem,
               let editMap = provenance["edit_map"] as? EvalItem, editMap["corrected_sha256"] as? String == audioHash,
               let sourceDefinition = (try? json(path("eval/transcribe/history/review/\(parent).json"))) as? EvalItem,
               sourceDefinition["audio_sha256"] as? String == provenance["source_audio_sha256"] as? String,
               sourceDefinition["reference_sha256"] as? String == provenance["source_reference_sha256"] as? String {
                let sourceText = ReviewText(try read(path("eval/transcribe/history/expected/\(parent).md")))
                var originals = sourceDefinition["passages"] as? [EvalItem] ?? []
                for i in originals.indices {
                    if let a = originals[i]["reference_start_word"] as? Int, let b = originals[i]["reference_end_word"] as? Int { originals[i]["reference"] = sourceText.excerpt(a, b) }
                }
                carried = try inheritedReviewPassages(passages: passages, source: originals, decisions: provenance["owner_decisions"] as? [String: EvalItem] ?? [:], edits: editMap["edits"] as? [EvalItem] ?? [])
            }
            recordings.append(["selection": generateDifferences ? "aligned-differences" : "listening-checklist", "id": identifier, "name": name, "title": title, "language": evaluator.string(fixture, "language"), "duration": duration, "audio": audioPath, "reference": reference, "app_transcript": transcript as Any? ?? NSNull(), "second_transcript": second as Any? ?? NSNull(), "app_label": evaluator.string(item, "model_label", "Saved evaluation transcript"), "comparison_label": comparisonLabel, "reference_sha256": referenceHash, "audio_sha256": audioHash, "output_sha256": (try? hash(output)) as Any? ?? NSNull(), "passages": passages, "carried_passages": carried])
        }
        let data: EvalItem = ["selection": generateDifferences ? "aligned-differences" : "listening-checklist", "version": 1, "run": run.path, "app_source_hashes": try hashes(files(source)), "comparison_source": comparison?.path as Any? ?? previousData?["comparison_source"] ?? NSNull(), "recordings": recordings]
        try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]).write(to: app.appendingPathComponent("recordings.json"), options: .atomic)
        try write(app.appendingPathComponent("README.txt"), "Run from the repository: make evals-review RUN_DIR=\(run.path)\nDecisions are saved in review-state.json. Regeneration preserves them. Audio/reference changes invalidate prior verification without discarding its saved text.\n")
        return app
    }
    func inheritedReviewPassages(passages: [EvalItem], source: [EvalItem], decisions: [String: EvalItem], edits: [EvalItem]) throws -> [String] {
        var result: [String] = []
        for passage in passages {
            guard let id = passage["id"] as? String, let original = source.first(where: { $0["short_id"] as? String == passage["short_id"] as? String }),
                  let sourceID = original["id"] as? String, let decision = decisions[sourceID],
                  ["matches", "corrected"].contains(decision["status"] as? String ?? ""),
                  let start = original["start_seconds"] as? Double, let end = original["end_seconds"] as? Double else { continue }
            let changedAudio = edits.contains { edit in
                guard edit["kind"] as? String == "replacement", let a = edit["original_start"] as? Double, let b = edit["original_end"] as? Double else { return false }
                return a < end && b > start
            }
            if changedAudio { continue }
            let confirmed = decision["status"] as? String == "corrected" ? decision["words"] as? String ?? "" : original["reference"] as? String ?? ""
            guard !confirmed.isEmpty, let expected = passage["reference"] as? String, try TranscriptionScore(reference: confirmed, hypothesis: expected).json["errors"] as? Int == 0 else { continue }
            result.append(id)
        }
        return result
    }
    func evalsReview(_ args: [String]) throws {
        var run: URL?, comparison: URL?, port: UInt16 = 8777, prepareOnly = false, differencesOnly = false, serveSaved = false, i = 0
        func value() throws -> String { i += 1; try require(i < args.count, "Missing review option value", status: 2); return args[i] }
        while i < args.count {
            switch args[i] {
            case "--run": run = path(try value()).standardizedFileURL
            case "--comparison-run": comparison = path(try value()).standardizedFileURL
            case "--port": guard let parsed = UInt16(try value()), parsed > 0 else { throw ToolFailure("Invalid review port", status: 2) }; port = parsed
            case "--differences": differencesOnly = true
            case "--serve-saved": serveSaved = true
            case "--prepare-only": prepareOnly = true
            case "--help", "-h": print("Usage: make evals-review RUN_DIR=RUN [COMPARISON_RUN=RUN_OR_TRANSCRIPT_DIR] [PORT=8777] [ARGS='--differences --prepare-only|--serve-saved']"); return
            default: throw ToolFailure("Unknown review option: \(args[i])", status: 2)
            }
            i += 1
        }
        try require(run != nil, "Specify a saved evaluation RUN_DIR", status: 2)
        let app: URL
        if serveSaved {
            try require(!prepareOnly && !differencesOnly && comparison == nil, "--serve-saved only opens existing review files; do not combine it with preparation options", status: 2)
            app = run!.appendingPathComponent("review-app")
            try require(fm.fileExists(atPath: app.appendingPathComponent("recordings.json").path) && fm.fileExists(atPath: app.appendingPathComponent("index.html").path), "No saved review app exists", status: 2)
        } else {
            guard let prepared = try prepareEvalReview(run!, comparison: comparison, differencesOnly: differencesOnly) else { throw ToolFailure("No transcription cases in the selected evaluation run", status: 2) }
            app = prepared
        }
        if prepareOnly { print("Prepared review app: \(app.path)"); return }
        let catalog = path("tmp/eval-review-sessions.json")
        let server = try EvalReviewServer(root: app, port: port, catalog: catalog)
        var sessions = (try? json(catalog)) as? [EvalItem] ?? []
        let baseURL = "http://127.0.0.1:\(server.port)"
        sessions.removeAll { $0["url"] as? String == baseURL || $0["root"] as? String == app.resolvingSymlinksInPath().path }
        sessions.append(["root": app.resolvingSymlinksInPath().path, "url": baseURL])
        try mkdir(catalog.deletingLastPathComponent())
        try json(catalog, sessions)
        print("Local: http://127.0.0.1:\(server.port)")
        print("Review decisions: \(app.appendingPathComponent("review-state.json").path)")
        fflush(stdout)
        try server.serve()
    }
}

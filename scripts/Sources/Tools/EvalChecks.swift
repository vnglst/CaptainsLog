import Foundation
import Yams

extension Tools {
    func evalFixture(_ args: [String]) throws {
        let tool = URL(fileURLWithPath: CommandLine.arguments[0]).lastPathComponent
        if tool == "swift" { if args.first == "--version" { print("fixture-swift") } else if args.contains("--show-bin-path") { print(environment["EVAL_FIXTURE_BIN"]!) }; return }
        if tool == "otool" { print("fixture-runtime"); return }
        guard let command = args.first else { throw ToolFailure("unexpected fixture command") }
        let root = URL(fileURLWithPath: environment["EVAL_FIXTURE_ROOT"]!), calls = URL(fileURLWithPath: environment["EVAL_FIXTURE_CALLS"]!)
        let previous = (try? read(calls)) ?? ""; try write(calls, previous + command + "\n")
        func source(_ value: String) throws -> String { try read(root.appendingPathComponent("eval/" + value)) }
        func value(_ flag: String) throws -> String { guard let i = args.firstIndex(of: flag), i+1 < args.count else { throw ToolFailure("Missing fixture argument \(flag)") }; return args[i+1] }
        func enriched(_ data: [String: Any], _ body: String) throws -> String { "---\n" + (try Yams.dump(object: data)) + "---\n\n" + body }
        switch command {
        case "enrich" where args.contains("--print-prompt"):
            guard let seed = UInt64(try value("--seed")), seed < 4294967295 else { throw ToolFailure("Error: invalid seed") }; print("FinanceHub")
        case "eval-batch":
            guard let items = try json(path(value("--manifest"))) as? [EvalItem] else { throw ToolFailure("Invalid fixture batch") }
            for item in items {
                let eval = Evaluator(self), expected = try read(eval.file(item, "expected")), stage = eval.string(item, "stage")
                var output = expected
                if stage == "enrich" {
                    var data = try expectedFrontmatter(eval.file(item, "expected"))
                    for key in ["categories", "tags", "persons", "projects", "companies", "entities"] where data[key] == nil { data[key] = [String]() }
                    data["date"] = item["date"]; data["recording_time"] = item["recording_time"]
                    output = try enriched(data, read(eval.file(item, "input")))
                } else if stage == "categorize" { output = String(decoding: try JSONSerialization.data(withJSONObject: ["sourceStem": item["name"]!, "category": expected.trimmingCharacters(in: .whitespacesAndNewlines)]), as: UTF8.self) }
                else if stage == "filename" { output = expected.replacingOccurrences(of: "\\A\\d{4}-\\d{2}-\\d{2}", with: "2025-01-15", options: .regularExpression) }
                try write(eval.file(item, "output"), output)
            }
        case "transcribe":
            let name = URL(fileURLWithPath: args[1]).deletingPathExtension().lastPathComponent
            try write(path(value("--output")), source("transcribe/expected/\(name).md"))
        case "pipeline":
            let data = path(environment["CAPTAINS_LOG_DATA_DIR"]!), stem = "2025-01-14 side project", slug = "2025-01-14-side-project-star-trek-voice-log"
            let transcript = try source("transcribe/expected/\(stem).md"), cleaned = try source("cleanup/expected/\(stem).md")
            var frontmatter = try expectedFrontmatter(root.appendingPathComponent("eval/enrich/expected/\(stem).md")); frontmatter["date"] = "2025-01-14"
            let audio = data.appendingPathComponent("audio/\(stem).m4a"); try copy(root.appendingPathComponent("eval/transcribe/audio/\(stem).m4a"), audio)
            let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"; frontmatter["recording_time"] = formatter.string(from: try fm.attributesOfItem(atPath: audio.path)[.creationDate] as! Date)
            let category = String(decoding: try JSONSerialization.data(withJSONObject: ["sourceStem": stem, "category": "side_project"]), as: UTF8.self)
            let artifacts = [".pipeline/01-transcribed/\(stem).md": transcript, ".pipeline/02-logs/\(stem).md": cleaned, ".pipeline/03-category/\(stem).json": category, ".pipeline/04-rename/\(stem).slug.txt": slug, ".pipeline/04-rename/\(slug).md": cleaned, "logs/side-project/\(slug).md": try enriched(frontmatter, cleaned)]
            for (relative, text) in artifacts { if environment["EVAL_FIXTURE_OMIT_ENRICH"] != nil && relative.hasPrefix("logs/") { continue }; try write(data.appendingPathComponent(relative), text) }
        case "search": print(environment["CAPTAINS_LOG_DATA_DIR"]! + "/logs/side-project/2025-01-14-side-project-star-trek-voice-log.md")
        case "resume", "search-index": print("fixture no-op")
        default: throw ToolFailure("unexpected fixture command: \(command)")
        }
    }
    func testEvals() throws {
        var checks = 0
        func assert(_ condition: @autoclosure () throws -> Bool, _ message: String) throws { try require(condition(), message); checks += 1 }
        let dir = try temporary("captainslog-eval-tests-"); defer { try? fm.removeItem(at: dir) }
        let eval = Evaluator(self)
        var item = try eval.cases(["enrich"], "01_work_week")[0]; item["output"] = dir.appendingPathComponent("generated.md").path; item["recording_time"] = "12:00"
        let body = try read(eval.file(item, "input"))
        let data: EvalItem = ["date": "2025-01-15", "recording_time": "12:00", "language": "English", "categories": ["work"], "tags": ["work", "planning", "meetings"], "persons": [String](), "projects": [String](), "companies": [String](), "entities": [String](), "summary": "A work week."]
        func writeValue(_ value: Any, _ text: String? = nil) throws { try write(eval.file(item, "output"), "---\n" + Yams.dump(object: value) + "---\n\n" + (text ?? body)) }
        try writeValue(data); try assert(eval.validate(item) == "PASS", "valid enrichment rejected")
        var bad: [Any] = [NSNull(), EvalItem()]
        for (key, value) in [("tags", [NSNull()] as Any), ("entities", [["Apple": "company"]] as Any), ("persons", [""] as Any), ("summary", "" as Any), ("language", "" as Any), ("date", "2025-01-14" as Any), ("recording_time", "25:00" as Any), ("categories", [String]() as Any), ("categories", ["finance"] as Any), ("extra", "field" as Any)] { var wrong = data; wrong[key] = value; bad.append(wrong) }
        for value in bad { try writeValue(value); try assert(eval.validate(item).hasPrefix("FAIL:"), "malformed enrichment accepted") }
        try writeValue(data, body + "Added fact."); try assert(eval.validate(item).contains("source body changed"), "body mutation accepted")
        try writeValue(data); try write(eval.file(item, "output"), read(eval.file(item, "output")).replacingOccurrences(of: "language: English", with: "language: English\nlanguage: Dutch")); try assert(eval.validate(item).contains("duplicate"), "duplicate YAML key accepted")
        for text in ["---\ntags: [broken\n---\n\n" + body, "---\nentities: &entity [Apple]\ntags: *entity\n---\n\n" + body] { try write(eval.file(item, "output"), text); try assert(eval.validate(item).hasPrefix("FAIL:"), "broken YAML or alias accepted") }
        try Data([255]).write(to: eval.file(item, "output")); try assert(eval.validate(item).contains("UTF-8"), "invalid UTF-8 accepted")
        try fm.removeItem(at: eval.file(item, "output")); try assert(eval.validate(item).hasPrefix("FAIL:"), "missing output accepted")
        var filename = try eval.cases(["filename"], "04_short_entry")[0]; filename["output"] = dir.appendingPathComponent("filename.md").path
        try write(eval.file(filename, "output"), "2025-01-15-three-grounded-words.md\n"); try assert(eval.validate(filename) == "PASS", "valid filename rejected")
        for name in ["2025-01-15-two-words.md", "2025-01-15-Upper-case-word.md", "2025-01-14-three-grounded-words.md", "2025-01-15-three-grounded-words.md\nExplanation"] { try write(eval.file(filename, "output"), name); try assert(eval.validate(filename).hasPrefix("FAIL:"), "invalid filename accepted") }
        var category = try eval.cases(["categorize"], "personal-weekend")[0]; category["output"] = dir.appendingPathComponent("category.json").path
        for (index, pair) in [("personal-weekend", "personal"), ("wrong", "personal"), ("personal-weekend", "professional")].enumerated() { try json(eval.file(category, "output"), ["sourceStem": pair.0, "category": pair.1]); try assert((eval.validate(category) == "PASS") == (index == 0), "category validation mismatch") }
        var cleanup = try eval.cases(["cleanup"], "book-reference")[0]; cleanup["output"] = dir.appendingPathComponent("cleanup.md").path
        for text in ["", "<think>private reasoning</think>", "bad\0text", "```output"] { try write(eval.file(cleanup, "output"), text); try assert(eval.validate(cleanup).hasPrefix("FAIL:"), "malformed cleanup accepted") }
        try copy(eval.file(cleanup, "expected"), eval.file(cleanup, "output")); try assert(eval.validate(cleanup) == "PASS", "valid cleanup rejected")
        try assert(eval.cases(eval.stages).count == 24, "suite selection changed unexpectedly"); try assert(eval.cases(["filename"], "04_short_entry").count == 1, "case selection mismatch")
        do { _ = try eval.cases(["cleanup"], "missing"); throw ToolFailure("unknown fixture silently skipped") } catch { try assert(String(describing: error).contains("No fixtures"), "wrong unknown-fixture error") }
        try writeValue(data); try assert(eval.evidence(dir, [item]), "valid evidence failed")
        let review = dir.appendingPathComponent("review/suites/enrich/01_work_week"), report = review.appendingPathComponent("report.md")
        try assert(fm.fileExists(atPath: review.appendingPathComponent("input.md").path), "missing input snapshot")
        let original = try read(report); try write(report, original + "Authored finding"); try assert(original.contains("Added or hallucinated"), "missing review guidance")
        var baseline = item; baseline["output"] = dir.appendingPathComponent("baseline.md").path; try write(eval.file(baseline, "output"), read(eval.file(item, "output")).replacingOccurrences(of: "work week", with: "week at work"))
        try assert(eval.evidence(dir, [item], [baseline]), "baseline evidence failed"); try assert(read(report).contains("Authored finding"), "revalidation overwrote authored review"); try assert(read(review.appendingPathComponent("baseline.diff")).contains("week at work"), "missing baseline diff")
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
        func cli(_ args: [String], _ env: [String: String] = [:]) throws -> CommandResult { try run([executable, "evals"] + args, quiet: true, allowFailure: true, environment: env) }
        try writeValue(data, body + "Changed"); try json(dir.appendingPathComponent("manifest.json"), [item]); var response = try cli(["--validate-run", dir.path]); try assert(response.status == 1 && response.output.contains("source body changed"), "validator failure did not fail CLI")
        response = try cli(["--stage", "filename", "--case", "04_short_entry", "--list"]); try assert(response.status == 0 && response.output.trimmingCharacters(in: .whitespacesAndNewlines) == "filename/04_short_entry", "CLI selection mismatch")
        response = try cli(["--suites", "--case", "04_short_entry"]); try assert(response.status == 2 && response.output.contains("--case requires"), "ambiguous selection accepted")
        try assert((try eval.settings()["enrich"] as? EvalItem)?["max_tokens"] as? Int == 4096, "generation defaults not resolved")
        try json(dir.appendingPathComponent("manifest.json"), [EvalItem]()); response = try cli(["--validate-run", dir.path]); try assert(response.status == 2, "empty saved manifest accepted")
        let bin = dir.appendingPathComponent("bin"); try mkdir(bin)
        for command in ["swift", "otool", "cl"] { try fm.createSymbolicLink(atPath: bin.appendingPathComponent(command).path, withDestinationPath: executable) }
        let models = dir.appendingPathComponent("models"), whisper = dir.appendingPathComponent("whisper")
        try copy(eval.file(item, "input"), models.appendingPathComponent("fixture.gguf")); try copy(eval.file(item, "input"), whisper.appendingPathComponent("fixture-model"))
        let env = ["PATH": bin.path + ":" + (environment["PATH"] ?? ""), "CAPTAINS_LOG_EVAL_QWEN_FOLDER": models.path, "CAPTAINS_LOG_EVAL_QWEN_FILE": "fixture.gguf", "CAPTAINS_LOG_EVAL_WHISPER_FOLDER": whisper.path, "EVAL_FIXTURE_ROOT": root.path, "EVAL_FIXTURE_CALLS": dir.appendingPathComponent("calls").path, "EVAL_FIXTURE_BIN": bin.path, "CAPTAINS_LOG_TOOL_FIXTURE_KIND": "eval"]
        func runFixture(_ name: String, _ args: [String], _ extra: [String: String] = [:]) throws -> (URL, CommandResult) { let saved = dir.appendingPathComponent(name); return (saved, try cli(args, env.merging(extra) { _, n in n }.merging(["CAPTAINS_LOG_EVAL_RUN_DIR": saved.path]) { _, n in n })) }
        var savedRuns: [URL] = []
        defer { for saved in savedRuns { if let manifest = (try? json(saved.appendingPathComponent("manifest.json"))) as? [EvalItem] { for item in manifest where eval.string(item, "scope") != "pipeline" { try? fm.removeItem(at: eval.file(item, "output")) } } } }
        let (suite, suiteResult) = try runFixture("suite", ["--suites"]); savedRuns.append(suite); try assert(suiteResult.status == 0, "suite fixture failed: \(suiteResult.output)")
        let manifest = try json(suite.appendingPathComponent("manifest.json")) as! [EvalItem]; try assert(manifest.count == 24, "full suite dropped cases")
        let calls = try read(dir.appendingPathComponent("calls")).split(separator: "\n").map(String.init); try assert(calls.filter { $0 != "enrich" } == ["transcribe", "transcribe", "transcribe", "transcribe", "eval-batch"], "suite did not batch text after sequential audio")
        let metadata = try json(suite.appendingPathComponent("metadata.json")) as! EvalItem
        try assert(((metadata["models"] as? EvalItem)?["qwen"] as? EvalItem)?["sha256"] as? String == hash(eval.file(item, "input")), "actual model identity missing")
        try assert(metadata["status"] as? String == "passed-mechanical-checks" && (metadata["fixture_hashes"] as? EvalItem)?.count == 48, "suite metadata incomplete")
        let regression = manifest.first { eval.string($0, "name") == "04_fictional_name_loop" }!
        try assert(eval.string(regression, "date") == "2025-02-18" && eval.string(regression, "recording_time") == "20:30" && regression["seed"] as? Int == 42, "enrichment case settings lost")
        try assert(read(suite.appendingPathComponent("enrich-cases.json")) == read(path("eval/enrich/cases.json")), "enrichment manifest not snapshotted")
        try write(eval.file(regression, "input"), read(eval.file(regression, "input")) + "Changed fixture."); try assert(eval.validate(regression).hasPrefix("FAIL:"), "changed saved regression source accepted"); try copy(path("eval/enrich/input/04_fictional_name_loop.md"), eval.file(regression, "input"))
        let (focused, focusedResult) = try runFixture("focused", ["--stage", "filename", "--case", "04_short_entry", "--baseline", suite.path], ["CAPTAINS_LOG_EVAL_WHISPER_FOLDER": "/missing-whisper"]); savedRuns.append(focused); try assert(focusedResult.status == 0, "focused fixture required unrelated model: \(focusedResult.output)"); try assert((try json(focused.appendingPathComponent("manifest.json")) as? [EvalItem])?.count == 1, "focused run included other cases")
        response = try cli(["--stage", "filename"], env.merging(["CAPTAINS_LOG_EVAL_RUN_DIR": focused.path]) { _, n in n }); try assert(response.status == 2 && response.output.contains("already exists"), "run overwrite accepted")
        let (enrich, enrichResult) = try runFixture("enrich-only", ["--enrich"], ["CAPTAINS_LOG_EVAL_WHISPER_FOLDER": "/missing-whisper"]); savedRuns.append(enrich); try assert(enrichResult.status == 0 && (try json(enrich.appendingPathComponent("manifest.json")) as? [EvalItem])?.count == 5, "enrichment alias failed: \(enrichResult.output)")
        let (failed, failedResult) = try runFixture("missing-model", ["--stage", "filename", "--case", "04_short_entry"], ["CAPTAINS_LOG_EVAL_QWEN_FOLDER": "/missing-qwen"]); try assert(failedResult.status == 1 && (try json(failed.appendingPathComponent("metadata.json")) as? EvalItem)?["status"] as? String == "failed", "missing model failure was not retained")
        let (pipeline, pipelineResult) = try runFixture("pipeline", ["--pipeline"]); try assert(pipelineResult.status == 0, "pipeline fixture failed: \(pipelineResult.output)"); try assert((try json(pipeline.appendingPathComponent("manifest.json")) as? [EvalItem])?.count == 5, "pipeline review did not include every stage"); try assert(read(pipeline.appendingPathComponent("before-resume.sha256")) == read(pipeline.appendingPathComponent("after-resume.sha256")), "resume immutability check lost")
        let (omitted, omittedResult) = try runFixture("omitted-pipeline-artifact", ["--pipeline"], ["EVAL_FIXTURE_OMIT_ENRICH": "1"]); try assert(omittedResult.status == 1 && omittedResult.output.contains("Missing renamed/enriched artifacts"), "pipeline assertion did not stop for missing output"); try assert(!fm.fileExists(atPath: omitted.appendingPathComponent("resume.log").path), "pipeline continued after failed artifact assertion")
        let (combined, combinedResult) = try runFixture("all", ["--all"]); savedRuns.append(combined); try assert(combinedResult.status == 0, "combined release gate fixture failed: \(combinedResult.output)"); try assert((try json(combined.appendingPathComponent("manifest.json")) as? [EvalItem])?.count == 29, "combined gate dropped pipeline or suite cases")
        try require(checks == 66, "Expected 66 evaluation tooling checks, got \(checks)")
        print("PASS: \(checks) evaluation tooling checks")
        let aliasYAML = "---\ndate: \"2025-01-15\"\nrecording_time: \"12:00\"\nlanguage: English\ncategories: [work]\ntags: &names [work, planning, meetings]\npersons: []\nprojects: []\ncompanies: []\nentities: *names\nsummary: A work week.\n---\n\n"
        try write(eval.file(item, "output"), aliasYAML + body)
        try require(eval.validate(item).contains("alias"), "Full-schema YAML alias was accepted or failed for an unrelated reason")
        let unicodeInput = dir.appendingPathComponent("unicode-source.md")
        try write(unicodeInput, body + "caf\u{00e9}")
        item["input"] = unicodeInput.path
        try writeValue(data, body + "cafe\u{0301}")
        try require(eval.validate(item).contains("source body changed"), "Canonically equivalent but byte-changed source body was accepted")
        print("PASS: full-schema YAML alias and byte-exact Unicode body boundary checks")
    }
}

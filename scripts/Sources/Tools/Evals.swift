import Foundation
import Yams

typealias EvalItem = [String: Any]
final class Evaluator {
    let tools: Tools
    var errorStatus: Int32 = 2
    let stages = ["transcribe", "cleanup", "filename", "enrich", "categorize"]
    let date = "2025-01-15", time = "12:00"
    init(_ tools: Tools) { self.tools = tools }
    func string(_ item: EvalItem, _ key: String, _ fallback: String = "") -> String { item[key] as? String ?? fallback }
    func file(_ item: EvalItem, _ key: String) -> URL { tools.path(string(item, key)) }
    func cases(_ selectedStages: [String], _ selected: String? = nil) throws -> [EvalItem] {
        var result: [EvalItem] = []
        for stage in selectedStages {
            var enrichment: [String: EvalItem]?
            if stage == "enrich" {
                try tools.validateEnrichCases(tools.path("eval/enrich/cases.json"), tools.path("eval/enrich/input"))
                enrichment = try tools.json(tools.path("eval/enrich/cases.json")) as? [String: EvalItem]
            }
            let ext = stage == "transcribe" ? "m4a" : "md", folder = stage == "transcribe" ? "audio" : "input"
            let inputs = tools.files(tools.path("eval/\(stage)/\(folder)")).filter { $0.pathExtension == ext && (selected == nil || $0.deletingPathExtension().lastPathComponent == selected) }
            try tools.require(!inputs.isEmpty, "No fixtures for \(stage)" + (selected.map { "/" + $0 } ?? ""))
            for input in inputs {
                let name = input.deletingPathExtension().lastPathComponent
                let expected = tools.path("eval/\(stage)/expected/\(name).\(stage == "categorize" ? "category" : "md")")
                try tools.require(tools.fm.fileExists(atPath: expected.path), "Missing expected fixture: \(expected.path)")
                var item: EvalItem = ["stage": stage, "name": name, "input": input.path, "expected": expected.path]
                if let settings = enrichment?[name] {
                    item.merge(settings.filter { $0.key != "sha256" }) { _, new in new }
                    if let hash = settings["sha256"] { item["input_sha256"] = hash }
                }
                result.append(item)
            }
        }
        return result
    }
    func validate(_ item: EvalItem) -> String {
        do {
            let bytes = try Data(contentsOf: file(item, "output"))
            guard let text = String(data: bytes, encoding: .utf8) else { throw ToolFailure("invalid UTF-8") }
            try tools.require(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "empty output")
            try tools.require(tools.match("[\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f\\x7f]", text) == nil, "NUL/control bytes in output")
            switch string(item, "stage") {
            case "filename":
                var name = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if string(item, "scope") == "pipeline" { name += ".md" }
                let supplied = NSRegularExpression.escapedPattern(for: string(item, "date", date))
                try tools.require(tools.match("\\A\(supplied)-[\\p{Ll}\\p{N}]+(?:-[\\p{Ll}\\p{N}]+){2,7}\\.md\\z", name) != nil, "filename must use supplied date and 3–8 lowercase kebab words")
            case "categorize":
                guard let data = try JSONSerialization.jsonObject(with: bytes) as? EvalItem else { throw ToolFailure("category manifest must contain only category and sourceStem") }
                try tools.require(data.keys.sorted() == ["category", "sourceStem"], "category manifest must contain only category and sourceStem")
                try tools.require(data["sourceStem"] as? String == string(item, "name"), "sourceStem mismatch")
                try tools.require(data["category"] as? String == tools.read(file(item, "expected")).trimmingCharacters(in: .whitespacesAndNewlines), "category mismatch")
            case "enrich":
                let (yaml, body) = try tools.frontmatter(text, strict: true)
                let data = try tools.yamlMapping(yaml)
                let required = ["date", "recording_time", "language", "categories", "tags", "persons", "projects", "companies", "entities", "summary"]
                try tools.require(data.keys.sorted() == required.sorted(), "incorrect frontmatter fields")
                for key in ["categories", "tags", "persons", "projects", "companies", "entities"] {
                    guard let values = data[key] as? [String], values.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw ToolFailure("\(key) must be a list of nonempty strings") }
                }
                for key in ["date", "recording_time", "language", "summary"] { try tools.require(!(data[key] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(key) must be nonempty text") }
                try tools.require(data["date"] as? String == string(item, "date", date), "date differs from supplied date")
                if let supplied = item["recording_time"] as? String { try tools.require(data["recording_time"] as? String == supplied, "recording_time differs from supplied time") }
                try tools.require(tools.match("\\A(?:[01]\\d|2[0-3]):[0-5]\\d\\z", data["recording_time"] as? String ?? "") != nil, "invalid recording_time")
                let categories = data["categories"] as? [String] ?? []
                try tools.require(!categories.isEmpty && categories.allSatisfy { ["personal", "work", "side-project"].contains($0) }, "categories must use personal, work or side-project")
                let source = try tools.read(file(item, "input"))
                try tools.require(body.utf8.elementsEqual(source.utf8), "source body changed")
                if let hash = item["input_sha256"] { try tools.validateCaseInput(file(item, "input"), ["sha256": hash]) }
                var expected = try tools.expectedFrontmatter(file(item, "expected"))
                expected["date"] = string(item, "date", date); expected["recording_time"] = string(item, "recording_time", time)
                try tools.validateEnrich(source, text, expected)
            case "cleanup", "transcribe":
                try tools.require(tools.match("<\\|(?:im_start|im_end|endoftext)\\|>|</?think>|\\A```", text) == nil, "model wrapper or special token leaked into text")
            default: throw ToolFailure("unknown stage")
            }
            return "PASS"
        } catch { return "FAIL: \(error)" }
    }
    func link(_ value: String) -> String { value.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~/")) ?? value }
    func evidence(_ run: URL, _ items: [EvalItem], _ baseline: [EvalItem]? = nil) throws -> Bool {
        var failures = 0
        var index = ["# Evaluation review", "", "Mechanical success does not establish semantic quality. Read every selected case; owner judgment remains required.", ""]
        for item in items {
            let relative = "review/\(string(item, "scope", "suites"))/\(string(item, "stage"))/\(string(item, "name"))", folder = run.appendingPathComponent(relative)
            try tools.mkdir(folder)
            for key in ["input", "expected", "output"] { let url = file(item, key); if tools.fm.fileExists(atPath: url.path) { try tools.copy(url, folder.appendingPathComponent(key + "." + url.pathExtension)) } }
            let status = validate(item); if status != "PASS" { failures += 1 }
            print("\(string(item, "stage"))/\(string(item, "name")): \(status)")
            try tools.write(folder.appendingPathComponent("validation.txt"), status + "\n")
            func contents(_ key: String, scrub: Bool = false) -> String {
                guard let data = try? Data(contentsOf: file(item, key)) else { return "(missing)" }
                return scrub ? String(decoding: data, as: UTF8.self) : (String(data: data, encoding: .utf8) ?? "(invalid UTF-8)")
            }
            var parts = ["# \(string(item, "stage"))/\(string(item, "name"))", "", "Validation: \(status)", "", "Input: [\(string(item, "input"))](\(link(string(item, "input"))))", "", "## Input", "", string(item, "stage") == "transcribe" ? "(Audio fixture linked above.)" : contents("input"), "", "## Expected", "", contents("expected"), "", "## Generated", "", contents("output", scrub: true), ""]
            if let baseline {
                if let previous = baseline.first(where: { string($0, "scope") == string(item, "scope") && string($0, "stage") == string(item, "stage") && string($0, "name") == string(item, "name") }), tools.fm.fileExists(atPath: file(previous, "output").path), tools.fm.fileExists(atPath: file(item, "output").path) {
                    let old = file(previous, "output")
                    try tools.copy(old, folder.appendingPathComponent("baseline." + old.pathExtension))
                    let diff = try tools.run(["diff", "-u", old.path, file(item, "output").path], quiet: true, allowFailure: true)
                    try tools.require([0,1].contains(diff.status), "baseline diff failed")
                    try tools.write(folder.appendingPathComponent("baseline.diff"), diff.output)
                    parts += ["## Baseline changes (navigation only)", "", "```diff", diff.output, "```", ""]
                } else { parts += ["Baseline: no matching saved output.", ""] }
            }
            let report = folder.appendingPathComponent("report.md")
            if !tools.fm.fileExists(atPath: report.path) { try tools.write(report, "# Semantic review (fill after reading)\n\n- Omissions / changed meaning: pending\n- Added or hallucinated content: pending\n- Improvements / regressions against baseline: pending (or no baseline)\n- Stage-specific observations: pending\n- Judgment and remaining limits: pending owner review\n") }
            parts += ["[Semantic report](report.md)", ""]
            try tools.write(folder.appendingPathComponent("review.md"), parts.joined(separator: "\n"))
            index.append("- [\(string(item, "stage"))/\(string(item, "name"))](\(link(relative + "/review.md"))): \(status)")
        }
        try tools.write(run.appendingPathComponent("review.md"), index.joined(separator: "\n") + "\n")
        try tools.json(run.appendingPathComponent("validation.json"), ["cases": items.count, "failures": failures, "validator_sha256": tools.hash(tools.path("scripts/Sources/Tools/Evals.swift")), "enrichment_validator_sha256": tools.hash(tools.path("scripts/Sources/Tools/EnrichValidation.swift"))])
        print("Validated \(items.count) cases; failures: \(failures). Review: \(run.path)/review.md")
        return failures == 0
    }
    func settings() throws -> EvalItem {
        let llm = try tools.read(tools.path("Sources/CaptainsLogCore/LLM.swift"))
        var result: EvalItem = [:]
        for stage in stages where stage != "transcribe" {
            let source = try tools.read(tools.path("Sources/CaptainsLogCore/\(stage.prefix(1).uppercased() + stage.dropFirst()).swift"))
            guard let max = tools.match("defaultMaxTokens = ([\\d_]+)", source, group: 1) ?? tools.match("maxTokens: Int = (\\d+)", llm, group: 1), let temp = tools.match("defaultTemperature: Float = ([\\d.]+)", source, group: 1) ?? tools.match("temperature: Float = ([\\d.]+)", llm, group: 1), let k = tools.match("llama_sampler_init_top_k\\((\\d+)\\)", llm, group: 1), let p = tools.match("llama_sampler_init_top_p\\(([\\d.]+),", llm, group: 1) else { throw ToolFailure("Cannot resolve generation defaults") }
            result[stage] = ["max_tokens": Int(max.replacingOccurrences(of: "_", with: ""))!, "temperature": Double(temp)!, "prevent_repetition": stage == "enrich", "top_k": Int(k)!, "top_p": Double(p)!, "dry": stage == "enrich" ? (tools.match("llama_sampler_init_dry\\(vocab, ([^)]+)\\)", llm, group: 1) as Any? ?? NSNull()) : NSNull(), "seed_policy": stage == "enrich" ? "per-case manifest seed; pipeline uses random default" : "LLAMA_DEFAULT_SEED (random per fresh sampler)", "context_policy": "LLM.plannedContextSize; fresh context per call", "parameter_scope": "stage defaults; date/time are per-case manifest values"] as EvalItem
        }
        result["transcribe"] = ["language": "auto-detect", "skip_special_tokens": true, "audio_encoder_compute": "cpuAndGPU", "text_decoder_compute": "cpuAndGPU"] as EvalItem
        return result
    }
    func nameOutputs(_ items: inout [EvalItem], _ stamp: String) throws {
        for i in items.indices {
            let stage = string(items[i], "stage"), label = stage == "transcribe" ? tools.environment["CAPTAINS_LOG_EVAL_WHISPER_MODEL"] ?? "openai_whisper-large-v2" : tools.environment["CAPTAINS_LOG_EVAL_QWEN_LABEL"] ?? "Qwen3.5-9B-Q4_K_M"
            try tools.require(tools.match("\\A[\\w.-]+\\z", label) != nil, "Model label must be a filename component")
            items[i]["output"] = tools.path("eval/\(stage)/generated/\(stamp)_\(label)_\(string(items[i], "name")).\(stage == "categorize" ? "json" : "md")").path
            if items[i]["date"] == nil { items[i]["date"] = date }; if items[i]["recording_time"] == nil { items[i]["recording_time"] = time }
        }
    }
    func baselineItems(_ path: String?) throws -> [EvalItem]? {
        guard let path else { return nil }; guard let items = try tools.json(tools.path(path).appendingPathComponent("manifest.json")) as? [EvalItem] else { throw ToolFailure("Invalid baseline manifest") }; return items
    }
    func configure(_ run: URL, _ stages: [String], _ mode: String, _ metadata: inout EvalItem) throws {
        let pipeline = ["--all", "--pipeline"].contains(mode)
        var config: EvalItem = ["schemaVersion": 1, "dataDir": run.appendingPathComponent("data").path], models: EvalItem = [:]
        if pipeline || stages.contains(where: { $0 != "transcribe" }) {
            let folder = tools.environment["CAPTAINS_LOG_EVAL_QWEN_FOLDER"] ?? NSHomeDirectory() + "/Library/Application Support/CaptainsLog/models"
            let model = tools.path(folder).appendingPathComponent(tools.environment["CAPTAINS_LOG_EVAL_QWEN_FILE"] ?? "Qwen_Qwen3.5-9B-Q4_K_M.gguf").resolvingSymlinksInPath()
            try tools.require(tools.fm.fileExists(atPath: model.path), "Not a Qwen file: \(model.path)")
            let destination = run.appendingPathComponent("models"); try tools.mkdir(destination)
            try tools.fm.createSymbolicLink(atPath: destination.appendingPathComponent("Qwen_Qwen3.5-9B-Q4_K_M.gguf").path, withDestinationPath: model.path)
            config["qwenModelFolder"] = destination.path
            models["qwen"] = ["path": model.path, "bytes": (try tools.fm.attributesOfItem(atPath: model.path))[.size]!, "sha256": try tools.hash(model)]
        }
        if pipeline || stages.contains("transcribe") {
            let model = tools.environment["CAPTAINS_LOG_EVAL_WHISPER_MODEL"] ?? "openai_whisper-large-v2"
            let folder = tools.path(tools.environment["CAPTAINS_LOG_EVAL_WHISPER_FOLDER"] ?? NSHomeDirectory() + "/Library/Caches/CaptainsLog/models/whisper/models/argmaxinc/whisperkit-coreml/\(model)").resolvingSymlinksInPath()
            var isDirectory: ObjCBool = false
            try tools.require(tools.fm.fileExists(atPath: folder.path, isDirectory: &isDirectory) && isDirectory.boolValue, "Whisper model folder missing: \(folder.path)")
            config["whisperModel"] = model; config["whisperModelFolder"] = folder.path
            models["whisper"] = ["path": folder.path, "model": model, "file_hashes": try tools.hashes(tools.files(folder, recursive: true))]
        }
        metadata["models"] = models; try tools.json(run.appendingPathComponent("config.json"), config)
        tools.environment["CAPTAINS_LOG_CONFIG_PATH"] = run.appendingPathComponent("config.json").path; tools.environment["CAPTAINS_LOG_DATA_DIR"] = run.appendingPathComponent("data").path
    }
    func pipelineCases(_ run: URL) -> [EvalItem] {
        let stem = "2025-01-14 side project", data = run.appendingPathComponent("data/.pipeline")
        let transcript = data.appendingPathComponent("01-transcribed/\(stem).md").path, cleaned = data.appendingPathComponent("02-logs/\(stem).md").path
        return [("transcribe", tools.path("eval/transcribe/audio/\(stem).m4a").path, transcript, "eval/transcribe/expected/\(stem).md"), ("cleanup", transcript, cleaned, "eval/cleanup/expected/\(stem).md"), ("categorize", cleaned, data.appendingPathComponent("03-category/\(stem).json").path, "eval/categorize/expected/side-project-voice-app.category"), ("filename", cleaned, data.appendingPathComponent("04-rename/\(stem).slug.txt").path, "eval/filename/expected/\(stem).md"), ("enrich", cleaned, run.appendingPathComponent("data/logs/missing.md").path, "eval/enrich/expected/\(stem).md")].map { ["scope": "pipeline", "stage": $0.0, "name": stem, "input": $0.1, "output": $0.2, "expected": tools.path($0.3).path, "date": "2025-01-14"] }
    }
    func refresh(_ run: URL, _ items: inout [EvalItem]) throws {
        guard let i = items.firstIndex(where: { string($0, "scope") == "pipeline" && string($0, "stage") == "enrich" }), let text = try? tools.read(run.appendingPathComponent("data/.pipeline/04-rename/2025-01-14 side project.slug.txt")) else { return }
        let slug = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let output = tools.files(run.appendingPathComponent("data/logs"), recursive: true).first(where: { $0.lastPathComponent == slug + ".md" }) { items[i]["output"] = output.path }
    }
    func pipelineParameters(_ run: URL, _ items: inout [EvalItem]) throws {
        let audio = run.appendingPathComponent("data/audio/2025-01-14 side project.m4a")
        guard let attributes = try? tools.fm.attributesOfItem(atPath: audio.path), let birth = attributes[.creationDate] as? Date else { return }
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
        for i in items.indices where string(items[i], "scope") == "pipeline" { items[i]["recording_time"] = formatter.string(from: birth) }
    }
    func recordPipeline(_ run: URL, _ items: inout [EvalItem], _ metadata: inout EvalItem) throws {
        try pipelineParameters(run, &items)
        let pipeline = items.filter { string($0, "scope") == "pipeline" }; guard !pipeline.isEmpty else { return }
        metadata["pipeline_parameters"] = pipeline.map { $0.filter { ["stage", "date", "recording_time"].contains($0.key) } }
        if tools.fm.fileExists(atPath: run.appendingPathComponent("data/.search/search.sqlite").path) {
            let model = tools.path(NSHomeDirectory() + "/Library/Application Support/CaptainsLog/models/embeddings/multilingual-e5-small-q8_0.gguf")
            var models = metadata["models"] as? EvalItem ?? [:]
            models["embeddings"] = ["path": model.path, "bytes": (try tools.fm.attributesOfItem(atPath: model.path))[.size]!, "sha256": try tools.hash(model)]; metadata["models"] = models
        }
    }
    func main(_ rawArgs: [String]) throws {
        let valued = ["--stage", "--case", "--baseline", "--validate-run", "--validate-enrich", "--validate-categorize"]
        let args = rawArgs.flatMap { arg -> [String] in
            guard let separator = arg.firstIndex(of: "="), valued.contains(String(arg[..<separator])) else { return [arg] }
            return [String(arg[..<separator]), String(arg[arg.index(after: separator)...])]
        }
        var mode = "--all", explicit = false, stage: String?, selected: String?, baselinePath: String?, validation: String?, legacy: String?, list = false, i = 0
        func value(_ flag: String) throws -> String { i += 1; try tools.require(i < args.count, "Missing value for \(flag)", status: 2); return args[i] }
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "--all", "--pipeline", "--suites", "--categorize", "--enrich": try tools.require(!explicit, "Choose one execution mode", status: 2); mode = arg; explicit = true
            case "--stage": try tools.require(!explicit, "Choose one execution mode", status: 2); stage = try value(arg); try tools.require(stages.contains(stage!), "Invalid stage: \(stage!)", status: 2); mode = arg; explicit = true
            case "--case": selected = try value(arg)
            case "--baseline": baselinePath = tools.path(try value(arg)).standardizedFileURL.path
            case "--validate-run", "--validate-enrich", "--validate-categorize": validation = try value(arg); if arg != "--validate-run" { legacy = arg == "--validate-enrich" ? "enrich" : "categorize" }
            case "--list": list = true
            case "-h", "--help": print("Usage: make evals ARGS=\"[--all|--pipeline|--suites|--categorize|--enrich|--stage STAGE [--case STEM]] [--baseline RUN_DIR] [--validate-run RUN_DIR_OR_STAMP] [--list]\""); return
            default: throw ToolFailure("Unexpected arguments: \(args[i...].joined(separator: " "))", status: 2)
            }
            i += 1
        }
        try tools.require(selected == nil || stage != nil, "--case requires --stage", status: 2)
        let chosen = stage.map { [$0] } ?? (["--categorize", "--enrich"].contains(mode) ? [String(mode.dropFirst(2))] : stages)
        if let validation {
            try tools.require(!explicit && selected == nil && !list, "Validation cannot be combined with execution options", status: 2)
            let saved = tools.path(validation).standardizedFileURL
            var items: [EvalItem], run: URL
            if tools.fm.fileExists(atPath: saved.appendingPathComponent("manifest.json").path) { run = saved; items = try tools.json(run.appendingPathComponent("manifest.json")) as? [EvalItem] ?? [] }
            else {
                try tools.require(tools.match("\\A[\\w.-]+\\z", validation) != nil, "Expected saved run directory or timestamp", status: 2)
                run = tools.path("tmp/eval-validation-\(validation)"); items = try cases(legacy.map { [$0] } ?? stages); try nameOutputs(&items, validation)
            }
            try tools.require(!items.isEmpty, "Saved manifest has no cases", status: 2)
            try refresh(run, &items); try pipelineParameters(run, &items)
            if tools.fm.fileExists(atPath: run.appendingPathComponent("manifest.json").path) { try tools.json(run.appendingPathComponent("manifest.json"), items) }
            let recorded = (try? tools.json(run.appendingPathComponent("metadata.json"))) as? EvalItem
            errorStatus = 1
            if try !evidence(run, items, baselineItems(baselinePath ?? recorded?["baseline"] as? String)) { throw ToolFailure("Saved evaluation failed validation") }; return
        }
        var items = mode == "--pipeline" ? [] : try cases(chosen, selected)
        if list { for item in items { print("\(string(item, "stage"))/\(string(item, "name"))") }; return }
        let baseline = try baselineItems(baselinePath)
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let stamp = formatter.string(from: Date()) + "_\(ProcessInfo.processInfo.processIdentifier)"
        let run = tools.path(tools.environment["CAPTAINS_LOG_EVAL_RUN_DIR"] ?? "tmp/evals-\(stamp)").standardizedFileURL
        try tools.require(!tools.fm.fileExists(atPath: run.path), "Run directory already exists: \(run.path)", status: 2)
        try nameOutputs(&items, stamp); try tools.mkdir(run)
        let started = ProcessInfo.processInfo.systemUptime
        var metadata: EvalItem = ["stamp": stamp, "started_at": ISO8601DateFormatter().string(from: Date()), "mode": mode, "revision": try tools.capture(["git", "rev-parse", "HEAD"]), "dirty_status": try tools.run(["git", "status", "--porcelain"], quiet: true).output, "generation": try settings(), "baseline": baselinePath as Any? ?? NSNull(), "status": "preparing"]
        errorStatus = 1
        do {
            if items.contains(where: { string($0, "stage") == "enrich" }) {
                try tools.copy(tools.path("eval/enrich/cases.json"), run.appendingPathComponent("enrich-cases.json")); metadata["enrich_cases_sha256"] = try tools.hash(run.appendingPathComponent("enrich-cases.json"))
                for i in items.indices where string(items[i], "stage") == "enrich" { items[i]["diagnostics"] = run.appendingPathComponent("enrich-\(string(items[i], "name")).log").path }
            }
            try configure(run, chosen, mode, &metadata)
            for i in items.indices {
                let folder = run.appendingPathComponent("fixtures/\(string(items[i], "stage"))/\(string(items[i], "name"))")
                for key in ["input", "expected"] { let source = file(items[i], key), destination = folder.appendingPathComponent((key == "input" ? string(items[i], "name") : "expected") + "." + source.pathExtension); try tools.copy(source, destination); items[i][key] = destination.path }
            }
            if ["--all", "--pipeline"].contains(mode) {
                var pipeline = pipelineCases(run)
                for i in pipeline.indices {
                    let folder = run.appendingPathComponent("fixtures/pipeline/\(string(pipeline[i], "stage"))"), old = file(pipeline[i], "expected"), expected = folder.appendingPathComponent("expected." + old.pathExtension)
                    try tools.copy(old, expected); pipeline[i]["expected"] = expected.path
                    if string(pipeline[i], "stage") == "transcribe" { let source = file(pipeline[i], "input"), dest = folder.appendingPathComponent(source.lastPathComponent); try tools.copy(source, dest); pipeline[i]["input"] = dest.path }
                }
                items += pipeline
            }
            try tools.json(run.appendingPathComponent("manifest.json"), items)
            metadata["fixture_hashes"] = try tools.hashes(items.flatMap { [file($0, "input"), file($0, "expected")] }.filter { tools.fm.fileExists(atPath: $0.path) }.uniquedURLs())
            let source = ["Sources/CaptainsLogCore", "Sources/cl", "scripts/Sources/Tools"].flatMap { tools.files(tools.path($0)).filter { $0.pathExtension == "swift" } } + [tools.path("Package.resolved"), tools.path("scripts/Package.swift"), tools.path("scripts/Package.resolved"), tools.path("scripts/tooling.swift")]
            metadata["source_hashes"] = try tools.hashes(source); metadata["prompt_hashes"] = try tools.hashes(tools.files(tools.path("prompts")).filter { $0.pathExtension == "md" }); metadata["status"] = "running"
            try tools.json(run.appendingPathComponent("metadata.json"), metadata); print("Run: \(run.path) (\(items.count) cases)")
            try tools.run(["swift", "build", "--product", "cl"], log: run.appendingPathComponent("build.log"))
            let cl = try tools.capture(["swift", "build", "--show-bin-path"]) + "/cl"
            metadata["binary_sha256"] = try tools.hash(tools.path(cl)); metadata["swift_version"] = try tools.capture(["swift", "--version"])
            let runtime = try tools.capture(["otool", "-L", cl]); metadata["runtime"] = runtime
            let libraries = try runtime.split(separator: "\n").dropFirst().compactMap { line -> URL? in
                let name = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " (")[0]
                guard name.hasPrefix("@rpath/llama.framework/") else { return nil }
                let resolved = tools.path(cl).deletingLastPathComponent().appendingPathComponent(String(name.dropFirst(7)))
                try tools.require(tools.fm.fileExists(atPath: resolved.path), "Pinned runtime not found beside CLI: \(resolved.path)"); return resolved
            }
            metadata["runtime_manifest_sha256"] = try tools.hash(tools.path("Package.swift")); metadata["runtime_hashes"] = try tools.hashes(libraries)
            try tools.json(run.appendingPathComponent("metadata.json"), metadata)
            if items.contains(where: { string($0, "stage") == "enrich" }) { try tools.run([CommandLine.arguments[0], "test-enrich-eval"], log: run.appendingPathComponent("enrich-checks.log"), environment: ["CAPTAINS_LOG_EVAL_CL": cl]) }
            if ["--all", "--pipeline"].contains(mode) { try tools.run([CommandLine.arguments[0], "eval-pipeline", run.path, cl], log: run.appendingPathComponent("pipeline-checks.log")) }
            for item in items where string(item, "stage") == "transcribe" && string(item, "scope") != "pipeline" { try tools.run([cl, "transcribe", string(item, "input"), "--output", string(item, "output")], log: run.appendingPathComponent("transcribe-\(string(item, "name")).log")) }
            let text = items.filter { string($0, "stage") != "transcribe" && string($0, "scope") != "pipeline" }
            if !text.isEmpty { try tools.json(run.appendingPathComponent("batch.json"), text); try tools.run([cl, "eval-batch", "--manifest", run.appendingPathComponent("batch.json").path], log: run.appendingPathComponent("batch.log")) }
            metadata["status"] = "generated"
        } catch { metadata["status"] = "failed"; metadata["error"] = String(describing: error); FileHandle.standardError.write(Data(("\(error)\n").utf8)) }
        try refresh(run, &items); try recordPipeline(run, &items, &metadata); try tools.json(run.appendingPathComponent("manifest.json"), items)
        let valid = try evidence(run, items, baseline)
        if metadata["status"] as? String == "generated" { metadata["status"] = valid ? "passed-mechanical-checks" : "failed-validation" }
        metadata["elapsed_seconds"] = ProcessInfo.processInfo.systemUptime - started; try tools.json(run.appendingPathComponent("metadata.json"), metadata)
        try tools.require(metadata["status"] as? String == "passed-mechanical-checks", "Evaluation failed; see \(run.path)")
    }
}
private extension Array where Element == URL { func uniquedURLs() -> [URL] { Array(Set(self)).sorted { $0.path < $1.path } } }
extension Tools {
    func evals(_ args: [String]) throws {
        let evaluator = Evaluator(self)
        do { try evaluator.main(args) }
        catch { throw ToolFailure("Evaluation error: \(error)", status: evaluator.errorStatus) }
    }
}

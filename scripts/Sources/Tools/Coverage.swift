import Foundation

extension Tools {
    func testCoverage(_ args: [String]) throws {
        let coverage = path(".build/coverage"), profile = coverage.appendingPathComponent("run-tests.profdata")
        try mkdir(coverage)
        for file in files(coverage) where file.pathExtension == "profraw" || file == profile || file.lastPathComponent == "coverage.json" {
            try fm.removeItem(at: file)
        }
        let instrumentation = ["-Xswiftc", "-profile-generate", "-Xswiftc", "-profile-coverage-mapping"]
        try run(["swift", "build"] + instrumentation + ["--product", "run-tests"])
        try run(["swift", "build"] + instrumentation + ["--product", "cl"])
        let bin = try capture(["swift", "build", "--show-bin-path"])
        try run([bin + "/run-tests"], environment: ["LLVM_PROFILE_FILE": coverage.appendingPathComponent("run-tests-%p.profraw").path])

        let temp = try temporary("captainslog-cli-tests.")
        defer { try? fm.removeItem(at: temp) }
        func local(_ value: String) -> URL { temp.appendingPathComponent(value) }
        for directory in ["data/logs", "data/.pipeline/01-transcribed", "empty-data"] { try mkdir(local(directory)) }
        try json(local("config.json"), ["schemaVersion": 1, "dataDir": local("data").path])
        for (source, destination) in [
            ("eval/cleanup/input/captains-log-nlm-llm.md", "input.md"),
            ("eval/transcribe/expected/durins-volk.md", "data/.pipeline/01-transcribed/2025-01-14-0830.md"),
            ("eval/filename/input/01_single_topic.md", "filename-input.md"),
            ("eval/enrich/input/01_work_week.md", "enrich-input.md"),
        ] { try copy(path(source), local(destination)) }
        let cliEnvironment = ["CAPTAINS_LOG_CONFIG_PATH": local("config.json").path,
                              "LLVM_PROFILE_FILE": coverage.appendingPathComponent("cl-%p.profraw").path]
        @discardableResult func cli(_ arguments: [String], failure: Bool = false, log: String? = nil) throws -> CommandResult {
            try run([bin + "/cl"] + arguments, quiet: true, allowFailure: failure,
                    log: log.map(local), environment: cliEnvironment)
        }
        func contains(_ output: String, _ fragments: [String], _ message: String) throws {
            var rest = output[...]
            for fragment in fragments {
                guard let range = rest.range(of: fragment) else { throw ToolFailure(message + "\n" + output) }
                rest = rest[range.upperBound...]
            }
        }
        func fails(_ arguments: [String], log: String, diagnostic: String, regex: Bool = false) throws {
            let result = try cli(arguments, failure: true, log: log)
            try require(result.status != 0, "CLI accepted invalid arguments: " + arguments.joined(separator: " "))
            try require(regex ? match(diagnostic, result.output) != nil : result.output.contains(diagnostic),
                        "CLI failed without expected diagnostic: " + diagnostic + "\n" + result.output)
        }
        try contains(cli(["ping"]).output, ["captains log core"], "CLI ping returned unexpected output.")
        try contains(cli(["--help"]).output, ["SUBCOMMANDS:", "pipeline", "search"], "CLI help omitted expected commands.")
        for command in ["ping", "record", "warm", "transcribe", "cleanup", "categorize", "filename", "enrich", "pipeline", "resume", "list", "search-index", "search", "config"] {
            try contains(cli([command, "--help"]).output, ["USAGE:", "OPTIONS:"], "CLI \(command) help omitted usage or options.")
        }
        try contains(cli(["config", "set", "--help"]).output, ["USAGE:", "<key>", "<value>"], "CLI config set help omitted key/value arguments.")
        try contains(cli(["config", "show", "--help"]).output, ["USAGE:"], "CLI config show help omitted usage.")
        for command in ["transcribe", "cleanup", "categorize", "filename", "enrich", "search"] {
            try fails([command], log: command + "-missing-args.txt", diagnostic: "USAGE:|Missing|missing|requires", regex: true)
        }
        for command in ["cleanup", "filename", "categorize", "enrich"] {
            var arguments = [command, "--input", local("missing-eval-input.md").path]
            if command == "categorize" { arguments += ["--output", local("category.json").path] }
            try fails(arguments + ["--print-prompt"], log: command + "-missing-file.txt", diagnostic: "missing-eval-input.md")
        }
        try fails(["pipeline", "--input", local("missing-eval-audio.m4a").path, "--data-dir", local("pipeline").path],
                  log: "pipeline-missing-audio.txt", diagnostic: "missing-eval-audio.m4a")
        print("CLI help, required-argument, and missing-input checks passed.")
        for duration in ["0", "-1"] {
            for command in ["record", "pipeline"] {
                let destination = command == "record" ? ["--output", local("should-not-record.m4a").path]
                    : ["--data-dir", local("duration-pipeline").path]
                try fails([command, "--duration=" + duration] + destination,
                          log: command + "-duration-" + duration + ".txt", diagnostic: "--duration must be greater than zero")
            }
        }
        try fails(["resume", "eval-fixture", "--data-dir", local("empty-data").path, "--from-stage", "unknown"],
                  log: "invalid-resume-stage.txt", diagnostic: "--from-stage must be one of")
        let settings = [("dataDir", local("data").path), ("whisperModel", "synthetic/whisper-model"),
                        ("whisperModelFolder", local("models/whisper").path), ("qwenModelId", "synthetic/eval-model"),
                        ("qwenModelFolder", local("models/qwen").path)]
        for (key, value) in settings { try cli(["config", "set", key, value]) }
        try contains(cli(["config", "show"]).output,
                     ["dataDir:             " + local("data").path, "whisperModel:        synthetic/whisper-model",
                      "whisperModelFolder:  " + local("models/whisper").path, "qwenModelId:         synthetic/eval-model",
                      "qwenModelFolder:     " + local("models/qwen").path], "CLI config show did not return saved isolated values.")
        try cli(["config", "set", "qwenModelFolder", "unset"])
        try contains(cli(["config", "show"]).output, ["qwenModelFolder:     (unset — local GGUF required)"], "CLI config unset did not clear Qwen folder.")
        try write(local("data/audio/2025-01-20-0900.m4a"), "synthetic audio marker")
        for day in [13, 12, 11, 10, 9] {
            let stem = String(format: "2025-01-%02d-0900", day)
            try write(local("data/.pipeline/01-transcribed/" + stem + ".md"), "synthetic transcript")
            if day <= 12 { try write(local("data/.pipeline/02-logs/" + stem + ".md"), "synthetic cleaned text") }
            if day <= 11 { try write(local("data/.pipeline/03-category/" + stem + ".json"), "{\"sourceStem\":\"\(stem)\",\"category\":\"personal\"}") }
            if day <= 10 {
                let slug = String(format: "2025-01-%02d-", day) + (day == 10 ? "enrich-me" : "finished")
                try write(local("data/.pipeline/04-rename/" + stem + ".slug.txt"), slug)
                try write(local("data/.pipeline/04-rename/" + slug + ".md"), "synthetic renamed text")
                if day == 9 { try write(local("data/logs/personal/" + slug + ".md"), "synthetic enriched text") }
            }
        }
        let list = try cli(["list", "--data-dir", local("data").path]).output
        for expected in ["[transcribing]  2025-01-20-0900", "[cleaning]  2025-01-14-0830", "[categorizing]  2025-01-12-0900",
                         "[naming]  2025-01-11-0900", "[enriching]  2025-01-10-enrich-me", "[done]  2025-01-09-finished"] {
            try require(list.contains(expected), "CLI list omitted stage entry: " + expected + "\n" + list)
        }
        for stem in ["2025-01-20-0900", "2025-01-14-0830", "2025-01-13-0900", "2025-01-12-0900", "2025-01-11-0900", "2025-01-10-0900", "2025-01-09-0900"] {
            try require(list.components(separatedBy: "(stem: " + stem + ")").count - 1 == 1, "CLI list should show stem exactly once: " + stem)
        }
        try contains(cli(["resume", "--data-dir", local("empty-data").path]).output, ["No pending entries to resume."], "CLI resume did not report an empty queue.")
        try contains(cli(["cleanup", "--input", local("input.md").path, "--print-prompt"]).output, ["<transcript>", "Obsidian"], "Cleanup prompt omitted transcript.")
        try contains(cli(["filename", "--input", local("filename-input.md").path, "--date", "2025-01-14", "--print-prompt"]).output,
                     ["2025-01-14", "<log_entry>"], "Filename prompt omitted date/log entry.")
        for input in files(path("eval/categorize/input")) where input.pathExtension == "md" {
            let prompt = try cli(["categorize", "--input", input.path, "--output", local(input.deletingPathExtension().lastPathComponent + ".json").path, "--print-prompt"]).output
            try contains(prompt, ["- personal:", "- professional:", "- side_project:", "<log_entry>"], "Categorize prompt omitted rubric: " + input.lastPathComponent)
            var fixture = try read(input)
            while fixture.hasSuffix("\n") { fixture.removeLast() }
            try require(prompt.contains(fixture), "Categorize prompt omitted fixture content: " + input.lastPathComponent)
        }
        try contains(cli(["enrich", "--input", local("enrich-input.md").path, "--date", "2025-01-14", "--recording-time", "08:30", "--print-prompt"]).output,
                     ["date: \"2025-01-14\"", "recording_time: \"08:30\"", "<log_entry>"], "Enrich prompt omitted supplied metadata.")
        try fails(["search", "--limit", "0", "synthetic-query"], log: "invalid-limit.txt", diagnostic: "--limit must be greater than zero")
        try fails(["config", "set", "unknown-key", "value"], log: "invalid-config-key.txt", diagnostic: "Unknown key: unknown-key")

        let rawProfiles = files(coverage).filter { $0.pathExtension == "profraw" }
        try require(!rawProfiles.isEmpty, "No coverage profiles were produced.")
        try run(["xcrun", "llvm-profdata", "merge", "-sparse"] + rawProfiles.map(\.path) + ["-o", profile.path])
        let sources = ["Sources/CaptainsLogCore", "Sources/CaptainsLog", "Sources/cl", "Sources/CaptainsLogApp"]
            .flatMap { files(path($0), recursive: true) }.filter { $0.pathExtension == "swift" }.map { $0.path.replacingOccurrences(of: root.path + "/", with: "") }
        let objects = [bin + "/run-tests", "-object", bin + "/cl", "-instr-profile=" + profile.path]
        print(try capture(["xcrun", "llvm-cov", "report"] + objects + sources))
        try write(coverage.appendingPathComponent("coverage.json"), capture(["xcrun", "llvm-cov", "export"] + objects + sources) + "\n")
        let exclusions: Set<String> = [
            "Sources/CaptainsLog/FieldNotesContentView.swift", "Sources/CaptainsLog/Theme.swift",
            "Sources/CaptainsLog/FieldNotesTheme.swift", "Sources/CaptainsLog/DesignFixtures.swift", "Sources/CaptainsLogCore/Recorder.swift",
            "Sources/CaptainsLogCore/Transcriber.swift", "Sources/CaptainsLogCore/LLM.swift", "Sources/CaptainsLogCore/Embeddings.swift",
        ]
        let report = try capture(["xcrun", "llvm-cov", "report"] + objects + sources.filter { !exclusions.contains($0) })
        print("\nDeterministic production coverage scope (excluding SwiftUI, fixtures, and native adapters):\n" + report)
        let total = report.components(separatedBy: "\n").first { $0.hasPrefix("TOTAL") } ?? ""
        let percentages = total.split(whereSeparator: \.isWhitespace).filter { $0.hasSuffix("%") }
        try require(percentages.count >= 3, "Coverage report omitted total line coverage.")
        let actual = Double(percentages[2].dropLast()) ?? -1
        try require(actual >= 80, "Deterministic production line coverage \(actual)% is below the 80% minimum.")
        print("Deterministic production line coverage: \(actual)% (minimum 80%).")
        print("Full production coverage report: " + coverage.appendingPathComponent("coverage.json").path)
    }
}

import Foundation
import Darwin

extension Tools {
    func nonempty(_ url: URL) -> Bool { ((try? fm.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0) > 0 }
    func evalPipeline(_ args: [String]) throws {
        try require(args.count == 2, "Usage: eval-pipeline RUN_DIR CL", status: 2)
        let dir = path(args[0]), cl = args[1], data = dir.appendingPathComponent("data")
        try run([cl, "pipeline", "--input", "eval/transcribe/audio/2025-01-14 side project.m4a", "--data-dir", data.path], log: dir.appendingPathComponent("pipeline.log"))
        for relative in ["01-transcribed/2025-01-14 side project.md", "02-logs/2025-01-14 side project.md", "03-category/2025-01-14 side project.json"] {
            try require(nonempty(data.appendingPathComponent(".pipeline/" + relative)), "Pipeline artifact assertion failed: \(relative)")
        }
        let category = try json(data.appendingPathComponent(".pipeline/03-category/2025-01-14 side project.json")) as? [String: Any]
        try require(category?["category"] as? String == "side_project", "Unexpected pipeline category")
        let marker = data.appendingPathComponent(".pipeline/04-rename/2025-01-14 side project.slug.txt")
        try require(nonempty(marker), "Missing slug marker")
        let slug = try read(marker).trimmingCharacters(in: .whitespacesAndNewlines)
        let enriched = data.appendingPathComponent("logs/side-project/\(slug).md")
        try require(nonempty(data.appendingPathComponent(".pipeline/04-rename/\(slug).md")) && nonempty(enriched), "Missing renamed/enriched artifacts for \(slug)")
        func snapshot() throws -> String { try files(data, recursive: true).map { try hash($0) + "  " + $0.path }.sorted().joined(separator: "\n") + "\n" }
        let before = try snapshot(); try write(dir.appendingPathComponent("before-resume.sha256"), before)
        try run([cl, "resume", "--data-dir", data.path], log: dir.appendingPathComponent("resume.log"))
        let after = try snapshot(); try write(dir.appendingPathComponent("after-resume.sha256"), after)
        try require(before == after, "Resume changed completed pipeline artifacts")
        try run([cl, "search-index", "--data-dir", data.path], log: dir.appendingPathComponent("search-index.log"))
        let search = try run([cl, "search", "Star Trek captain log side project", "--data-dir", data.path, "--limit", "5"], log: dir.appendingPathComponent("search.log"))
        try require(search.output.contains(enriched.path), "Search did not return pipeline entry: \(enriched.path)")
        print("Pipeline artifact, category, resume immutability, and search readback assertions passed.")
    }
    func testUpdates() throws {
        let dir = try temporary("update-verification-", in: path("tmp")); try isolated(dir)
        environment["CAPTAINS_LOG_UPDATE_FIXTURE_STATE"] = dir.appendingPathComponent("installed").path
        environment["CAPTAINS_LOG_UPDATE_FIXTURE_LOG"] = dir.appendingPathComponent("commands").path
        try run(["swift", "build", "--product", "cl"])
        let cl = try capture(["swift", "build", "--show-bin-path"]) + "/cl", fixture = path("eval/update/input/brew-fixture.sh").path
        func update(_ name: String, _ extra: [String]) throws -> CommandResult { try run([cl, "update"] + extra + ["--brew-path", fixture], log: dir.appendingPathComponent(name + ".log")) }
        let check = try update("check", ["--check"])
        try require(!exists(environment["CAPTAINS_LOG_UPDATE_FIXTURE_STATE"]!) && check.output.contains("Update available"), "Update check mutated installation or failed to report availability")
        _ = try update("install", [])
        try require(exists(environment["CAPTAINS_LOG_UPDATE_FIXTURE_STATE"]!), "Install fixture state missing")
        try require(try update("current", ["--check"]).output.contains("up to date"), "Installed version not detected")
        let upgrades = try read(dir.appendingPathComponent("commands")).split(separator: "\n").filter { $0.hasPrefix("upgrade ") }
        try require(upgrades == ["upgrade --cask --no-quit --require-sha vnglst/captainslog/captainslog"], "Expected one exact verified cask upgrade")
        let failure = try run([cl, "update", "--check", "--brew-path", fixture], allowFailure: true, log: dir.appendingPathComponent("failure.log"), environment: ["CAPTAINS_LOG_UPDATE_FIXTURE_FAIL": "update"])
        try require(failure.status != 0 && failure.output.contains("Synthetic network failure"), "Synthetic update failure was not propagated")
        for key in ["automaticUpdates", "automaticUpdateChecks"] { try run([cl, "config", "set", key, "false"]) }
        let config = try json(dir.appendingPathComponent("config.json")) as? [String: Any]
        try require(config?["automaticUpdates"] as? Bool == false && config?["automaticUpdateChecks"] as? Bool == false, "Update preferences not saved")
        let invalid = try run([cl, "config", "set", "automaticUpdates", "invalid"], allowFailure: true, log: dir.appendingPathComponent("invalid-preference.log"))
        try require(invalid.status != 0, "Invalid Boolean preference was accepted")
        for key in ["automaticUpdates", "automaticUpdateChecks"] { try run([cl, "config", "set", key, "unset"]) }
        let show = try run([cl, "config", "show"], log: dir.appendingPathComponent("config.log"))
        try require(show.output.contains("automaticUpdates: true") && show.output.contains("automaticUpdateChecks: true"), "Unset preferences did not restore defaults")
        print("Update CLI fixture checks passed. Logs: \(dir.path)")
    }
    func testModelSmoke() throws {
        let keys = ["CAPTAINSLOG_WHISPER_MODEL_ID", "CAPTAINSLOG_WHISPER_MODEL_FOLDER", "CAPTAINSLOG_QWEN_MODEL_ID", "CAPTAINSLOG_QWEN_MODEL_FOLDER"]
        for key in keys { try require(!(environment[key] ?? "").isEmpty, "Set \(key) to an already-installed model before running this opt-in smoke.", status: 2) }
        for key in [keys[1], keys[3]] { var directory: ObjCBool = false; try require(fm.fileExists(atPath: environment[key]!, isDirectory: &directory) && directory.boolValue, "Model folder does not exist: \(environment[key]!)", status: 2) }
        try require(files(path(environment[keys[3]]!)).contains { $0.pathExtension == "gguf" }, "Qwen model folder must contain an installed .gguf file.", status: 2)
        let fixture = path("eval/transcribe/audio/durins-volk.m4a")
        try require(nonempty(fixture), "Synthetic transcription fixture missing", status: 2)
        let dir = try temporary("captainslog-model-smoke-"); defer { try? fm.removeItem(at: dir) }; try isolated(dir)
        for (key, value) in [("whisperModel", environment[keys[0]]!), ("whisperModelFolder", environment[keys[1]]!), ("qwenModelId", environment[keys[2]]!), ("qwenModelFolder", environment[keys[3]]!)] { try run(["swift", "run", "cl", "config", "set", key, value], quiet: true) }
        print("Loading and warming the configured Qwen model...")
        try run(["swift", "run", "cl", "warm", "--model", environment[keys[2]]!])
        print("Transcribing the synthetic eval fixture with the configured Whisper model...")
        let output = dir.appendingPathComponent("transcript.md")
        try run(["swift", "run", "cl", "transcribe", fixture.path, "--output", output.path, "--model", environment[keys[0]]!, "--language", "nl"])
        try require(nonempty(output), "Whisper smoke returned without a non-empty transcript")
        print("Installed-model smoke passed. Models loaded sequentially; outputs and config were temporary.")
    }
    func testRecorder() throws {
        try require(try capture(["uname", "-s"]) == "Darwin", "Recorder hardware smoke requires macOS and Core Audio.", status: 2)
        try require(isatty(STDIN_FILENO) == 1, "Run this smoke test interactively; it records three seconds after confirmation.", status: 2)
        try require(fm.isExecutableFile(atPath: "/usr/bin/afinfo"), "The macOS afinfo utility is required.", status: 2)
        print("This will record three seconds from the default microphone to a temporary file.")
        print("The temporary file and isolated config will be removed when the script exits.")
        print("Continue? [y/N] ", terminator: ""); fflush(stdout)
        guard ["y", "yes"].contains((readLine() ?? "").lowercased()) else { print("Recorder smoke cancelled."); return }
        let dir = try temporary("captainslog-recorder-smoke-"); defer { try? fm.removeItem(at: dir) }; try isolated(dir)
        let output = dir.appendingPathComponent("recording.m4a")
        try run(["swift", "run", "cl", "record", "--duration", "3", "--output", output.path])
        try require(nonempty(output), "Recorder returned without a non-empty audio file")
        try run(["afinfo", output.path], quiet: true)
        print("Recorder hardware smoke passed: audio was captured and the M4A file is readable.")
    }
    func testUI(_ args: [String]) throws {
        let fixture = args.first ?? "eval"
        let fixtures = ["onboarding", "eval", "eval-settings", "eval-empty", "eval-processing", "eval-paused", "eval-failed", "eval-search-results", "eval-search-empty", "eval-search-error", "eval-search-preparing", "eval-searching", "eval-indexing", "eval-model-downloading", "eval-model-error", "eval-recording", "eval-recording-paused"]
        try require(fixtures.contains(fixture), "Unknown UI fixture: \(fixture)", status: 2)
        try require(try capture(["uname", "-s"]) == "Darwin", "The native UI check requires macOS; Xcode IDE is not required.", status: 2)
        if environment["CAPTAINSLOG_UI_SKIP_BUILD"] != "1" { try run(["swift", "build", "--product", "CaptainsLogApp"]) }
        let bin = path(try capture(["swift", "build", "--show-bin-path"]))
        let dir = try temporary("captainslog-ui-eval-"); try isolated(dir)
        let data = dir.appendingPathComponent("data"), app = dir.appendingPathComponent("CaptainsLogUITest.app"), identifier = "local.captainslog.ui-eval." + UUID().uuidString.lowercased()
        func source(_ relative: String) throws -> String { try read(path("eval/" + relative)) }
        func completed(_ stem: String, _ slug: String, _ category: String, _ transcript: String, _ cleaned: String, _ final: String) throws {
            try copy(path("eval/" + transcript), data.appendingPathComponent(".pipeline/01-transcribed/\(stem).md"))
            try write(data.appendingPathComponent(".pipeline/02-logs/\(stem).md"), cleaned)
            try json(data.appendingPathComponent(".pipeline/03-category/\(stem).json"), ["sourceStem": stem, "category": category])
            try write(data.appendingPathComponent(".pipeline/04-rename/\(stem).slug.txt"), slug)
            try write(data.appendingPathComponent(".pipeline/04-rename/\(slug).md"), cleaned)
            try write(data.appendingPathComponent("logs/\(category.replacingOccurrences(of: "_", with: "-"))/\(slug).md"), final)
        }
        let slug = try source("filename/expected/2025-01-14 side project.md").trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ".md", with: "")
        let cleaned = try source("cleanup/expected/2025-01-14 side project.md")
        try completed("2025-01-14-0730", slug, "side_project", "transcribe/expected/2025-01-14 side project.md", cleaned, source("enrich/expected/2025-01-14 side project.md") + cleaned)
        let work = try source("enrich/input/01_work_week.md")
        try completed("2025-01-15-1200", "2025-01-15-work-week-review", "professional", "enrich/input/01_work_week.md", work, source("enrich/expected/01_work_week.md") + work)
        try copy(path("eval/cleanup/input/book-reference.md"), data.appendingPathComponent(".pipeline/01-transcribed/2025-01-16-0900.md"))
        try mkdir(app.appendingPathComponent("Contents/MacOS")); try mkdir(app.appendingPathComponent("Contents/Resources"))
        let executable = app.appendingPathComponent("Contents/MacOS/CaptainsLogUITest")
        try copy(bin.appendingPathComponent("CaptainsLogApp"), executable)
        try bundleRuntime([bin.path, app.path, executable.path])
        let plist: [String: String] = ["CFBundleExecutable": "CaptainsLogUITest", "CFBundleIdentifier": identifier, "CFBundleName": "CaptainsLog UI Eval", "CFBundlePackageType": "APPL", "LSMinimumSystemVersion": "26.0"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: app.appendingPathComponent("Contents/Info.plist"))
        try run(["codesign", "--force", "--deep", "--sign", "-", app.path]); try run(["codesign", "--verify", "--deep", "--strict", app.path])
        print("Isolated UI app: \(app.path)\nIsolated config: \(dir.path)/config.json\nIsolated eval data: \(data.path)\nFixture state: \(fixture)\nBundle identifier: \(identifier)")
        print("The app launch skips model download and audio discovery. Do not activate processing or recording controls; those use real inference or audio hardware.")
        var open = ["open", "--env", "CAPTAINS_LOG_CONFIG_PATH=\(dir.path)/config.json", "--env", "CAPTAINSLOG_UI_FIXTURE=\(fixture)"]
        if fixture == "onboarding" { open += ["--env", "CAPTAINSLOG_DEMO_MODE=1"] }
        try run(open + ["-n", app.path])
    }
}

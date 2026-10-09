import Foundation

extension Tools {
    func testReleaseTooling() throws {
        let dir = try temporary("captainslog-release-tests-"); defer { try? fm.removeItem(at: dir) }
        let tool = dir.appendingPathComponent("release-tool"), source = dir.appendingPathComponent("source"), bin = dir.appendingPathComponent("bin"), origin = dir.appendingPathComponent("origin.git")
        try run(["swiftc", "scripts/release.swift", "-o", tool.path]); try run([tool.path, "test"])
        try run(["git", "init", "-q", "--bare", origin.path]); try mkdir(source); try mkdir(bin)
        let fixture = Tools(root: source, environment: environment)
        func git(_ args: String...) throws -> String { try fixture.run(["git"] + args, quiet: true).output.trimmingCharacters(in: .whitespacesAndNewlines) }
        func commit(_ message: String = "chore(test): synthetic fixture change") throws { _ = try git("add", "."); _ = try git("commit", "--allow-empty", "-qm", message) }
        func release(_ args: [String], _ name: String = "release") throws -> String { try fixture.run([tool.path] + args, quiet: true, log: dir.appendingPathComponent(name + ".log")).output }
        func fail(_ args: [String]) throws { let result = try fixture.run([tool.path] + args, quiet: true, allowFailure: true, log: dir.appendingPathComponent("failure.log")); try require(result.status != 0, "Expected release failure: \(args.joined(separator: " "))") }
        _ = try git("init", "-q", "-b", "main")
        for (key, value) in [("user.name", "Release fixture"), ("user.email", "fixture@example.invalid"), ("commit.gpgsign", "false"), ("tag.gpgsign", "false")] { _ = try git("config", key, value) }
        try fixture.write(source.appendingPathComponent("VERSION"), "0.1.2\n")
        try fixture.write(source.appendingPathComponent("CHANGELOG.md"), "# Changelog\n\n## [Unreleased]\n\n- Synthetic release fix.\n\n## [0.1.2] - 2026-10-01\n\n- Previous synthetic feature.\n\n[Unreleased]: https://github.com/vnglst/CaptainsLog/compare/v0.1.2...HEAD\n")
        try fixture.write(source.appendingPathComponent("Casks/captainslog.rb"), "  version \"0.1.2\"\n  sha256 \"" + String(repeating: "0", count: 64) + "\"\n")
        try commit(); _ = try git("tag", "v0.1.2")
        try require(try release(["--dry-run"], "no-release").contains("no releasable changes"), "Maintenance triggered automatic release")
        try commit("fix(test): repair synthetic fixture")
        try require(try release(["--dry-run"], "auto-preview").contains("## [0.1.3]"), "Fix did not select patch")
        try commit("chore(test): change synthetic config\n\nBREAKING CHANGE: remove old fixture key")
        try require(try release(["--dry-run"], "breaking-preview").contains("## [0.2.0]"), "Breaking 0.x change did not select minor")
        try commit("feat(test): add synthetic capability")
        try require(try release(["auto", "--dry-run"], "auto-preview").contains("## [0.2.0]"), "Feature did not select minor")
        _ = try git("tag", "v9.0.0"); try fail(["--dry-run"]); _ = try git("tag", "-d", "v9.0.0")
        let base = try git("rev-parse", "HEAD")
        _ = try git("remote", "add", "origin", origin.path); _ = try git("push", "-q", "origin", "main")
        try require(try release(["patch", "--dry-run"], "preview").contains("## [0.1.3]"), "Manual patch preview wrong")
        try require(try git("rev-parse", "HEAD") == base && git("status", "--porcelain").isEmpty && git("tag", "--list") == "v0.1.2", "Preview mutated repository")
        try fixture.write(source.appendingPathComponent("README.md"), "Uncommitted synthetic documentation\n"); try fail(["patch"]); try commit()
        try fail(["check", base, "HEAD"])
        try fixture.write(source.appendingPathComponent("CHANGELOG.md"), fixture.read(source.appendingPathComponent("CHANGELOG.md")) + "\n"); try commit()
        _ = try release(["check", base, "HEAD"]); _ = try release(["check", String(repeating: "0", count: 40), "HEAD"]); _ = try release(["check", "HEAD", "HEAD"])
        _ = try git("switch", "-qc", "fixture-branch"); try fail(["patch"]); _ = try git("switch", "-q", "main")
        _ = try git("tag", "v0.1.3"); try fail(["patch"]); _ = try git("tag", "-d", "v0.1.3")
        // Reject any build/test invocation during local preparation; Git publication uses a local bare fixture.
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        try fm.createSymbolicLink(at: bin.appendingPathComponent("make"), withDestinationURL: executable)
        fixture.environment["PATH"] = bin.path + ":" + (environment["PATH"] ?? "")
        fixture.environment["CAPTAINS_LOG_TOOL_FIXTURE_KIND"] = "release"
        fixture.environment["RELEASE_FIXTURE_CHECK_LOG"] = dir.appendingPathComponent("checks.log").path
        let before = try git("rev-parse", "HEAD")
        fixture.environment["RELEASE_FIXTURE_FAIL"] = "1"
        try write(dir.appendingPathComponent("checks.log"), "")
        let preparationStarted = Date()
        _ = try release(["--publish"], "publish")
        print(String(format: "Local release preparation/publication fixture: %.2fs", Date().timeIntervalSince(preparationStarted)))
        try require(try fixture.read(source.appendingPathComponent("VERSION")).trimmingCharacters(in: .whitespacesAndNewlines) == "0.2.0", "Publication version wrong")
        let head = try git("rev-parse", "HEAD")
        try require(try git("status", "--porcelain").isEmpty && git("rev-parse", "v0.2.0^{}") == head && git("rev-parse", "origin/main") == head && git("ls-remote", "origin", "refs/tags/v0.2.0").contains("refs/tags/v0.2.0"), "Local atomic publication mismatch")
        _ = try release(["check", before, "HEAD"])
        try require(try git("log", "-1", "--format=%s") == "chore(release): CaptainsLog 0.2.0", "Release commit subject wrong")
        try require(try release(["--dry-run"], "post-release").contains("no releasable changes"), "Release commit triggered next release")
        try require(try read(dir.appendingPathComponent("checks.log")).isEmpty, "Local release preparation must not invoke builds or test suites")
        let caskBase = try git("rev-parse", "HEAD")
        _ = try release(["cask", "0.2.0", String(repeating: "0", count: 63) + "1"]); try commit(); _ = try release(["check", caskBase, "HEAD"])
        try require(try release(["--dry-run"], "maintenance-preview").contains("no releasable changes"), "Generated cask commit triggered release")
        let manualBase = try git("rev-parse", "HEAD")
        let cask = source.appendingPathComponent("Casks/captainslog.rb")
        try fixture.write(cask, fixture.read(cask) + "# Manual cask change\n"); try commit(); try fail(["check", manualBase, "HEAD"])
        print("Release Git/CLI fixtures passed (no build/test invocations; local atomic publication verified).")
    }
    func releaseFixture(_ args: [String]) throws {
        try require(!(environment["CAPTAINS_LOG_CONFIG_PATH"] ?? "").isEmpty && !(environment["CAPTAINS_LOG_DATA_DIR"] ?? "").isEmpty, "Missing isolated release config/data")
        let log = path(environment["RELEASE_FIXTURE_CHECK_LOG"]!)
        let handle = try FileHandle(forWritingTo: log); defer { try? handle.close() }; try handle.seekToEnd(); try handle.write(contentsOf: Data(("make " + args.joined(separator: " ") + "\n").utf8))
        try require(environment["RELEASE_FIXTURE_FAIL"] != "1", "Synthetic check failure")
    }
}

#!/usr/bin/env swift
import Foundation

struct ReleaseError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw ReleaseError(message: message) }
}
func matches(_ text: String, _ pattern: String) -> Bool {
    text.range(of: pattern, options: .regularExpression) != nil
}
func read(_ path: String) throws -> String {
    try String(contentsOfFile: path, encoding: .utf8)
}
func write(_ text: String, _ path: String) throws {
    try text.write(toFile: path, atomically: true, encoding: .utf8)
}
@discardableResult
func run(_ arguments: [String], capture: Bool = false, environment: [String: String] = [:]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
    let pipe = Pipe()
    if capture { process.standardOutput = pipe }
    try process.run()
    let output = capture ? pipe.fileHandleForReading.readDataToEndOfFile() : Data()
    process.waitUntilExit()
    try require(process.terminationStatus == 0, "Command failed: \(arguments.joined(separator: " "))")
    return String(decoding: output, as: UTF8.self).trimmingCharacters(in: .newlines)
}
func git(_ arguments: String...) throws -> String {
    try run(["git"] + arguments, capture: true)
}
func versionParts(_ version: String) throws -> [Int] {
    try require(matches(version, "^[0-9]+\\.[0-9]+\\.[0-9]+$"), "Expected MAJOR.MINOR.PATCH")
    let parts = version.split(separator: ".").compactMap { Int($0) }
    try require(parts.count == 3, "Version numbers are too large")
    return parts
}
func nextVersion(_ current: String, _ bump: String) throws -> String {
    var parts = try versionParts(current)
    if let index = ["major": 0, "minor": 1, "patch": 2][bump] {
        try require(parts[index] < Int.max, "Version number is too large")
        parts[index] += 1
        for remaining in (index + 1)..<3 { parts[remaining] = 0 }
        return parts.map(String.init).joined(separator: ".")
    }
    let proposed = try versionParts(bump)
    try require(parts.lexicographicallyPrecedes(proposed), "New version must be greater than VERSION")
    return bump
}
// Conventional Commits determine only the bump; CHANGELOG.md remains the
// reviewed release notes. During 0.x, breaking changes advance the minor version.
func conventionalType(_ message: String) -> String? {
    let subject = message.components(separatedBy: "\n").first ?? ""
    guard matches(subject, "(?i)^[a-z]+(?:\\([^()\\r\\n]+\\))?!?: \\S.*$") else { return nil }
    return String(subject.prefix { $0 != "(" && $0 != "!" && $0 != ":" }).lowercased()
}
func inferredBump(_ messages: [String], current: String) throws -> String? {
    let parts = try versionParts(current)
    var rank = 0
    for message in messages {
        guard let type = conventionalType(message) else { continue }
        let subject = message.components(separatedBy: "\n")[0]
        let breaking = matches(subject, #"(?i)^[a-z]+(?:\([^()\r\n]+\))?!: \S"#) || matches(message, #"(?m)^BREAKING(?: CHANGE|-CHANGE): \S"#)
        if breaking { rank = max(rank, parts[0] == 0 ? 2 : 3) }
        else if type == "feat" { rank = max(rank, 2) }
        else if type == "fix" || type == "perf" { rank = max(rank, 1) }
    }
    return [1: "patch", 2: "minor", 3: "major"][rank]
}
func automaticBump(_ current: String) throws -> String? {
    let tags = try git("tag", "--merged", "HEAD", "--list", "v*", "--sort=-version:refname")
        .components(separatedBy: "\n").filter { matches($0, "^v[0-9]+\\.[0-9]+\\.[0-9]+$") }
    try require(tags.first == "v\(current)", "Latest reachable release tag must match VERSION (v\(current)); fetch tags or use an explicit bump")
    let range = "v\(current)..HEAD"
    let messages = try git("log", "--format=%B%x00", range).split(separator: "\0")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    for message in messages where conventionalType(message) == nil {
        let subject = message.components(separatedBy: "\n")[0]
        FileHandle.standardError.write(Data("Ignoring non-conventional commit for version selection: \(subject)\n".utf8))
    }
    let bump = try inferredBump(messages, current: current)
    print("Commits since v\(current): \(bump.map { "\($0) release" } ?? "no releasable changes")")
    return bump
}
func notes(_ content: String, _ version: String) throws -> String {
    _ = try versionParts(version)
    let lines = content.components(separatedBy: "\n")
    let headings = lines.indices.filter { lines[$0].hasPrefix("## [\(version)]") }
    try require(headings.count == 1, "Expected exactly one changelog section for \(version)")
    let start = headings[0]
    let prefix = "## [\(version)] - "
    let heading = lines[start]
    try require(heading.hasPrefix(prefix), "Expected ## [\(version)] - YYYY-MM-DD")
    let stamp = String(heading.dropFirst(prefix.count))
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    try require(matches(stamp, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$") && formatter.date(from: stamp) != nil,
                "Invalid release date")
    let end = lines.indices.dropFirst(start + 1).first {
        lines[$0].hasPrefix("## ") || matches(lines[$0], "^\\[[^]]+\\]:")
    } ?? lines.count
    let body = lines[(start + 1)..<end].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    try require(matches(body, "(?m)^- \\S"), "Release section has no change entries")
    return "\(heading)\n\n\(body)\n"
}
func prepareChangelog(_ content: String, current: String, version: String, date: String) throws -> String {
    var lines = content.components(separatedBy: "\n")
    let starts = lines.indices.filter { lines[$0] == "## [Unreleased]" }
    try require(starts.count == 1, "Expected exactly one Unreleased section")
    try require(!lines.contains(where: { $0.hasPrefix("## [\(version)]") }), "Release already exists")
    let start = starts[0] + 1
    let end = lines.indices.dropFirst(start).first { lines[$0].hasPrefix("## ") } ?? lines.count
    let entries = lines[start..<end].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    try require(matches(entries, "(?m)^- \\S"), "Unreleased must contain changes before releasing")
    let replacement = "\n## [\(version)] - \(date)\n\n\(entries)\n\n### Release\n\n- Publish the \(version) app/CLI archive and matching Homebrew cask version and checksum.\n"
    lines.replaceSubrange(start..<end, with: replacement.components(separatedBy: "\n"))
    let oldLink = "[Unreleased]: https://github.com/vnglst/CaptainsLog/compare/v\(current)...HEAD"
    try require(lines.filter { $0 == oldLink }.count == 1, "Unreleased comparison link must match VERSION")
    let link = lines.firstIndex(of: oldLink)!
    lines.replaceSubrange(link...link, with: [
        "[Unreleased]: https://github.com/vnglst/CaptainsLog/compare/v\(version)...HEAD",
        "[\(version)]: https://github.com/vnglst/CaptainsLog/compare/v\(current)...v\(version)"
    ])
    let result = lines.joined(separator: "\n")
    _ = try notes(result, version)
    return result
}
func checkRange(_ requestedBase: String, _ head: String) throws {
    let base = !requestedBase.isEmpty && requestedBase.allSatisfy { $0 == "0" }
        ? try git("hash-object", "-t", "tree", "/dev/null") : requestedBase
    let changed = Set(try git("diff", "--name-only", "-z", base, head).split(separator: "\0").map(String.init))
    if changed.isEmpty { return }
    if changed == ["Casks/captainslog.rb"] {
        let diff = try git("diff", "--no-ext-diff", "--no-color", "--unified=0", base, head, "--", "Casks/captainslog.rb")
        let edits = diff.components(separatedBy: "\n").filter {
            ($0.hasPrefix("+") || $0.hasPrefix("-")) && !$0.hasPrefix("+++") && !$0.hasPrefix("---")
        }.map { String($0.dropFirst()) }
        if !edits.isEmpty && edits.allSatisfy({ matches($0, "^  (version \"[0-9]+\\.[0-9]+\\.[0-9]+\"|sha256 \"[0-9a-f]{64}\")$") }) {
            let version = try git("show", "\(head):VERSION")
            _ = try notes(git("show", "\(head):CHANGELOG.md"), version)
            try require(try git("show", "\(head):Casks/captainslog.rb").contains("  version \"\(version)\""), "Cask version must match VERSION")
            return
        }
    }
    try require(changed.contains("CHANGELOG.md"), "Update CHANGELOG.md for these Git changes (including docs/tests)")
    try require(try git("show", "\(head):CHANGELOG.md").components(separatedBy: "\n").contains("## [Unreleased]"), "Keep an Unreleased section")
}
func updateCask(_ version: String, _ checksum: String) throws {
    _ = try versionParts(version)
    try require(matches(checksum, "^[0-9a-f]{64}$"), "Expected SHA-256 checksum")
    var lines = try read("Casks/captainslog.rb").components(separatedBy: "\n")
    for (key, value) in [("version", version), ("sha256", checksum)] {
        let indices = lines.indices.filter { lines[$0].hasPrefix("  \(key) \"") }
        try require(indices.count == 1, "Expected exactly one cask \(key)")
        lines[indices[0]] = "  \(key) \"\(value)\""
    }
    try write(lines.joined(separator: "\n"), "Casks/captainslog.rb")
}
func prepareRelease(_ arguments: [String]) throws {
    var arguments = arguments
    let requested = arguments.first.flatMap { $0.hasPrefix("--") ? nil : $0 } ?? "auto"
    if arguments.first == requested { arguments.removeFirst() }
    try require(arguments.count <= 1, "Use [auto|patch|minor|major|version] [--dry-run|--publish]")
    let option = arguments.first
    try require(option == nil || option == "--dry-run" || option == "--publish", "Unknown release option")
    try require(FileManager.default.changeCurrentDirectoryPath(git("rev-parse", "--show-toplevel")), "Cannot open repository")
    let current = try read("VERSION").trimmingCharacters(in: .whitespacesAndNewlines)
    let bump: String
    if requested == "auto" {
        if option != "--dry-run" {
            try require(try git("status", "--porcelain").isEmpty, "Commit or set aside working-tree changes before releasing")
            try require(try git("branch", "--show-current") == "main", "Prepare releases on main")
            try run(["git", "fetch", "origin", "main", "--tags"])
            try require(try git("rev-list", "--count", "HEAD..origin/main") == "0", "Bring main up to date with origin/main")
        }
        guard let inferred = try automaticBump(current) else { return }
        bump = inferred
    } else { bump = requested }
    let version = try nextVersion(current, bump)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    let content = try prepareChangelog(read("CHANGELOG.md"), current: current, version: version, date: formatter.string(from: Date()))
    print(try notes(content, version), terminator: "")
    if option == "--dry-run" { return }
    try require(try git("status", "--porcelain").isEmpty, "Commit or set aside working-tree changes before releasing")
    let revision = try git("rev-parse", "HEAD")
    try require(try git("branch", "--show-current") == "main", "Prepare releases on main")
    if requested != "auto" { try run(["git", "fetch", "origin", "main", "--tags"]) }
    try require(try git("rev-list", "--count", "HEAD..origin/main") == "0", "Bring main up to date with origin/main")
    let tag = "v\(version)"
    try require(try git("tag", "--list", tag).isEmpty, "Tag \(tag) already exists")
    try selfTest()
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("captainslog-release-\(UUID().uuidString)")
    let data = temporary.appendingPathComponent("data")
    let config = temporary.appendingPathComponent("config.json")
    try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }
    try JSONSerialization.data(withJSONObject: ["dataDir": data.path]).write(to: config)
    let environment = ["CAPTAINS_LOG_CONFIG_PATH": config.path,
                       "CAPTAINS_LOG_DATA_DIR": data.path,
                       "CAPTAINS_LOG_SEARCH_INTEGRATION": "0"]
    // Build all products once, then run that build's test executable without another SwiftPM invocation.
    for (label, command) in [("Build", ["make", "build", "CONFIGURATION=debug", "ARGS="]),
                             ("Deterministic tests", [".build/debug/run-tests"])] {
        let started = Date()
        print("\(label)...")
        try run(command, environment: environment)
        print(String(format: "%@ passed in %.2fs", label, Date().timeIntervalSince(started)))
    }
    let status = try git("status", "--porcelain")
    let checkedRevision = try git("rev-parse", "HEAD")
    try require(status.isEmpty && checkedRevision == revision, "Source changed during release preparation; review and retry")
    try write(version + "\n", "VERSION")
    try write(content, "CHANGELOG.md")
    try run(["git", "--no-pager", "diff", "--no-ext-diff", "--check"])
    try run(["git", "add", "VERSION", "CHANGELOG.md"])
    try run(["git", "commit", "-m", "chore(release): CaptainsLog \(version)"])
    try run(["git", "tag", "-a", tag, "-m", "CaptainsLog \(version)"])
    let push = ["git", "push", "--atomic", "origin", "main", tag]
    print("Prepared \(tag). Publish/retry with: \(push.joined(separator: " "))")
    if option == "--publish" { try run(push) }
}
func selfTest() throws {
    let fixture = "# Changelog\n\n## [Unreleased]\n\n- Synthetic fix.\n\n## [0.1.2] - 2026-10-01\n\n- Previous feature.\n\n[Unreleased]: https://github.com/vnglst/CaptainsLog/compare/v0.1.2...HEAD\n"
    for (bump, expected) in [("patch", "0.1.3"), ("minor", "0.2.0"), ("major", "1.0.0"), ("2.3.4", "2.3.4")] {
        try require(try nextVersion("0.1.2", bump) == expected, "Version bump failed")
    }
    for invalid in ["0.1.2", "0.1.1", "latest"] {
        try require((try? nextVersion("0.1.2", invalid)) == nil, "Invalid bump accepted")
    }
    let commitCases: [([String], String, String?)] = [
        (["fix: repair", "docs: explain"], "0.1.2", "patch"),
        (["perf(search): speed up lookup"], "1.2.3", "patch"),
        (["fix: repair", "FEAT(cli): add command"], "0.1.2", "minor"),
        (["refactor(api)!: remove endpoint"], "1.2.3", "major"),
        (["refactor!: remove endpoint"], "0.1.2", "minor"),
        (["fix: repair\n\nBREAKING CHANGE: remove old config"], "1.2.3", "major"),
        (["chore(config): update\n\nBREAKING-CHANGE: replace key"], "0.1.2", "minor"),
        (["fix: repair\n\nbreaking change: not a breaking footer"], "1.2.3", "patch"),
        (["feat: add", "fix!: remove"], "1.2.3", "major"),
        (["docs: explain", "chore(release): publish", "Legacy message"], "0.1.2", nil),
        (["feat: ", "feat(): empty scope", "feat:missing space"], "0.1.2", nil),
        ([], "0.1.2", nil),
    ]
    for (messages, current, expected) in commitCases {
        try require(try inferredBump(messages, current: current) == expected, "Incorrect Conventional Commit bump: \(messages)")
    }
    let old = try notes(fixture, "0.1.2")
    try require(old.contains("Previous feature") && !old.contains("Synthetic fix") && !old.contains("[Unreleased]:"), "Incorrect note extraction")
    for invalid in [fixture.replacingOccurrences(of: "2026-10-01", with: "2026-02-30"),
                    fixture.replacingOccurrences(of: " - 2026-10-01", with: ""),
                    fixture.replacingOccurrences(of: "- Previous feature.", with: ""),
                    fixture + "\n## [0.1.2] - 2026-10-01\n- Duplicate\n"] {
        try require((try? notes(invalid, "0.1.2")) == nil, "Invalid notes accepted")
    }
    try require((try? notes(fixture, "0.1.3")) == nil, "Missing notes accepted")
    let rolled = try prepareChangelog(fixture, current: "0.1.2", version: "0.1.3", date: "2026-10-02")
    let new = try notes(rolled, "0.1.3")
    try require(rolled.contains("## [Unreleased]\n\n## [0.1.3]") && rolled.contains("v0.1.3...HEAD") && rolled.contains("v0.1.2...v0.1.3"), "Rollover failed")
    try require(new.contains("Synthetic fix") && !new.contains("Previous feature"), "History leaked into release")
    for invalid in [fixture.replacingOccurrences(of: "- Synthetic fix.", with: ""),
                    fixture.replacingOccurrences(of: "v0.1.2...HEAD", with: "v0.1.1...HEAD")] {
        try require((try? prepareChangelog(invalid, current: "0.1.2", version: "0.1.3", date: "2026-10-02")) == nil, "Invalid rollover accepted")
    }
    print("Release note/version checks passed.")
}
let usage = """
Usage: make release [BUMP=auto|patch|minor|major|version] [ARGS=--dry-run|--publish]
       make release-notes VERSION=<version>
       make release-check BASE=<base> HEAD=<head>
       make release-cask VERSION=<version> SHA256=<sha256>
       make tests-release
"""
do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    switch arguments.first {
    case "--help": print(usage)
    case "notes":
        try require(arguments.count == 2, usage)
        print(try notes(read("CHANGELOG.md"), arguments[1]), terminator: "")
    case "check":
        try require(arguments.count == 3, usage)
        try checkRange(arguments[1], arguments[2])
    case "cask":
        try require(arguments.count == 3, usage)
        try updateCask(arguments[1], arguments[2])
    case "test":
        try require(arguments.count == 1, usage)
        try selfTest()
    default:
        if arguments.contains("--help") { print(usage) }
        else { try prepareRelease(arguments) }
    }
} catch {
    FileHandle.standardError.write(Data("Release error: \(error.localizedDescription)\n".utf8))
    exit(1)
}

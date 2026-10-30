#!/usr/bin/env swift
import Foundation
import CryptoKit
import Darwin

func require(_ condition: Bool, _ message: String) {
    guard condition else { fputs(message + "\n", stderr); exit(1) }
}
let args = CommandLine.arguments
let env = ProcessInfo.processInfo.environment
require(args.count == 3 || args.count == 4, "usage: test-search-shutdown.swift APP_EXECUTABLE NEW_ABSOLUTE_OUTPUT [--baseline]")
let baseline = args.contains("--baseline")
let root = URL(fileURLWithPath: args[2], isDirectory: true)
let fm = FileManager.default
require(args[2].hasPrefix("/") && !fm.fileExists(atPath: root.path), "Use a new absolute output directory")
let qwen = env["CAPTAINSLOG_QWEN_MODEL_FOLDER"] ?? ""
let whisper = env["CAPTAINSLOG_WHISPER_MODEL_FOLDER"] ?? ""
require(fm.fileExists(atPath: qwen) && fm.fileExists(atPath: whisper), "Prepared Qwen and Whisper folders are required; no downloads in this check")
let embedding = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("CaptainsLog/models/embeddings/multilingual-e5-small-q8_0.gguf")
require(fm.fileExists(atPath: embedding.path), "Prepare the E5 embedding model before this native check")
func sha256(_ url: URL) throws -> String {
    let file = try FileHandle(forReadingFrom: url); defer { try? file.close() }
    var hash = SHA256()
    while let data = try file.read(upToCount: 1024 * 1024), !data.isEmpty { hash.update(data: data) }
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
}
let embeddingHash = try sha256(embedding)
require(embeddingHash == "e011debc1208e31bf7b6aebee2d9fc8bd2ca11694a77ed66ac9d0c9d0a877c93", "E5 model checksum must match the pinned model")
let header = URL(fileURLWithPath: "eval/enrich/expected/2025-01-14 side project.md")
let body = URL(fileURLWithPath: "eval/cleanup/expected/2025-01-14 side project.md")
require(fm.fileExists(atPath: header.path) && fm.fileExists(atPath: body.path), "Run from the repository root; use only eval fixtures")
let data = root.appendingPathComponent("data")
let logs = data.appendingPathComponent("logs/side-project")
try fm.createDirectory(at: logs, withIntermediateDirectories: true)
let stem = "2025-01-14-0730"
let slug = "2025-01-14-side-project-star-trek-voice-log"
for relative in [".pipeline/01-transcribed", ".pipeline/02-logs", ".pipeline/03-category", ".pipeline/04-rename"] {
    try fm.createDirectory(at: data.appendingPathComponent(relative), withIntermediateDirectories: true)
}
try fm.copyItem(at: URL(fileURLWithPath: "eval/transcribe/archive/expected/2025-01-14 side project.md"),
                to: data.appendingPathComponent(".pipeline/01-transcribed/\(stem).md"))
try fm.copyItem(at: body, to: data.appendingPathComponent(".pipeline/02-logs/\(stem).md"))
try fm.copyItem(at: body, to: data.appendingPathComponent(".pipeline/04-rename/\(slug).md"))
try JSONSerialization.data(withJSONObject: ["sourceStem": stem, "category": "side_project"], options: [.sortedKeys])
    .write(to: data.appendingPathComponent(".pipeline/03-category/\(stem).json"))
try slug.write(to: data.appendingPathComponent(".pipeline/04-rename/\(stem).slug.txt"), atomically: true, encoding: .utf8)
try (String(contentsOf: header, encoding: .utf8) + "\n" + String(contentsOf: body, encoding: .utf8))
    .write(to: logs.appendingPathComponent("2025-01-14-side-project-star-trek-voice-log.md"), atomically: true, encoding: .utf8)
let config: [String: Any] = ["schemaVersion": 1, "dataDir": data.path, "whisperModel": "openai_whisper-large-v2", "whisperModelFolder": whisper, "qwenModelId": "Qwen3.5-9B-Q4_K_M", "qwenModelFolder": qwen, "automaticUpdates": false, "automaticUpdateChecks": false]
let configURL = root.appendingPathComponent("config.json")
try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]).write(to: configURL)
var childEnv = env; childEnv["CAPTAINS_LOG_CONFIG_PATH"] = configURL.path
childEnv.removeValue(forKey: "CAPTAINSLOG_UI_FIXTURE")
let cli = Process(); cli.executableURL = URL(fileURLWithPath: args[1]).deletingLastPathComponent().appendingPathComponent("cl")
cli.arguments = ["config", "show"]; cli.environment = childEnv
let pipe = Pipe(); cli.standardOutput = pipe; cli.standardError = pipe
try cli.run(); let checkedData = pipe.fileHandleForReading.readDataToEndOfFile(); cli.waitUntilExit()
let checked = String(decoding: checkedData, as: UTF8.self)
try checkedData.write(to: root.appendingPathComponent("config-show.txt"))
require(cli.terminationStatus == 0 && checked.contains("dataDir:             " + data.path) && checked.contains("whisperModelFolder:  " + whisper) && checked.contains("qwenModelFolder:     " + qwen), "Loaded config must match exact isolated data and model paths")
let listing = Process(); listing.executableURL = cli.executableURL
listing.arguments = ["list"]; listing.environment = childEnv
let listingPipe = Pipe(); listing.standardOutput = listingPipe; listing.standardError = listingPipe
try listing.run(); let listingData = listingPipe.fileHandleForReading.readDataToEndOfFile(); listing.waitUntilExit()
try listingData.write(to: root.appendingPathComponent("list-before-search.txt"))
let listed = String(decoding: listingData, as: UTF8.self)
require(listing.terminationStatus == 0 && listed.contains(slug) && listed.contains("done"), "Synthetic checkpoints must expose one completed entry before native search")
let executable = URL(fileURLWithPath: args[1])
let revision = Process(); revision.executableURL = URL(fileURLWithPath: "/usr/bin/git")
revision.arguments = ["rev-parse", "HEAD"]
let revisionPipe = Pipe(); revision.standardOutput = revisionPipe
try revision.run(); let revisionData = revisionPipe.fileHandleForReading.readDataToEndOfFile(); revision.waitUntilExit()
require(revision.terminationStatus == 0, "Cannot record source revision")
let repositoryRevision = String(decoding: revisionData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
var sourceRevision = repositoryRevision
let identityURL = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("bundle-identity.json")
let binaryHash = try sha256(executable)
if fm.fileExists(atPath: identityURL.path) {
    let identity = try JSONSerialization.jsonObject(with: Data(contentsOf: identityURL)) as? [String: Any]
    let hashes = identity?["hashes"] as? [String: String]
    require(hashes?[executable.lastPathComponent] == binaryHash, "Preserved bundle identity must match the actual executable")
    guard let savedRevision = identity?["sourceRevision"] as? String else { fatalError("Missing preserved source revision") }
    sourceRevision = savedRevision
}
let metadata: [String: Any] = ["sourceRevision": sourceRevision, "helperRepositoryRevision": repositoryRevision, "binarySHA256": binaryHash, "embeddingSHA256": embeddingHash, "headerSHA256": try sha256(header), "bodySHA256": try sha256(body), "executable": executable.standardizedFileURL.path, "operatingSystem": ProcessInfo.processInfo.operatingSystemVersionString]
try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]).write(to: root.appendingPathComponent("metadata.json"))
let trace = root.appendingPathComponent("trace.txt")
childEnv["CAPTAINSLOG_PERFORMANCE_TRACE"] = trace.path
childEnv["CAPTAINSLOG_SEARCH_QUIT_CHECK"] = "1"
let process = Process(); process.executableURL = executable; process.environment = childEnv
// Process-local defaults skip onboarding without changing the user's saved defaults.
process.arguments = ["-CaptainsLogHasLaunched", "YES"]
let log = root.appendingPathComponent("app.log"); fm.createFile(atPath: log.path, contents: nil)
let output = try FileHandle(forWritingTo: log); process.standardOutput = output; process.standardError = output
let start = ProcessInfo.processInfo.systemUptime
try process.run()
try String(process.processIdentifier).write(to: root.appendingPathComponent("pid.txt"), atomically: true, encoding: .utf8)
var timedOut = false
while process.isRunning {
    if ProcessInfo.processInfo.systemUptime - start > 180 {
        timedOut = true; kill(process.processIdentifier, SIGTERM)
        Thread.sleep(forTimeInterval: 0.5)
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        break
    }
    Thread.sleep(forTimeInterval: 0.02)
}
process.waitUntilExit(); try output.close()
let text = (try? String(contentsOf: trace, encoding: .utf8)) ?? ""
let result: [String: Any] = ["pid": process.processIdentifier, "exitStatus": process.terminationStatus, "normalExit": process.terminationReason == .exit, "timedOut": timedOut, "elapsedSeconds": ProcessInfo.processInfo.systemUptime - start]
try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]).write(to: root.appendingPathComponent("result.json"))
print("Cached-search quit: exit \(process.terminationStatus), normal \(process.terminationReason == .exit), timeout \(timedOut). Evidence: \(root.path)")
require(text.contains("cached-search-ready") && text.contains("quit-request") && text.contains("delegate-reply"), "Check must load/search/cache a real model and enter native app termination")
let database = Process(); database.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
database.arguments = [data.appendingPathComponent(".search/search.sqlite").path, "SELECT count(*) FROM documents; SELECT count(*) FROM chunks;"]
let databasePipe = Pipe(); database.standardOutput = databasePipe; database.standardError = databasePipe
try database.run(); let databaseData = databasePipe.fileHandleForReading.readDataToEndOfFile(); database.waitUntilExit()
try databaseData.write(to: root.appendingPathComponent("index-counts.txt"))
let counts = String(decoding: databaseData, as: UTF8.self).split(separator: "\n").compactMap { Int($0) }
require(database.terminationStatus == 0 && counts.count == 2 && counts[0] == 1 && counts[1] > 0, "Native search must have indexed the evaluation document and embedded its passages")
if !baseline { require(!timedOut && process.terminationReason == .exit && process.terminationStatus == 0, "Cached-search app quit crashed or did not terminate normally") }

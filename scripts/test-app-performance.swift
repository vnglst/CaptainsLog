#!/usr/bin/env swift
import Foundation
import CryptoKit
import Darwin

// Opt-in native check: compile the debug app first and supply installed model paths.
let args = CommandLine.arguments
let env = ProcessInfo.processInfo.environment
func require(_ condition: Bool, _ message: String) { if !condition { fputs(message + "\n", stderr); exit(1) } }
require(args.count >= 3, "usage: test-app-performance.swift APP_EXECUTABLE OUTPUT_DIR [--baseline] [--startup-only] [--quit-during-loading] [--startup-entries=1000] [--startup-max-seconds=5] [--startup-runs=3]")
let startupOnly = args.contains("--startup-only")
let quitDuringLoading = args.contains("--quit-during-loading")
let entriesOption = args.dropFirst(3).first { $0.hasPrefix("--startup-entries=") }
let runsOption = args.dropFirst(3).first { $0.hasPrefix("--startup-runs=") }
let startupRuns = runsOption.flatMap { Int($0.split(separator: "=").last ?? "") } ?? 3
require(runsOption == nil || (startupRuns > 0 && startupRuns <= 20), "Startup runs must be 1...20")
let limitOption = args.dropFirst(3).first { $0.hasPrefix("--startup-max-seconds=") }
let startupLimit = limitOption.flatMap { Double($0.split(separator: "=").last ?? "") } ?? 5
require((limitOption == nil || Double(limitOption!.split(separator: "=").last ?? "") != nil) && startupLimit > 0 && startupLimit.isFinite, "Startup limit must be positive and finite")
let startupEntries = entriesOption.flatMap { Int($0.split(separator: "=").last ?? "") } ?? 0
require(entriesOption == nil || (startupEntries > 0 && startupEntries <= 10000), "Startup fixture count must be 1...10000")
require(args.dropFirst(3).allSatisfy { $0 == "--baseline" || $0 == "--startup-only" || $0 == "--quit-during-loading" || $0 == entriesOption || $0 == limitOption || $0 == runsOption }, "Unknown performance option")
require(!args[2].isEmpty, "A new absolute output directory is required")
require(args[2].hasPrefix("/"), "Use an absolute output directory")
let processTimeoutValue = env["CAPTAINSLOG_PERFORMANCE_PROCESS_TIMEOUT"]
let processTimeout = processTimeoutValue.flatMap(Double.init) ?? 180
require((processTimeoutValue == nil || Double(processTimeoutValue!) != nil) && processTimeout.isFinite && processTimeout >= 180 && processTimeout <= 600, "Processing watchdog must be 180...600 seconds")
let baseline = args.contains("--baseline")
let output = URL(fileURLWithPath: args[2], isDirectory: true)
let fm = FileManager.default
try fm.createDirectory(at: output, withIntermediateDirectories: true)
let qwen = env["CAPTAINSLOG_QWEN_MODEL_FOLDER"] ?? ""
let whisper = env["CAPTAINSLOG_WHISPER_MODEL_FOLDER"] ?? ""
require(fm.fileExists(atPath: qwen), "Missing prepared Qwen folder")
require(fm.fileExists(atPath: whisper), "Missing prepared Whisper folder")
let fixture = URL(fileURLWithPath: "eval/transcribe/archive/audio/2025-01-14 side project.m4a")
require(fm.fileExists(atPath: fixture.path), "Run from the repository root with eval fixtures")
func sha256(_ path: String) throws -> String {
    let file = try FileHandle(forReadingFrom: URL(fileURLWithPath: path)); defer { try? file.close() }
    var hash = SHA256()
    while let data = try file.read(upToCount: 1024 * 1024), !data.isEmpty { hash.update(data: data) }
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
}
var modelHashes: [String: String] = [:]
modelHashes["qwen-gguf"] = try sha256(URL(fileURLWithPath: qwen).appendingPathComponent("Qwen_Qwen3.5-9B-Q4_K_M.gguf").path)
for component in ["AudioEncoder", "MelSpectrogram", "TextDecoder"] {
    let weight = URL(fileURLWithPath: whisper).appendingPathComponent("\(component).mlmodelc/weights/weight.bin")
    modelHashes[component] = try sha256(weight.path)
}
let revisionProcess = Process(); revisionProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
revisionProcess.arguments = ["rev-parse", "HEAD"]
let revisionOutput = Pipe(); revisionProcess.standardOutput = revisionOutput
try revisionProcess.run(); let revisionData = revisionOutput.fileHandleForReading.readDataToEndOfFile(); revisionProcess.waitUntilExit()
require(revisionProcess.terminationStatus == 0, "Cannot record repository revision")
var startupFixtureHashes: [String: String] = [:]
if startupEntries > 0 {
    for path in ["eval/transcribe/archive/expected/2025-01-14 side project.md", "eval/cleanup/expected/2025-01-14 side project.md", "eval/enrich/expected/2025-01-14 side project.md"] {
        startupFixtureHashes[path] = try sha256(path)
    }
}
let metadata: [String: Any] = ["revision": String(decoding: revisionData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines), "executable": URL(fileURLWithPath: args[1]).standardizedFileURL.path, "binarySHA256": try sha256(args[1]), "fixtureSHA256": try sha256(fixture.path), "modelSHA256": modelHashes, "operatingSystem": ProcessInfo.processInfo.operatingSystemVersionString, "processorCount": ProcessInfo.processInfo.processorCount, "promptChunkSize": 128, "baselineThresholdsDisabled": baseline, "startupFixtureEntries": startupEntries, "startupFixtureSHA256": startupFixtureHashes, "startupLimitSeconds": startupLimit, "startupOnlyControlledStop": startupOnly, "quitDuringLoading": quitDuringLoading, "startupRuns": startupRuns, "processingWatchdogSeconds": processTimeout]
try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("metadata.json"))
var results: [[String: Any]] = []
let startupModes = (1...startupRuns).map { "startup-\($0)" }
let modes = quitDuringLoading ? ["processing-close"] : startupOnly ? startupModes : env["CAPTAINSLOG_PERFORMANCE_QWEN"] == "1" ? ["processing-close"] : startupModes + ["processing-close"]
for mode in modes {
    let run = output.appendingPathComponent(mode, isDirectory: true)
    require(!fm.fileExists(atPath: run.path), "Output already exists: \(run.path)")
    let data = run.appendingPathComponent("data", isDirectory: true)
    try fm.createDirectory(at: data.appendingPathComponent("audio"), withIntermediateDirectories: true)
    if mode.hasPrefix("startup") && startupEntries > 0 {
        let transcript = try Data(contentsOf: URL(fileURLWithPath: "eval/transcribe/archive/expected/2025-01-14 side project.md"))
        let cleaned = try Data(contentsOf: URL(fileURLWithPath: "eval/cleanup/expected/2025-01-14 side project.md"))
        let enriched = try Data(contentsOf: URL(fileURLWithPath: "eval/enrich/expected/2025-01-14 side project.md"))
        for directory in [".pipeline/01-transcribed", ".pipeline/02-logs", ".pipeline/03-category", ".pipeline/04-rename", "logs/side-project"] {
            try fm.createDirectory(at: data.appendingPathComponent(directory), withIntermediateDirectories: true)
        }
        for index in 0..<startupEntries {
            let stem = String(format: "2025-01-14 fixture-%04d", index)
            let slug = String(format: "2025-01-14-fixture-%04d", index)
            try transcript.write(to: data.appendingPathComponent(".pipeline/01-transcribed/\(stem).md"))
            try cleaned.write(to: data.appendingPathComponent(".pipeline/02-logs/\(stem).md"))
            try JSONSerialization.data(withJSONObject: ["sourceStem": stem, "category": "side_project"]).write(to: data.appendingPathComponent(".pipeline/03-category/\(stem).json"))
            try slug.write(to: data.appendingPathComponent(".pipeline/04-rename/\(stem).slug.txt"), atomically: true, encoding: .utf8)
            try cleaned.write(to: data.appendingPathComponent(".pipeline/04-rename/\(slug).md"))
            try enriched.write(to: data.appendingPathComponent("logs/side-project/\(slug).md"))
        }
    } else {
        try fm.copyItem(at: fixture, to: data.appendingPathComponent("audio/2025-01-14-0730.m4a"))
    }
    if env["CAPTAINSLOG_PERFORMANCE_QWEN"] == "1" {
        let transcript = data.appendingPathComponent(".pipeline/01-transcribed/2025-01-14-0730.md")
        try fm.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: URL(fileURLWithPath: "eval/transcribe/archive/expected/2025-01-14 side project.md"), to: transcript)
    }
    let config: [String: Any] = ["schemaVersion": 1, "dataDir": data.path, "whisperModel": "openai_whisper-large-v2", "whisperModelFolder": whisper, "qwenModelId": "Qwen3.5-9B-Q4_K_M", "qwenModelFolder": qwen, "automaticUpdates": false, "automaticUpdateChecks": false]
    let configPath = run.appendingPathComponent("config.json")
    try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]).write(to: configPath)
    let checker = Process()
    checker.executableURL = URL(fileURLWithPath: args[1]).deletingLastPathComponent().appendingPathComponent("cl")
    checker.arguments = ["config", "show"]
    var isolatedEnv = env; isolatedEnv["CAPTAINS_LOG_CONFIG_PATH"] = configPath.path
    checker.environment = isolatedEnv
    let configOutput = Pipe(); checker.standardOutput = configOutput; checker.standardError = configOutput
    try checker.run()
    let checkedData = configOutput.fileHandleForReading.readDataToEndOfFile(); checker.waitUntilExit()
    let checked = String(decoding: checkedData, as: UTF8.self)
    try checkedData.write(to: run.appendingPathComponent("config-show.txt"))
    require(checker.terminationStatus == 0, "Isolated configuration check failed")
    var settings: [String: String] = [:]
    for line in checked.split(separator: "\n") {
        let fields = line.split(separator: ":", maxSplits: 1)
        if fields.count == 2 { settings[fields[0].trimmingCharacters(in: .whitespaces)] = fields[1].trimmingCharacters(in: .whitespaces) }
    }
    require(settings["dataDir"] == data.path && settings["whisperModelFolder"] == whisper && settings["qwenModelFolder"] == qwen, "Loaded config does not match isolated data/model paths")
    let trace = run.appendingPathComponent("trace.txt")
    let process = Process(); process.executableURL = URL(fileURLWithPath: args[1])
    process.arguments = ["-CaptainsLogHasLaunched", "YES"]
    var child = env; child["CAPTAINS_LOG_CONFIG_PATH"] = configPath.path
    child["CAPTAINSLOG_PERFORMANCE_TRACE"] = trace.path
    if mode == "processing-close" {
        child["CAPTAINSLOG_PERFORMANCE_PROCESS"] = "1"
        if quitDuringLoading { child["CAPTAINSLOG_PERFORMANCE_QUIT_ON_LOAD"] = "1" }
        else if env["CAPTAINSLOG_PERFORMANCE_FINISH_PIPELINE"] != "1" { child["CAPTAINSLOG_PERFORMANCE_QUIT_ON_DECODE"] = "1" }
    } else { child["CAPTAINSLOG_PERFORMANCE_STARTUP_ONLY"] = "1" }
    child.removeValue(forKey: "CAPTAINSLOG_UI_FIXTURE")
    process.environment = child
    let log = run.appendingPathComponent("app.log"); fm.createFile(atPath: log.path, contents: nil)
    let handle = try FileHandle(forWritingTo: log); process.standardOutput = handle; process.standardError = handle
    let started = ProcessInfo.processInfo.systemUptime
    try process.run()
    try String(process.processIdentifier).write(to: run.appendingPathComponent("pid.txt"), atomically: true, encoding: .utf8)
    var markers: [String: Double] = [:]
    var timedOut = false
    var stoppedAfterReadiness = false
    while process.isRunning {
        if let text = try? String(contentsOf: trace, encoding: .utf8) {
            for line in text.split(separator: "\n") {
                let fields = line.split(separator: " ", maxSplits: 1)
                if fields.count == 2, let time = Double(fields[0]) { markers[String(fields[1])] = time }
            }
        }
        if startupOnly && markers["models-ready"].map({ ProcessInfo.processInfo.systemUptime - $0 > 1 }) == true && markers["bootstrap-ready"] != nil {
            // This mode measures startup only. Stop the owned idle process after
            // readiness instead of treating an AppKit quit as part of startup.
            stoppedAfterReadiness = true
            kill(process.processIdentifier, SIGTERM)
            Thread.sleep(forTimeInterval: 0.1)
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            break
        }
        if markers["pipeline-failed"] != nil {
            kill(process.processIdentifier, SIGTERM)
            Thread.sleep(forTimeInterval: 0.1)
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            break
        }
        let now = ProcessInfo.processInfo.systemUptime
        if now - started > (mode == "processing-close" ? processTimeout : 180) || markers["quit-request"].map({ now - $0 > 60 }) == true {
            timedOut = true; kill(process.processIdentifier, SIGTERM)
            Thread.sleep(forTimeInterval: 0.5)
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            break
        }
        Thread.sleep(forTimeInterval: 0.02)
    }
    process.waitUntilExit(); try handle.close()
    let finished = ProcessInfo.processInfo.systemUptime
    if let text = try? String(contentsOf: trace, encoding: .utf8) {
        for line in text.split(separator: "\n") {
            let fields = line.split(separator: " ", maxSplits: 1)
            if fields.count == 2, let time = Double(fields[0]) { markers[String(fields[1])] = time }
        }
    }
    let startup = markers["models-ready"].map { $0 - started } ?? -1
    let close = startupOnly ? -1 : markers["quit-request"].map { finished - $0 } ?? -1
    let record: [String: Any] = ["mode": mode, "startupSeconds": startup, "closeSeconds": close, "exitStatus": process.terminationStatus, "normalExit": process.terminationReason == .exit, "processingSeconds": markers["pipeline-complete"].map { $0 - (markers["models-ready"] ?? started) } ?? -1, "timedOut": timedOut, "pipelineFailed": markers["pipeline-failed"] != nil, "stoppedAfterReadiness": stoppedAfterReadiness, "markers": markers]
    results.append(record)
    try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("results.json"))
    print("\(mode): startup \(startup)s, close \(close)s, exit \(process.terminationStatus), timeout \(timedOut)")
    if !baseline {
        if startupOnly {
            require(!timedOut && (stoppedAfterReadiness || (process.terminationStatus == 0 && process.terminationReason == .exit)) && markers["view-ready"] != nil && markers["bootstrap-ready"] != nil, "Startup check did not reach native readiness")
        } else {
            require(!timedOut && process.terminationStatus == 0 && process.terminationReason == .exit, "Native check did not terminate cleanly")
        }
        require(startup >= 0 && startup < startupLimit, "Startup readiness exceeded \(startupLimit) seconds")
        if mode == "processing-close" && quitDuringLoading {
            require(markers["whisper-loader Loading text decoder"] != nil && markers["quit-request"] != nil && markers["delegate-terminate"] != nil, "Quit must occur during native model initialization")
            require(close >= 0 && close < 3, "Quit during model initialization exceeded 3 seconds")
            if let bounded = markers["termination-bounded-exit"] {
                require(markers["termination-capture-closed"].map { $0 <= bounded } == true,
                        "Bounded exit must wait for the recording writer to close")
            } else {
                require(markers["termination-drained"] != nil && markers["delegate-reply"] != nil,
                        "Graceful exit must drain native teardown")
            }
        }
        if mode == "processing-close" && !quitDuringLoading {
            require((markers["whisper-decode"] != nil || markers["qwen-decode"] != nil) && markers["delegate-terminate"] != nil && markers["termination-drained"] != nil && markers["delegate-reply"] != nil, "Quit must occur during actual native decoding and drain teardown")
            let decode = markers["whisper-decode"] ?? markers["qwen-decode"]!
            require(decode <= markers["quit-request"]! && markers["quit-request"]! <= markers["delegate-terminate"]! && markers["delegate-terminate"]! <= markers["termination-drained"]! && markers["termination-drained"]! <= markers["delegate-reply"]!, "Native shutdown markers are out of order")
            require(close >= 0 && close < 3, "Quit during processing exceeded 3 seconds")
            if env["CAPTAINSLOG_PERFORMANCE_QWEN"] != "1" { require(!fm.fileExists(atPath: data.appendingPathComponent(".pipeline/01-transcribed/2025-01-14-0730.md").path), "Canceled partial transcript must not be saved") }
        }
    }
}

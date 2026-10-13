#!/usr/bin/env swift
import Foundation
import CryptoKit
import Darwin

// Opt-in native check: compile the debug app first and supply installed model paths.
let args = CommandLine.arguments
let env = ProcessInfo.processInfo.environment
func require(_ condition: Bool, _ message: String) { if !condition { fputs(message + "\n", stderr); exit(1) } }
require(args.count == 3 || args.count == 4, "usage: test-app-performance.swift APP_EXECUTABLE OUTPUT_DIR [--baseline]")
require(!args[2].isEmpty, "A new absolute output directory is required")
require(args[2].hasPrefix("/"), "Use an absolute output directory")
let baseline = args.contains("--baseline")
let output = URL(fileURLWithPath: args[2], isDirectory: true)
let fm = FileManager.default
try fm.createDirectory(at: output, withIntermediateDirectories: true)
let qwen = env["CAPTAINSLOG_QWEN_MODEL_FOLDER"] ?? ""
let whisper = env["CAPTAINSLOG_WHISPER_MODEL_FOLDER"] ?? ""
require(fm.fileExists(atPath: qwen), "Missing prepared Qwen folder")
require(fm.fileExists(atPath: whisper), "Missing prepared Whisper folder")
let fixture = URL(fileURLWithPath: "eval/transcribe/audio/2025-01-14 side project.m4a")
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
let metadata: [String: Any] = ["revision": String(decoding: revisionData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines), "executable": URL(fileURLWithPath: args[1]).standardizedFileURL.path, "binarySHA256": try sha256(args[1]), "fixtureSHA256": try sha256(fixture.path), "modelSHA256": modelHashes, "operatingSystem": ProcessInfo.processInfo.operatingSystemVersionString, "processorCount": ProcessInfo.processInfo.processorCount, "promptChunkSize": env["CAPTAINSLOG_PERFORMANCE_BASELINE_BATCH"] == "1" ? 512 : 128, "baselineThresholdsDisabled": baseline]
try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("metadata.json"))
var results: [[String: Any]] = []
let modes = env["CAPTAINSLOG_PERFORMANCE_QWEN"] == "1" ? ["processing-close"] : ["startup-1", "startup-2", "startup-3", "processing-close"]
for mode in modes {
    let run = output.appendingPathComponent(mode, isDirectory: true)
    require(!fm.fileExists(atPath: run.path), "Output already exists: \(run.path)")
    let data = run.appendingPathComponent("data", isDirectory: true)
    try fm.createDirectory(at: data.appendingPathComponent("audio"), withIntermediateDirectories: true)
    try fm.copyItem(at: fixture, to: data.appendingPathComponent("audio/2025-01-14-0730.m4a"))
    if env["CAPTAINSLOG_PERFORMANCE_QWEN"] == "1" {
        let transcript = data.appendingPathComponent(".pipeline/01-transcribed/2025-01-14-0730.md")
        try fm.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: URL(fileURLWithPath: "eval/transcribe/expected/2025-01-14 side project.md"), to: transcript)
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
    var child = env; child["CAPTAINS_LOG_CONFIG_PATH"] = configPath.path
    child["CAPTAINSLOG_PERFORMANCE_TRACE"] = trace.path
    if mode == "processing-close" {
        child["CAPTAINSLOG_PERFORMANCE_PROCESS"] = "1"
        if env["CAPTAINSLOG_PERFORMANCE_FINISH_PIPELINE"] != "1" { child["CAPTAINSLOG_PERFORMANCE_QUIT_ON_DECODE"] = "1" }
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
    while process.isRunning {
        if let text = try? String(contentsOf: trace, encoding: .utf8) {
            for line in text.split(separator: "\n") {
                let fields = line.split(separator: " ", maxSplits: 1)
                if fields.count == 2, let time = Double(fields[0]) { markers[String(fields[1])] = time }
            }
        }
        let now = ProcessInfo.processInfo.systemUptime
        if now - started > 180 || markers["quit-request"].map({ now - $0 > 60 }) == true {
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
    let close = markers["quit-request"].map { finished - $0 } ?? -1
    let record: [String: Any] = ["mode": mode, "startupSeconds": startup, "closeSeconds": close, "exitStatus": process.terminationStatus, "normalExit": process.terminationReason == .exit, "processingSeconds": markers["pipeline-complete"].map { $0 - (markers["models-ready"] ?? started) } ?? -1, "timedOut": timedOut, "markers": markers]
    results.append(record)
    try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("results.json"))
    print("\(mode): startup \(startup)s, close \(close)s, exit \(process.terminationStatus), timeout \(timedOut)")
    if !baseline {
        require(!timedOut && process.terminationStatus == 0 && process.terminationReason == .exit, "Native check did not terminate cleanly")
        require(startup >= 0 && startup < 5, "Startup readiness exceeded 5 seconds")
        if mode == "processing-close" {
            require((markers["whisper-decode"] != nil || markers["qwen-decode"] != nil) && markers["delegate-terminate"] != nil && markers["termination-drained"] != nil && markers["delegate-reply"] != nil, "Quit must occur during actual native decoding and drain teardown")
            let decode = markers["whisper-decode"] ?? markers["qwen-decode"]!
            require(decode <= markers["quit-request"]! && markers["quit-request"]! <= markers["delegate-terminate"]! && markers["delegate-terminate"]! <= markers["termination-drained"]! && markers["termination-drained"]! <= markers["delegate-reply"]!, "Native shutdown markers are out of order")
            require(close >= 0 && close < 3, "Quit during processing exceeded 3 seconds")
            if env["CAPTAINSLOG_PERFORMANCE_QWEN"] != "1" { require(!fm.fileExists(atPath: data.appendingPathComponent(".pipeline/01-transcribed/2025-01-14-0730.md").path), "Canceled partial transcript must not be saved") }
        }
    }
}

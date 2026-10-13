#!/usr/bin/env swift
import Foundation
import Darwin

// Opt-in native check: compile the debug app first and supply installed model paths.
let args = CommandLine.arguments
let env = ProcessInfo.processInfo.environment
func require(_ condition: Bool, _ message: String) { if !condition { fputs(message + "\n", stderr); exit(1) } }
require(args.count == 3 || args.count == 4, "usage: test-app-performance.swift APP_EXECUTABLE OUTPUT_DIR [--baseline]")
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
var results: [[String: Any]] = []
for mode in ["startup-1", "startup-2", "startup-3", "processing-close"] {
    let run = output.appendingPathComponent(mode, isDirectory: true)
    require(!fm.fileExists(atPath: run.path), "Output already exists: \(run.path)")
    let data = run.appendingPathComponent("data", isDirectory: true)
    try fm.createDirectory(at: data.appendingPathComponent("audio"), withIntermediateDirectories: true)
    try fm.copyItem(at: fixture, to: data.appendingPathComponent("audio/2025-01-14-0730.m4a"))
    let config: [String: Any] = ["dataDir": data.path, "whisperModel": "openai_whisper-large-v2", "whisperModelFolder": whisper, "qwenModelId": "Qwen3.5-9B-Q4_K_M", "qwenModelFolder": qwen, "automaticUpdates": false, "automaticUpdateChecks": false]
    let configPath = run.appendingPathComponent("config.json")
    try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]).write(to: configPath)
    let trace = run.appendingPathComponent("trace.txt")
    let process = Process(); process.executableURL = URL(fileURLWithPath: args[1])
    var child = env; child["CAPTAINS_LOG_CONFIG_PATH"] = configPath.path
    child["CAPTAINSLOG_PERFORMANCE_TRACE"] = trace.path
    if mode == "processing-close" {
        child["CAPTAINSLOG_PERFORMANCE_PROCESS"] = "1"; child["CAPTAINSLOG_PERFORMANCE_QUIT_ON_DECODE"] = "1"
    } else { child["CAPTAINSLOG_PERFORMANCE_STARTUP_ONLY"] = "1" }
    child.removeValue(forKey: "CAPTAINSLOG_UI_FIXTURE")
    process.environment = child
    let log = run.appendingPathComponent("app.log"); fm.createFile(atPath: log.path, contents: nil)
    let handle = try FileHandle(forWritingTo: log); process.standardOutput = handle; process.standardError = handle
    let started = ProcessInfo.processInfo.systemUptime
    try process.run()
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
    let record: [String: Any] = ["mode": mode, "startupSeconds": startup, "closeSeconds": close, "exitStatus": process.terminationStatus, "timedOut": timedOut, "markers": markers]
    results.append(record)
    try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("results.json"))
    print("\(mode): startup \(startup)s, close \(close)s, exit \(process.terminationStatus), timeout \(timedOut)")
    if !baseline {
        require(!timedOut && process.terminationStatus == 0, "Native check did not terminate cleanly")
        require(startup >= 0 && startup < 5, "Startup readiness exceeded 5 seconds")
        if mode == "processing-close" {
            require(markers["whisper-decode"] != nil && markers["delegate-terminate"] != nil && markers["termination-drained"] != nil, "Quit must occur during actual native decoding and drain teardown")
            require(close >= 0 && close < 10, "Quit during processing exceeded 10 seconds")
            require(!fm.fileExists(atPath: data.appendingPathComponent(".pipeline/01-transcribed/2025-01-14-0730.md").path), "Canceled partial transcript must not be saved")
        }
    }
}

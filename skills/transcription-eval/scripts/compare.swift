#!/usr/bin/env swift
import Foundation
import Darwin

// Use exactly the scorer and normalization recorded by the evaluation runner.
let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = ["swift", repository.appendingPathComponent("scripts/tooling.swift").path,
                     "score-transcription"] + Array(CommandLine.arguments.dropFirst())
process.standardInput = FileHandle.standardInput
process.standardOutput = FileHandle.standardOutput
process.standardError = FileHandle.standardError
try process.run()
process.waitUntilExit()
exit(process.terminationStatus)

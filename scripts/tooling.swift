#!/usr/bin/env swift
// Public Swift entrypoints share the compiled automation package.
import Foundation
import Darwin

let entrypoint = URL(fileURLWithPath: CommandLine.arguments[0])
let directory = entrypoint.deletingLastPathComponent().standardizedFileURL
let name = entrypoint.deletingPathExtension().lastPathComponent
var arguments = Array(CommandLine.arguments.dropFirst())
let command: String
if name == "tooling" {
    guard !arguments.isEmpty else { fputs("Usage: tooling.swift COMMAND [ARGS...]\n", stderr); exit(2) }
    command = arguments.removeFirst()
} else {
    command = name == "run-evals" ? "evals" : name
}
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = ["swift", "run", "--package-path", directory.path, "captainslog-tools", command] + arguments
process.standardInput = FileHandle.standardInput
process.standardOutput = FileHandle.standardOutput
process.standardError = FileHandle.standardError
try process.run()
process.waitUntilExit()
exit(process.terminationStatus)

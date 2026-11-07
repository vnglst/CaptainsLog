import Foundation
import EvalFixtureLibrary

struct CheckFailure: Error { let message: String }

func require(_ condition: @autoclosure () throws -> Bool) throws {
    guard try condition() else { throw CheckFailure(message: "Fixture library check failed") }
}

private func evalRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
}

func seedsCanonicalLibraryAndPreservesRuntimeChanges() throws {
    let fm = FileManager.default
    let data = fm.temporaryDirectory.appendingPathComponent("fixture-library-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: data) }
    try EvalFixtureLibrary.prepare(evalRoot: evalRoot(), dataRoot: data)

    let final = data.appendingPathComponent("logs/personal/2025-04-27-enterprise-vrije-dag-sensorcontrole.md")
    let cleaned = try String(contentsOf: evalRoot().appendingPathComponent("pipeline/tng-nl01/cleaned.md"), encoding: .utf8)
    let metadata = try String(contentsOf: evalRoot().appendingPathComponent("pipeline/tng-nl01/enriched.md"), encoding: .utf8)
    try require(try String(contentsOf: final, encoding: .utf8) == metadata + cleaned)
    try require(try Data(contentsOf: data.appendingPathComponent("audio/2025-04-27-1200.m4a")) == Data(contentsOf: evalRoot().appendingPathComponent("transcribe/audio/tng-nl01-vrije-dag-enterprise-corrected.m4a")))
    try require(try Data(contentsOf: data.appendingPathComponent("audio/world-war-z.m4a")) == Data(contentsOf: evalRoot().appendingPathComponent("transcribe/audio/world-war-z.m4a")))
    try require(fm.fileExists(atPath: data.appendingPathComponent(".pipeline/01-transcribed/2025-01-16-0900.md").path))
    try require(fm.fileExists(atPath: data.appendingPathComponent("logs/professional/2025-01-15-work-week-review.md").path))

    try "Runtime edit\n".write(to: final, atomically: true, encoding: .utf8)
    try EvalFixtureLibrary.prepare(evalRoot: evalRoot(), dataRoot: data)
    try require(try String(contentsOf: final, encoding: .utf8) == "Runtime edit\n")
    try require(try String(contentsOf: evalRoot().appendingPathComponent("pipeline/tng-nl01/enriched.md"), encoding: .utf8) == metadata)
}

func rejectsPathsOutsideFixtureLibrary() throws {
    let fm = FileManager.default
    let temporary = fm.temporaryDirectory.appendingPathComponent("fixture-library-path-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: temporary) }
    try fm.createDirectory(at: temporary, withIntermediateDirectories: true)
    let manifest = #"{"completed":[],"pending":[{"stem":"memo","transcript":"../outside.md"}]}"#
    try manifest.write(to: temporary.appendingPathComponent("demo-library.json"), atomically: true, encoding: .utf8)
    do {
        try EvalFixtureLibrary.prepare(evalRoot: temporary, dataRoot: temporary.appendingPathComponent("data"))
        throw CheckFailure(message: "Fixture path traversal was accepted")
    } catch is CocoaError {
        // Invalid manifest paths are rejected before reading outside the library.
    }
}

try seedsCanonicalLibraryAndPreservesRuntimeChanges()
try rejectsPathsOutsideFixtureLibrary()
print("Fixture library checks passed: canonical audio/text, pending entries, retained edits, source preservation and rejected traversal.")

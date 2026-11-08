import Foundation
import EvalFixtureLibrary

struct CheckFailure: Error { let message: String }

func require(_ condition: @autoclosure () throws -> Bool) throws {
    guard try condition() else { throw CheckFailure(message: "Fixture library check failed") }
}

private func evalRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("eval")
}

func seedsCanonicalLibraryAndPreservesRuntimeChanges() throws {
    let fm = FileManager.default
    let data = fm.temporaryDirectory.appendingPathComponent("fixture-library-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: data) }
    try EvalFixtureLibrary.prepare(evalRoot: evalRoot(), dataRoot: data)

    let final = data.appendingPathComponent("logs/personal/2025-04-27-enterprise-vrije-dag-sensorcontrole.md")
    let cleaned = try String(contentsOf: evalRoot().appendingPathComponent("suites/pipeline/tng-nl01/cleaned.md"), encoding: .utf8)
    let metadata = try String(contentsOf: evalRoot().appendingPathComponent("suites/pipeline/tng-nl01/enriched.md"), encoding: .utf8)
    try require(try String(contentsOf: final, encoding: .utf8) == metadata + cleaned)
    try require(try Data(contentsOf: data.appendingPathComponent("audio/2025-04-27-1200.m4a")) == Data(contentsOf: evalRoot().appendingPathComponent("suites/transcribe/audio/tng-nl01-vrije-dag-enterprise-corrected.m4a")))
    try require(try Data(contentsOf: data.appendingPathComponent("audio/world-war-z.m4a")) == Data(contentsOf: evalRoot().appendingPathComponent("suites/transcribe/audio/world-war-z.m4a")))
    try require(fm.fileExists(atPath: data.appendingPathComponent(".pipeline/01-transcribed/2025-01-16-0900.md").path))
    try require(fm.fileExists(atPath: data.appendingPathComponent("logs/professional/2025-01-15-work-week-review.md").path))

    let context = data.appendingPathComponent("context/personal_info.md")
    let corrections = data.appendingPathComponent("context/corrections.md")
    try require(try String(contentsOf: context, encoding: .utf8) == String(contentsOf: evalRoot().appendingPathComponent("fixtures/demo-context/personal_info.md"), encoding: .utf8))
    try require(try String(contentsOf: corrections, encoding: .utf8) == String(contentsOf: evalRoot().appendingPathComponent("fixtures/demo-context/corrections.md"), encoding: .utf8))

    try "Runtime edit\n".write(to: final, atomically: true, encoding: .utf8)
    try "My edited crew profile\n".write(to: context, atomically: true, encoding: .utf8)
    try "".write(to: corrections, atomically: true, encoding: .utf8)
    try EvalFixtureLibrary.prepare(evalRoot: evalRoot(), dataRoot: data)
    try require(try String(contentsOf: final, encoding: .utf8) == "Runtime edit\n")
    try require(try String(contentsOf: context, encoding: .utf8) == "My edited crew profile\n")
    try require(try String(contentsOf: corrections, encoding: .utf8).isEmpty)
    try require(try String(contentsOf: evalRoot().appendingPathComponent("suites/pipeline/tng-nl01/enriched.md"), encoding: .utf8) == metadata)
}

func rejectsPathsOutsideFixtureLibrary() throws {
    let fm = FileManager.default
    let temporary = fm.temporaryDirectory.appendingPathComponent("fixture-library-path-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: temporary) }
    try fm.createDirectory(at: temporary, withIntermediateDirectories: true)
    let manifest = #"{"completed":[],"pending":[{"stem":"memo","transcript":"../outside.md"}]}"#
    try fm.createDirectory(at: temporary.appendingPathComponent("fixtures"), withIntermediateDirectories: true)
    try manifest.write(to: temporary.appendingPathComponent("fixtures/demo-library.json"), atomically: true, encoding: .utf8)
    do {
        try EvalFixtureLibrary.prepare(evalRoot: temporary, dataRoot: temporary.appendingPathComponent("data"))
        throw CheckFailure(message: "Fixture path traversal was accepted")
    } catch let error as CocoaError {
        try require(error.code == .fileReadCorruptFile)
        // Invalid manifest paths are rejected before reading outside the library.
    }
}

try seedsCanonicalLibraryAndPreservesRuntimeChanges()
try rejectsPathsOutsideFixtureLibrary()
print("Fixture library checks passed: canonical audio/text, TNG context, pending entries, retained edits, source preservation and rejected traversal.")

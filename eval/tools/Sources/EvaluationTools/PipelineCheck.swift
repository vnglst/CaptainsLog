import Foundation
import ToolSupport
extension Tools {
    func evalPipeline(_ args: [String]) throws {
        try require(args.count >= 2 && args.dropFirst(2).allSatisfy { ["--combined-metadata", "--check-artifacts"].contains($0) }, "Usage: eval-pipeline RUN_DIR CL [--combined-metadata] [--check-artifacts]", status: 2)
        let dir = path(args[0]), cl = args[1], data = dir.appendingPathComponent("data"), eval = Evaluator(self)
        guard let manifest = try json(dir.appendingPathComponent("manifest.json")) as? [EvalItem],
              let audio = manifest.first(where: { eval.string($0, "scope") == "pipeline" && eval.string($0, "stage") == "transcribe" }) else { throw ToolFailure("Missing pipeline audio fixture") }
        let stem = eval.string(audio, "name")
        if !args.contains("--check-artifacts") {
            try run([cl, "pipeline", "--input", eval.string(audio, "input"), "--data-dir", data.path] + (args.contains("--combined-metadata") ? ["--combined-metadata"] : []), log: dir.appendingPathComponent("pipeline.log"))
        }
        for relative in ["01-transcribed/\(stem).md", "02-logs/\(stem).md", "03-category/\(stem).json"] {
            try require(nonempty(data.appendingPathComponent(".pipeline/" + relative)), "Pipeline artifact assertion failed: \(relative)")
        }
        let category = try json(data.appendingPathComponent(".pipeline/03-category/\(stem).json")) as? [String: Any]
        guard let categoryName = category?["category"] as? String,
              let categoryFixture = manifest.first(where: { eval.string($0, "scope") == "pipeline" && eval.string($0, "stage") == "categorize" }) else { throw ToolFailure("Missing pipeline category") }
        let accepted = try read(eval.file(categoryFixture, "expected")).split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        try require(accepted.contains(categoryName), "Unexpected pipeline category")
        let marker = data.appendingPathComponent(".pipeline/04-rename/\(stem).slug.txt")
        try require(nonempty(marker), "Missing slug marker")
        let slug = try read(marker).trimmingCharacters(in: .whitespacesAndNewlines)
        let enriched = data.appendingPathComponent("logs/\(categoryName.replacingOccurrences(of: "_", with: "-"))/\(slug).md")
        try require(nonempty(data.appendingPathComponent(".pipeline/04-rename/\(slug).md")) && nonempty(enriched), "Missing renamed/enriched artifacts for \(slug)")
        func snapshot() throws -> String { try files(data, recursive: true).map { try hash($0) + "  " + $0.path }.sorted().joined(separator: "\n") + "\n" }
        let before = try snapshot(); try write(dir.appendingPathComponent("before-resume.sha256"), before)
        try run([cl, "resume", "--data-dir", data.path], log: dir.appendingPathComponent("resume.log"))
        let after = try snapshot(); try write(dir.appendingPathComponent("after-resume.sha256"), after)
        try require(before == after, "Resume changed completed pipeline artifacts")
        try run([cl, "search-index", "--data-dir", data.path], log: dir.appendingPathComponent("search-index.log"))
        let search = try run([cl, "search", eval.string(audio, "search_query", "Star Trek captain log side project"), "--data-dir", data.path, "--limit", "5"], log: dir.appendingPathComponent("search.log"))
        try require(search.output.contains(enriched.path), "Search did not return pipeline entry: \(enriched.path)")
        print("Pipeline artifact, category, resume immutability, and search readback assertions passed.")
    }
}

import ArgumentParser
import CaptainsLogCore
import Foundation

/// Internal transport for run-evals.sh. Each stage uses the production API;
/// only the immutable model weights are reused, never contexts or samplers.
struct EvalBatch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "eval-batch",
        abstract: "Internal sequential fixture runner (use scripts/run-evals.sh).",
        shouldDisplay: false
    )

    struct Case: Decodable {
        let stage: String
        let input: String
        let output: String
    }

    @Option var manifest: String

    func run() async throws {
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: URL(fileURLWithPath: manifest)))
        let stages: Set<String> = ["cleanup", "categorize", "filename", "enrich"]
        guard !cases.isEmpty, cases.allSatisfy({ stages.contains($0.stage) }) else {
            throw ValidationError("Batch requires supported text stages.")
        }
        let start = Date()
        let container = try await LLM.loadModel()
        print("[eval] Model loaded once in \(Date().timeIntervalSince(start))s")
        let config = CaptainsLogConfig.load()
        for item in cases {
            let caseStart = Date()
            let text = try String(contentsOfFile: item.input, encoding: .utf8)
            let output: String
            switch item.stage {
            case "cleanup":
                output = try await Cleanup.cleanup(transcript: text, container: container, config: config)
            case "categorize":
                let category = try await Categorize.categorize(logText: text, container: container, config: config)
                let value = Categorize.Manifest(
                    sourceStem: URL(fileURLWithPath: item.input).deletingPathExtension().lastPathComponent,
                    category: category
                )
                output = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
            case "filename":
                output = try await Filename.generateFilename(logText: text, date: "2025-01-15", container: container)
            case "enrich":
                output = try await Enrich.enrich(
                    logText: text, date: "2025-01-15", recordingTime: "12:00", container: container, config: config
                )
            default:
                throw ValidationError("Unsupported stage: \(item.stage)")
            }
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: item.output).deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try output.write(toFile: item.output, atomically: true, encoding: .utf8)
            print("[eval] \(item.stage)/\(URL(fileURLWithPath: item.input).lastPathComponent): \(Date().timeIntervalSince(caseStart))s")
        }
    }
}

import ArgumentParser
import CaptainsLogCore
import Foundation

/// Internal transport for run-evals.swift. Each stage uses the production API;
/// only the immutable model weights are reused, never contexts or samplers.
struct EvalBatch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "eval-batch",
        abstract: "Internal sequential fixture runner (use make evals).",
        shouldDisplay: false
    )

    struct Case: Decodable {
        let stage: String
        let input: String
        let output: String
        let date: String?
        let recording_time: String?
        let seed: UInt32?
        let diagnostics: String?
    }

    @Option var manifest: String
    @Flag var combinedMetadata = false
    @Flag var verifyGrammar = false

    func run() async throws {
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: URL(fileURLWithPath: manifest)))
        let stages: Set<String> = ["cleanup", "categorize", "filename", "enrich"]
        guard !cases.isEmpty, cases.allSatisfy({ stages.contains($0.stage) && $0.seed != UInt32.max }) else {
            throw ValidationError("Batch requires supported text stages.")
        }
        let start = Date()
        let container = try await LLM.loadModel()
        print("[eval] Model loaded once in \(Date().timeIntervalSince(start))s")
        let config = CaptainsLogConfig.load()
        if verifyGrammar {
            let text = try String(contentsOfFile: cases[0].input, encoding: .utf8)
            let prompt = try Categorize.renderedPrompt(logText: text, config: CaptainsLogConfig())
            let expected = "<category>research</category>"
            let constrained = try await LLM.generate(
                container: container, systemPrompt: prompt.systemPrompt, userMessage: prompt.userMessage,
                maxTokens: 64, temperature: 0.1, seed: 42,
                grammar: #"root ::= "<category>research</category>""#
            )
            guard constrained == expected else { throw ValidationError("Native grammar allowed an unconfigured category.") }
            print("PASS: native grammar excludes unconfigured categories even when the prompt offers them.")
            let metadata = try await Metadata.generate(
                logText: text, date: cases[0].date ?? "2025-01-15", recordingTime: "12:00",
                container: container, config: CaptainsLogConfig(categories: ["professional", "side_project"]), seed: 42
            )
            let lines = metadata.yaml.components(separatedBy: .newlines)
            guard let categoryIndex = lines.firstIndex(of: "categories:") else {
                throw ValidationError("Native metadata category block is missing.")
            }
            let labels = Array(lines.dropFirst(categoryIndex + 1).prefix(while: { $0.hasPrefix("  - ") }))
            let allowed = Set(["  - \"personal\"", "  - \"work\"", "  - \"side-project\""])
            guard !labels.isEmpty, Set(labels).isSubset(of: allowed), Set(labels).count == labels.count else {
                throw ValidationError("Native metadata grammar allowed a filing identifier or duplicate metadata category.")
            }
            print("PASS: native metadata uses only distinct canonical labels, excluding professional and side_project.")
            let keys = lines.filter { !$0.hasPrefix(" ") }.compactMap { $0.split(separator: ":", maxSplits: 1).first.map(String.init) }
            guard keys == ["date", "recording_time", "language", "tags", "persons", "projects", "companies", "entities", "summary", "categories"],
                  !lines.contains(where: { $0.trimmingCharacters(in: .whitespaces) == "- []" }),
                  lines.filter({ $0.hasPrefix("  - ") }).allSatisfy({ $0.hasPrefix("  - \"") && $0.hasSuffix("\"") }) else {
                throw ValidationError("Native grammar allowed a missing/duplicate schema key or non-string list item.")
            }
            print("PASS: native metadata has every schema key once and quoted string lists, excluding nested empty arrays.")
            do {
                _ = try await LLM.generate(
                    container: container, systemPrompt: prompt.systemPrompt, userMessage: prompt.userMessage,
                    maxTokens: 64, temperature: 0.1, seed: 42, grammar: "root ::= ("
                )
                throw ValidationError("Invalid native grammar was silently ignored.")
            } catch {
                guard error.localizedDescription == "The output grammar is invalid." else { throw error }
            }
            print("PASS: invalid native grammar fails explicitly without unconstrained fallback.")
            return
        }
        for item in cases {
            let caseStart = Date()
            let text = try String(contentsOfFile: item.input, encoding: .utf8)
            let output: String
            if combinedMetadata && ["categorize", "filename", "enrich"].contains(item.stage) {
                let outputURL = URL(fileURLWithPath: item.output)
                try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let responseURL = URL(fileURLWithPath: item.output + ".response.txt")
                let generated = try await Metadata.generate(
                    logText: text, date: item.date ?? "2025-01-15", recordingTime: item.recording_time ?? "12:00",
                    container: container, config: config, seed: item.seed,
                    recordResponse: { try $0.write(to: responseURL, atomically: true, encoding: .utf8) }
                )
                try FileManager.default.createDirectory(
                    at: URL(fileURLWithPath: item.output).deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try JSONEncoder().encode(generated).write(to: URL(fileURLWithPath: item.output + ".combined.json"), options: .atomic)
                switch item.stage {
                case "categorize":
                    output = String(decoding: try JSONEncoder().encode(Categorize.Manifest(
                        sourceStem: URL(fileURLWithPath: item.input).deletingPathExtension().lastPathComponent,
                        category: generated.category
                    )), as: UTF8.self)
                case "filename": output = generated.filename
                default: output = generated.enriched(logText: text)
                }
            } else {
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
                    output = try await Filename.generateFilename(logText: text, date: item.date ?? "2025-01-15", container: container)
                case "enrich":
                    let log: FileHandle?
                    if let path = item.diagnostics {
                        FileManager.default.createFile(atPath: path, contents: nil)
                        log = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
                    } else {
                        log = nil
                    }
                    defer { try? log?.close() }
                    let diagnostic: (@Sendable (String) -> Void)?
                    if let handle = log {
                        diagnostic = { @Sendable message in
                            handle.write(Data((message + "\n").utf8))
                        }
                    } else {
                        diagnostic = nil
                    }
                    output = try await Enrich.enrich(
                        logText: text, date: item.date ?? "2025-01-15", recordingTime: item.recording_time ?? "12:00",
                        container: container, config: config, seed: item.seed, diagnostic: diagnostic
                    )
                default:
                    throw ValidationError("Unsupported stage: \(item.stage)")
                }
            }
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: item.output).deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try output.write(toFile: item.output, atomically: true, encoding: .utf8)
            print("[eval] \(item.stage)/\(URL(fileURLWithPath: item.input).lastPathComponent): \(Date().timeIntervalSince(caseStart))s")
        }
    }
}

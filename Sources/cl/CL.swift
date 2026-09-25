import ArgumentParser
import CaptainsLogCore
import Foundation

@main
struct CL: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cl",
        abstract: "CaptainsLog command-line interface.",
        subcommands: [Ping.self, Record.self, Warm.self, Transcribe.self, CleanupCommand.self, CategorizeCommand.self, FilenameCommand.self, EnrichCommand.self, PipelineCommand.self, ResumeCommand.self, ListCommand.self, SearchIndexCommand.self, SearchCommand.self, ConfigCommand.self]
    )
}

/// Resolves the pipeline data directory: explicit arg > config > env > "processed".
func resolveDataDir(_ explicit: String? = nil) -> String {
    explicit
        ?? CaptainsLogConfig.load().dataDir
        ?? ProcessInfo.processInfo.environment["CAPTAINS_LOG_DATA_DIR"]
        ?? "processed"
}

struct Ping: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Smoke test that core is wired up."
    )

    func run() async throws {
        print("captains log core v\(CaptainsLogCore.version)")
    }
}

struct Record: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Record audio from the default input device."
    )

    @Option(help: "Duration in seconds (default: record until Ctrl+C).")
    var duration: Int?

    @Option(help: "Output file path (default: YYYY-MM-DD-HHMM.m4a in current directory).")
    var output: String?

    func run() async throws {
        let outputPath = output ?? Recorder.defaultOutputPath()
        let url = URL(fileURLWithPath: outputPath)
        try await Recorder.record(to: url, duration: duration.map { TimeInterval($0) })
    }
}

struct Transcribe: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Transcribe an audio file using Whisper."
    )

    @Argument(help: "Path to the audio file (.m4a, .wav, .mp3).")
    var input: String

    @Option(help: "Output file path (default: same name with .md extension).")
    var output: String?

    @Option(help: "Model name (default: config value or \(Transcriber.defaultModel)).")
    var model: String?

    @Option(help: "ISO-639-1 language code to pin (e.g. 'nl'). Default: auto-detect.")
    var language: String?

    func run() async throws {
        let outputPath = output ?? defaultOutputPath(for: input)
        try FileSystemGuard.requireFreeSpaceForTranscription(paths: [
            outputPath,
            CaptainsLogConfig.configURL.path,
            NSTemporaryDirectory(),
        ])
        let transcript = try await Transcriber.transcribe(
            audioPath: input,
            model: model,
            language: language
        )

        try FileSystemGuard.writeText(transcript, to: outputPath)
        print("Transcript saved to \(outputPath)")
    }

    private func defaultOutputPath(for inputPath: String) -> String {
        let url = URL(fileURLWithPath: inputPath)
        return url.deletingPathExtension().appendingPathExtension("md").path
    }
}

struct CleanupCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cleanup",
        abstract: "Clean up a transcript using the LLM."
    )

    @Option(help: "Input transcript file.")
    var input: String

    @Option(help: "Output file path (default: input filename in current directory).")
    var output: String?

    @Option(help: "Path to cleanup prompt (default: \(Cleanup.defaultPromptPath)).")
    var prompt: String?

    @Option(help: "Hugging Face model ID (default: \(LLM.defaultModelId)).")
    var model: String?

    @Flag(help: "Print the fully rendered prompt and exit.")
    var printPrompt = false

    func run() async throws {
        let transcript = try String(contentsOfFile: input, encoding: .utf8)
        let renderedPrompt = try Cleanup.renderedPrompt(
            transcript: transcript,
            promptPath: prompt ?? Cleanup.defaultPromptPath
        )

        if printPrompt {
            print(PromptDebug.render(renderedPrompt))
            return
        }
        let container = try await LLM.loadModel(modelId: model)

        let result = try await Cleanup.cleanup(
            transcript: transcript,
            container: container,
            promptPath: prompt ?? Cleanup.defaultPromptPath
        )

        let outputPath = output ?? URL(fileURLWithPath: input).lastPathComponent
        try FileSystemGuard.writeText(result, to: outputPath)
        print("Saved to \(outputPath)")
    }
}

struct FilenameCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "filename",
        abstract: "Generate a descriptive filename slug for a log entry."
    )

    @Option(help: "Input log file.")
    var input: String

    @Option(help: "Date in YYYY-MM-DD format (default: today).")
    var date: String?

    @Option(help: "Path to filename prompt (default: \(Filename.defaultPromptPath)).")
    var prompt: String?

    @Option(help: "Hugging Face model ID (default: \(LLM.defaultModelId)).")
    var model: String?

    @Flag(help: "Print the fully rendered prompt and exit.")
    var printPrompt = false

    func run() async throws {
        let logText = try String(contentsOfFile: input, encoding: .utf8)
        let dateStr = date ?? defaultDate()
        let renderedPrompt = try Filename.renderedPrompt(
            logText: logText,
            date: dateStr,
            promptPath: prompt ?? Filename.defaultPromptPath
        )

        if printPrompt {
            print(PromptDebug.render(renderedPrompt))
            return
        }
        let container = try await LLM.loadModel(modelId: model)

        let filename = try await Filename.generateFilename(
            logText: logText,
            date: dateStr,
            container: container,
            promptPath: prompt ?? Filename.defaultPromptPath
        )

        print(filename)
    }

    private func defaultDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

struct CategorizeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "categorize",
        abstract: "Choose one destination category for a cleaned log entry."
    )

    @Option(help: "Input cleaned log file.") var input: String
    @Option(help: "Output category manifest JSON file.") var output: String
    @Option(help: "Path to category prompt (default: \(Categorize.defaultPromptPath)).") var prompt: String?
    @Option(help: "Hugging Face model ID (default: \(LLM.defaultModelId)).") var model: String?
    @Flag(help: "Print the fully rendered prompt and exit.") var printPrompt = false

    func run() async throws {
        let text = try String(contentsOfFile: input, encoding: .utf8)
        let rendered = try Categorize.renderedPrompt(logText: text, promptPath: prompt ?? Categorize.defaultPromptPath)
        if printPrompt { print(PromptDebug.render(rendered)); return }
        let diagnostics = DiagnosticLog(path: "\(output).log", label: "category")
        let container = try await LLM.loadModel(modelId: model)
        let category = try await Categorize.categorize(
            logText: text, container: container, promptPath: prompt ?? Categorize.defaultPromptPath,
            diagnostic: { message in await diagnostics.log(message) })
        let manifest = Categorize.Manifest(sourceStem: URL(fileURLWithPath: input).deletingPathExtension().lastPathComponent, category: category)
        let data = try JSONEncoder().encode(manifest)
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: output).deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileSystemGuard.writeText(String(decoding: data, as: UTF8.self), to: output)
        print("Category manifest saved to \(output)")
    }
}

struct EnrichCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "enrich",
        abstract: "Add YAML frontmatter metadata to a log entry."
    )

    @Option(help: "Input log file.")
    var input: String

    @Option(help: "Output file path (default: input filename in current directory).")
    var output: String?

    @Option(help: "Date in YYYY-MM-DD format (default: today).")
    var date: String?

    @Option(help: "Recording time in HH:MM format.")
    var recordingTime: String?

    @Option(help: "Path to enrich prompt (default: \(Enrich.defaultPromptPath)).")
    var prompt: String?

    @Option(help: "Hugging Face model ID (default: \(LLM.defaultModelId)).")
    var model: String?

    @Flag(help: "Print the fully rendered prompt and exit.")
    var printPrompt = false

    func run() async throws {
        let logText = try String(contentsOfFile: input, encoding: .utf8)
        let dateStr = date ?? defaultDate()
        let renderedPrompt = try Enrich.renderedPrompt(
            logText: logText,
            date: dateStr,
            recordingTime: recordingTime,
            promptPath: prompt ?? Enrich.defaultPromptPath
        )

        if printPrompt {
            print(PromptDebug.render(renderedPrompt))
            return
        }
        let container = try await LLM.loadModel(modelId: model)

        let result = try await Enrich.enrich(
            logText: logText,
            date: dateStr,
            recordingTime: recordingTime,
            container: container,
            promptPath: prompt ?? Enrich.defaultPromptPath
        )

        let outputPath = output ?? URL(fileURLWithPath: input).lastPathComponent
        try FileSystemGuard.writeText(result, to: outputPath)
        print("Saved to \(outputPath)")
    }

    private func defaultDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

struct PipelineCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pipeline",
        abstract: "Record and process a voice memo end-to-end. Records until Ctrl+C, then transcribes → cleans up → categorizes → generates a filename → enriches."
    )

    @Option(help: "Path to an existing audio file (default: record from mic).")
    var input: String?

    @Option(name: .long, help: "Data directory for pipeline output (default: ./processed).")
    var dataDir: String?

    @Option(help: "Max recording duration in seconds (default: unlimited, stop with Ctrl+C).")
    var duration: Int?

    @Option(help: "Hugging Face model ID for text processing (default: config value or \(LLM.defaultModelId)).")
    var model: String?

    @Option(help: "ISO-639-1 language code to pin (e.g. 'nl'). Default: auto-detect.")
    var language: String?

    func run() async throws {
        let dir = resolveDataDir(dataDir)
        let result = try await Pipeline.run(
            audioInput: input,
            dataDir: dir,
            language: language,
            recordDuration: duration.map { TimeInterval($0) },
            modelId: model,
            progress: { p in
                print("[stage:\(p.stage.rawValue)] \(p.stem)")
            }
        )
        print("\nOutput files:")
        print("  Audio:      \(result.audioPath)")
        print("  Transcript: \(result.transcriptPath)")
        print("  Cleaned:    \(result.cleanedPath)")
        print("  Renamed:    \(result.renamedPath)")
        print("  Enriched:   \(result.enrichedPath)")
        print("  Category:   \(result.category.rawValue)")
    }
}

struct ResumeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "resume",
        abstract: "Resume pipeline processing for unprocessed entries. Resumes a specific entry if stem is provided, or all pending entries if omitted."
    )

    @Argument(help: "Stem of the partial entry (e.g. '2026-04-17-1258' — no extension). If omitted, resumes all pending entries.")
    var stem: String?

    @Option(name: .long, help: "Data directory for pipeline output.")
    var dataDir: String?

    @Option(help: "Force starting from a specific stage (transcribing, cleaning, categorizing, naming, enriching).")
    var fromStage: String?

    @Option(help: "Hugging Face model ID for text processing (default: config value or \(LLM.defaultModelId)).")
    var model: String?

    @Option(help: "ISO-639-1 language code to pin (e.g. 'nl'). Default: auto-detect.")
    var language: String?

    func run() async throws {
        let dir = resolveDataDir(dataDir)

        if let singleStem = stem {
            // Resume single entry
            let stage = fromStage.flatMap { Pipeline.Stage(rawValue: $0) }
            let result = try await Pipeline.resume(
                stem: singleStem,
                dataDir: dir,
                fromStage: stage,
                language: language,
                modelId: model,
                progress: { p in
                    print("[stage:\(p.stage.rawValue)] \(p.stem)")
                }
            )
            print("\nOutput files:")
            print("  Transcript: \(result.transcriptPath)")
            print("  Cleaned:    \(result.cleanedPath)")
            print("  Renamed:    \(result.renamedPath)")
            print("  Enriched:   \(result.enrichedPath)")
            print("  Category:   \(result.category.rawValue)")
        } else {
            // Resume all pending entries
            let entries = Pipeline.listEntries(dataDir: dir).filter { $0.nextStage != .done }

            if entries.isEmpty {
                print("No pending entries to resume.")
                return
            }

            print("Resuming \(entries.count) pending entr\(entries.count == 1 ? "y" : "ies")...\n")

            for entry in entries {
                let detected = Pipeline.detectNextStage(stem: entry.stem, dataDir: dir)
                print("Processing \(entry.displayName) (starting at \(detected.rawValue))...")

                _ = try await Pipeline.resume(
                    stem: entry.stem,
                    dataDir: dir,
                    fromStage: detected,
                    language: language,
                    modelId: model,
                    progress: { p in
                        print("[stage:\(p.stage.rawValue)] \(p.stem)")
                    }
                )

                print("✓ Completed \(entry.displayName)\n")
            }

            print("All entries processed!")
        }
    }
}

struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all entries in a data dir, tagged with the next pipeline stage."
    )

    @Option(name: .long, help: "Data directory.")
    var dataDir: String?

    func run() async throws {
        let dir = resolveDataDir(dataDir)
        let entries = Pipeline.listEntries(dataDir: dir)
        for e in entries {
            print("[\(e.nextStage.rawValue)]  \(e.displayName)  (stem: \(e.stem))")
        }
    }
}

struct Warm: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Load the LLM and generate a few tokens to verify it works."
    )

    @Option(help: "Hugging Face model ID (default: \(LLM.defaultModelId)).")
    var model: String?

    func run() async throws {
        try await LLM.warm(modelId: model)
    }
}

struct SearchIndexCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search-index",
        abstract: "Build or update the local semantic-search index."
    )

    @Option(help: "Pipeline data directory (default: config value).")
    var dataDir: String?

    @Flag(help: "Discard and rebuild the existing search index.")
    var rebuild = false

    func run() async throws {
        let resolvedDataDir = resolveDataDir(dataDir)
        let downloadProgress = CLIDownloadProgressPrinter()
        print("Preparing multilingual search model…")
        let search = try await SemanticSearch.live(
            dataDir: resolvedDataDir,
            downloadProgress: { downloadProgress.report($0) }
        )
        let summary = try await search.synchronize(rebuild: rebuild) { progress in
            if progress.phase == .indexing {
                print("[\(progress.completed)/\(progress.total)] \(progress.message)")
            }
        }
        print(
            "Index ready: \(summary.added) added, \(summary.updated) updated, "
                + "\(summary.unchanged) unchanged, \(summary.removed) removed, "
                + "\(summary.chunks) chunks written."
        )
    }
}

struct SearchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search completed entries by meaning."
    )

    @Argument(help: "Natural-language search query.")
    var query: String

    @Option(help: "Maximum number of entries to return.")
    var limit: Int = 10

    @Option(help: "Pipeline data directory (default: config value).")
    var dataDir: String?

    func validate() throws {
        guard limit > 0 else { throw ValidationError("--limit must be greater than zero.") }
    }

    func run() async throws {
        let downloadProgress = CLIDownloadProgressPrinter()
        let search = try await SemanticSearch.live(
            dataDir: resolveDataDir(dataDir),
            downloadProgress: { downloadProgress.report($0) }
        )
        let results = try await search.search(query, limit: limit)
        if results.isEmpty {
            print("No matching entries.")
            return
        }
        for (offset, result) in results.enumerated() {
            let title = cliHighlighted(
                result.displayName.replacingOccurrences(of: "-", with: " "),
                terms: result.matchedTerms
            )
            let excerpt = cliHighlighted(result.excerpt, terms: result.matchedTerms)
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let kind = result.matchKind == .keyword ? "keyword match" : "related passage"
            print("\(offset + 1). \(title) [\(kind)]")
            print("   \(result.path)")
            print("   \(excerpt.prefix(240))")
        }
    }
}

private func cliHighlighted(_ text: String, terms: [String]) -> String {
    terms.reduce(text) { highlighted, term in
        let escaped = NSRegularExpression.escapedPattern(for: term)
        guard let expression = try? NSRegularExpression(
            pattern: "(?i)(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])")
        else { return highlighted }
        let range = NSRange(location: 0, length: (highlighted as NSString).length)
        return expression.stringByReplacingMatches(
            in: highlighted,
            range: range,
            withTemplate: "\u{001B}[1;33m$0\u{001B}[0m"
        )
    }
}

private final class CLIDownloadProgressPrinter: @unchecked Sendable {
    private let lock = NSLock()
    private var lastReportedBucket = -1

    func report(_ progress: Progress) {
        guard progress.totalUnitCount > 0 else { return }
        let percentage = min(100, max(0, Int(progress.fractionCompleted * 100)))
        let bucket = percentage == 100 ? 10 : percentage / 10
        lock.lock()
        defer { lock.unlock() }
        guard bucket > lastReportedBucket else { return }
        lastReportedBucket = bucket
        print("Embedding model: \(bucket * 10)%")
    }
}

struct ConfigCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Show or update CaptainsLog configuration.",
        subcommands: [ConfigShow.self, ConfigSet.self]
    )
}

struct ConfigShow: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Print current configuration."
    )

    func run() async throws {
        let cfg = CaptainsLogConfig.load()
        print("Config file: \(CaptainsLogConfig.configURL.path)")
        print("  dataDir:             \(cfg.dataDir ?? "(unset)")")
        print("  whisperModel:        \(cfg.whisperModel ?? "(unset, default: \(Transcriber.defaultModel))")")
        print("  whisperModelFolder:  \(cfg.whisperModelFolder ?? "(unset — will fetch from network)")")
        print("  qwenModelId:         \(cfg.qwenModelId ?? "(unset, default: \(LLM.defaultModelId))")")
        print("  qwenModelFolder:     \(cfg.qwenModelFolder ?? "(unset — local GGUF required)")")
        print("  personalContext:     \(cfg.readPersonalInfo() ?? "(unset — edit \(cfg.contextDir().path)/personal_info.md)")")
        print("  corrections:         \(cfg.readCorrections() ?? "(unset — edit \(cfg.contextDir().path)/corrections.md)")")
    }
}

struct ConfigSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set a config value."
    )

    @Argument(help: "Key (dataDir, whisperModel, whisperModelFolder, qwenModelId, qwenModelFolder).")
    var key: String

    @Argument(help: "Value (use 'unset' to clear).")
    var value: String

    func run() async throws {
        let v: String? = (value == "unset") ? nil : value
        let knownKeys = Set([
            "dataDir",
            "whisperModel",
            "whisperModelFolder",
            "qwenModelId",
            "qwenModelFolder",
        ])
        guard knownKeys.contains(key) else {
            let cfg = CaptainsLogConfig.load()
            throw ValidationError(
                """
                Unknown key: \(key)
                Valid keys: dataDir, whisperModel, whisperModelFolder, qwenModelId, qwenModelFolder
                Edit context files directly:
                  personal_info: \(cfg.contextDir().path)/personal_info.md
                  corrections:   \(cfg.contextDir().path)/corrections.md
                """
            )
        }
        try CaptainsLogConfig.update { cfg in
            switch key {
            case "dataDir": cfg.dataDir = v
            case "whisperModel": cfg.whisperModel = v
            case "whisperModelFolder": cfg.whisperModelFolder = v
            case "qwenModelId": cfg.qwenModelId = v
            case "qwenModelFolder": cfg.qwenModelFolder = v
            default:
                break
            }
        }
        print("Saved.")
    }
}

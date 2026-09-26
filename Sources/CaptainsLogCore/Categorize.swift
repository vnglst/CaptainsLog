import Foundation

public enum Categorize {
    public static let defaultPromptPath = "prompts/categorize.md"
    public static let defaultMaxTokens = 64
    public static let defaultTemperature: Float = 0.1

    public enum Category: String, Codable, CaseIterable, Sendable {
        case personal
        case professional
        case sideProject = "side_project"

        public var folderName: String {
            switch self {
            case .personal: return "personal"
            case .professional: return "professional"
            case .sideProject: return "side-project"
            }
        }
    }

    public struct Manifest: Codable, Equatable, Sendable {
        public let sourceStem: String
        public let category: Category

        public init(sourceStem: String, category: Category) {
            self.sourceStem = sourceStem
            self.category = category
        }
    }

    public typealias CommandOperation = @Sendable (
        _ logText: String,
        _ config: CaptainsLogConfig,
        _ promptPath: String,
        _ diagnostic: @escaping @Sendable (String) async -> Void
    ) async throws -> Category

    public enum CategorizeError: LocalizedError, Equatable {
        case invalidXML(outputByteCount: Int)
        case missingManifest(path: String)

        public var errorDescription: String? {
            switch self {
            case .invalidXML(let count):
                return "Category output was not valid XML (\(count) bytes received)."
            case .missingManifest(let path):
                return "Category manifest missing or unreadable: \(path)"
            }
        }
    }

    public static func categorize(
        logText: String,
        container: ModelContainer,
        config: CaptainsLogConfig = CaptainsLogConfig.load(),
        promptPath: String = defaultPromptPath,
        diagnostic: @Sendable @escaping (String) async -> Void = { _ in }
    ) async throws -> Category {
        let prompt = try renderedPrompt(logText: logText, config: config, promptPath: promptPath)
        await diagnostic("Category prompt ready: input=\(logText.utf8.count) bytes.")
        await diagnostic("Starting category inference (max tokens \(defaultMaxTokens)).")
        let start = Date()
        let raw = try await LLM.generate(
            container: container,
            systemPrompt: prompt.systemPrompt,
            userMessage: prompt.userMessage,
            maxTokens: defaultMaxTokens,
            temperature: defaultTemperature,
            diagnostic: { message in Task.detached { await diagnostic(message) } }
        )
        await diagnostic("Category inference completed in \(String(format: "%.1f", Date().timeIntervalSince(start)))s with \(raw.utf8.count) output bytes.")
        do {
            let category = try parseCategory(raw)
            await diagnostic("Category parsed: \(category.rawValue).")
            return category
        } catch {
            await diagnostic("Category XML parsing failed (error type: \(String(reflecting: type(of: error)))).")
            throw error
        }
    }

    public static func renderedPrompt(
        logText: String,
        config: CaptainsLogConfig = CaptainsLogConfig.load(),
        promptPath: String = defaultPromptPath
    ) throws -> RenderedPrompt {
        RenderedPrompt(
            systemPrompt: try PromptLoader.load(
                path: promptPath,
                replacements: ["{SPLIT_SPEAKER_CONTEXT_SECTION}": Cleanup.speakerContextSection(config.readPersonalInfo())]
            ),
            userMessage: PromptXML.document([PromptXML.element("log_entry", logText)])
        )
    }

    /// Runs the file and manifest part of the categorize CLI command with an injectable inference operation.
    public static func runCommand(
        inputPath: String,
        outputPath: String,
        promptPath: String = defaultPromptPath,
        config: CaptainsLogConfig = CaptainsLogConfig.load(),
        printPrompt: Bool = false,
        operation: CommandOperation
    ) async throws -> Category? {
        let logText = try String(contentsOfFile: inputPath, encoding: .utf8)
        let rendered = try renderedPrompt(logText: logText, config: config, promptPath: promptPath)
        if printPrompt {
            print(PromptDebug.render(rendered))
            return nil
        }

        let diagnostics = DiagnosticLog(path: "\(outputPath).log", label: "category")
        let category = try await operation(logText, config, promptPath) { message in
            await diagnostics.log(message)
        }
        let manifest = Manifest(
            sourceStem: URL(fileURLWithPath: inputPath).deletingPathExtension().lastPathComponent,
            category: category
        )
        let data = try JSONEncoder().encode(manifest)
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: outputPath).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileSystemGuard.writeText(String(decoding: data, as: UTF8.self), to: outputPath)
        print("Category manifest saved to \(outputPath)")
        return category
    }

    public static func parseCategory(_ raw: String) throws -> Category {
        let pattern = #"<\s*category\s*>([^<]+)</\s*category\s*>"#
        let range = NSRange(raw.startIndex..., in: raw)
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = expression.firstMatch(in: raw, range: range),
              let valueRange = Range(match.range(at: 1), in: raw),
              let category = Category(rawValue: raw[valueRange].trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        else {
            throw CategorizeError.invalidXML(outputByteCount: raw.utf8.count)
        }
        return category
    }

    public static func manifestURL(stem: String, dataDirURL: URL) -> URL {
        dataDirURL.appendingPathComponent(Pipeline.Directory.category.path).appendingPathComponent("\(stem).json")
    }

    public static func loadManifest(stem: String, dataDirURL: URL) throws -> Manifest {
        let url = manifestURL(stem: stem, dataDirURL: dataDirURL)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CategorizeError.missingManifest(path: url.path)
        }
        return try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
    }

    public static func writeManifest(_ manifest: Manifest, dataDirURL: URL) throws {
        let url = manifestURL(stem: manifest.sourceStem, dataDirURL: dataDirURL)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(manifest)
        try FileSystemGuard.writeText(String(decoding: data, as: UTF8.self), to: url.path)
    }
}

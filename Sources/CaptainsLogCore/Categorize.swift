import Foundation

public enum Categorize {
    public static let defaultPromptPath = "prompts/categorize.md"
    public static let defaultMaxTokens = 64
    public static let defaultTemperature: Float = 0.1

    public struct Category: RawRepresentable, Codable, CaseIterable, Hashable, Sendable {
        public let rawValue: String
        public static let personal = Category(rawValue: "personal")!
        public static let professional = Category(rawValue: "professional")!
        public static let sideProject = Category(rawValue: "side_project")!
        /// Built-in defaults retained for older configurations and clients.
        public static let allCases: [Category] = [.personal, .professional, .sideProject]

        public init?(rawValue: String) {
            guard !rawValue.isEmpty, rawValue.unicodeScalars.allSatisfy({
                CharacterSet.alphanumerics.contains($0) || $0 == "_"
            }) else { return nil }
            self.rawValue = rawValue.lowercased()
        }

        public init?(name: String) {
            let parts = name.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
            self.init(rawValue: parts.joined(separator: "_"))
        }

        public var folderName: String { rawValue.replacingOccurrences(of: "_", with: "-") }
        public var displayName: String { rawValue.replacingOccurrences(of: "_", with: " ").capitalized }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let category = Self(rawValue: raw) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid category")
            }
            self = category
        }
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
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
        case noCategories
        case missingManifest(path: String)

        public var errorDescription: String? {
            switch self {
            case .noCategories:
                return "Add a category in Settings before processing recordings."
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
            let category = try parseCategory(raw, categories: config.configuredCategories)
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
        guard !config.configuredCategories.isEmpty else { throw CategorizeError.noCategories }
        return RenderedPrompt(
            systemPrompt: try PromptLoader.load(
                path: promptPath,
                replacements: [
                    "{SPLIT_SPEAKER_CONTEXT_SECTION}": Cleanup.speakerContextSection(config.readPersonalInfo()),
                    "{CATEGORIES}": categoryInstructions(config.configuredCategories),
                    "{CATEGORY_EXAMPLE}": config.configuredCategories.first!.rawValue,
                ]
            ),
            userMessage: PromptXML.document([PromptXML.element("log_entry", logText)])
        )
    }

    private static func categoryInstructions(_ categories: [Category]) -> String {
        let descriptions: [Category: String] = [
            .personal: "family, friends, health, home, hobbies, travel, private reflection, and non-work life.",
            .professional: "paid work, colleagues, management, teams, companies, career, planning, meetings, delivery, and work-adjacent professional development.",
            .sideProject: "independent projects, experiments, learning projects, open-source work, apps, tools, writing, or creative/technical projects outside paid work.",
        ]
        return categories.map { "- \($0.rawValue): \(descriptions[$0] ?? $0.displayName)" }.joined(separator: "\n")
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

    public static func parseCategory(_ raw: String, categories: [Category] = Category.allCases) throws -> Category {
        let pattern = #"<\s*category\s*>([^<]+)</\s*category\s*>"#
        let range = NSRange(raw.startIndex..., in: raw)
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = expression.firstMatch(in: raw, range: range),
              let valueRange = Range(match.range(at: 1), in: raw),
              let category = Category(rawValue: raw[valueRange].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()),
              categories.contains(category)
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

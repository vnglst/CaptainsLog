import Foundation

/// One inference produces the three independent metadata checkpoints.
public enum Metadata {
    public static let defaultPromptPath = "prompts/metadata.md"

    public struct Result: Encodable, Sendable {
        public let category: Categorize.Category
        public let filename: String
        public let yaml: String

        public func enriched(logText: String) -> String {
            "---\n\(yaml)\n---\n\n\(logText)"
        }
    }

    public enum MetadataError: LocalizedError {
        case invalidResponse
        public var errorDescription: String? { "Combined metadata output is incomplete or invalid. Retry processing." }
    }

    public static func generate(
        logText: String, date: String, recordingTime: String,
        container: ModelContainer, config: CaptainsLogConfig,
        seed: UInt32? = nil,
        recordResponse: (@Sendable (String) throws -> Void)? = nil
    ) async throws -> Result {
        guard !config.configuredCategories.isEmpty else { throw Categorize.CategorizeError.noCategories }
        let prompt = try PromptLoader.load(path: defaultPromptPath, replacements: [
            "{date}": date, "{recording_time}": recordingTime,
            "{CATEGORY_RULES}": Categorize.categoryInstructions(config.configuredCategories),
            "{SPEAKER_CONTEXT}": Cleanup.speakerContextSection(config.readPersonalInfo()),
        ])
        let raw = try await LLM.generate(
            container: container, systemPrompt: prompt,
            userMessage: Enrich.userMessage(logText: logText),
            maxTokens: Enrich.defaultMaxTokens, temperature: Enrich.defaultTemperature,
            preventRepetition: true, seed: seed,
            grammar: try grammar(date: date, categories: config.configuredCategories)
        )
        try recordResponse?(raw)
        return try parse(raw, date: date, recordingTime: recordingTime, categories: config.configuredCategories)
    }

    /// GBNF constrains the complete YAML schema, envelope and configured identifiers.
    /// Grounding, completeness and name uniqueness still require semantic review.
    static func grammar(date: String, categories: [Categorize.Category]) throws -> String {
        guard !categories.isEmpty else { throw Categorize.CategorizeError.noCategories }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        func literal(_ value: String) throws -> String {
            String(decoding: try encoder.encode(value), as: UTF8.self)
        }
        let identifiers = try categories.map { try literal($0.rawValue) }.joined(separator: " | ")
        let prefix = try literal(date + "-")
        func permutations(_ prefix: [String], _ remaining: [String]) -> [[String]] {
            remaining.enumerated().flatMap { index, label in
                let next = prefix + [label]
                var rest = remaining
                rest.remove(at: index)
                return [next] + permutations(next, rest)
            }
        }
        let metadataCategories = try permutations([], ["personal", "work", "side-project"])
            .map { labels in try literal(labels.map { "  - \"\($0)\"\n" }.joined()) }
            .joined(separator: " | ")
        return #"""
        root ::= "<metadata>" body "</metadata>" ws "<filename>" \#(prefix) slug ".md</filename>" ws "<category>" category "</category>"
        body ::= "\nlanguage: " string "\ntags:\n" item{3,8} "persons:" list "projects:" list "companies:" list "entities:" list "summary: " string "\ncategories:\n" metadata-categories
        list ::= " []\n" | "\n" item{1,64}
        item ::= "  - " string "\n"
        string ::= "\"" character+ "\""
        character ::= [^"\\\x00-\x1f<] | "\\" (["\\/bfnrt] | "u" [0-9a-fA-F]{4})
        metadata-categories ::= \#(metadataCategories)
        ws ::= [ \t\n\r]*
        slug ::= word "-" word "-" word ("-" word){0,5}
        word ::= [a-z0-9]+
        category ::= \#(identifiers)
        """#
    }

    public static func parse(_ raw: String, date: String, recordingTime: String, categories: [Categorize.Category]) throws -> Result {
        // Delimiters are a transport envelope; field contents are never rewritten.
        func field(_ name: String) throws -> String {
            let open = "<\(name)>", close = "</\(name)>"
            guard raw.components(separatedBy: open).count == 2,
                  raw.components(separatedBy: close).count == 2,
                  let start = raw.range(of: open)?.upperBound,
                  let end = raw.range(of: close, range: start..<raw.endIndex)?.lowerBound else {
                throw MetadataError.invalidResponse
            }
            let value = raw[start..<end].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { throw MetadataError.invalidResponse }
            return value
        }
        let categoryValue = try field("category")
        guard let category = Categorize.Category(rawValue: categoryValue), categories.contains(category) else {
            throw MetadataError.invalidResponse
        }
        let filename = try field("filename")
        guard filename.hasPrefix(date + "-"), filename.hasSuffix(".md"),
              filename.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9]+(?:-[a-z0-9]+)*\.md$"#, options: .regularExpression) != nil else {
            throw MetadataError.invalidResponse
        }
        let yaml = try field("metadata")
        guard !yaml.hasPrefix("---"), !yaml.contains("```"), yaml.contains("summary:"),
              !yaml.components(separatedBy: .newlines).contains(where: {
                  $0.hasPrefix("date:") || $0.hasPrefix("recording_time:")
              }) else { throw MetadataError.invalidResponse }
        let frontmatter = "date: \"\(date)\"\nrecording_time: \"\(recordingTime)\"\n\(yaml)"
        return Result(category: category, filename: filename, yaml: frontmatter)
    }
}

/// Scoped to one pipeline invocation; fresh entries evaluate the cleaned memo once.
actor PipelineMetadata {
    private var value: Metadata.Result?
    private let generate: @Sendable (String, CaptainsLogConfig) async throws -> Metadata.Result

    init(container: ModelContainer, date: String, recordingTime: String) {
        generate = { logText, config in
            try await Metadata.generate(
                logText: logText, date: date, recordingTime: recordingTime,
                container: container, config: config
            )
        }
    }

    init(generate: @escaping @Sendable (String, CaptainsLogConfig) async throws -> Metadata.Result) {
        self.generate = generate
    }

    func result(logText: String, config: CaptainsLogConfig) async throws -> Metadata.Result {
        if let value { return value }
        let generated = try await generate(logText, config)
        try Task.checkCancellation()
        value = generated
        return generated
    }
}

import Foundation

public enum Enrich {

    public static let defaultPromptPath = "prompts/enrich.md"
    public static let defaultMaxTokens = 0
    public static let defaultTemperature: Float = 0.3

    public typealias CommandOperation = @Sendable (
        _ logText: String,
        _ date: String,
        _ recordingTime: String?,
        _ config: CaptainsLogConfig,
        _ promptPath: String
    ) async throws -> String

    public static func enrich(
        logText: String,
        date: String,
        recordingTime: String? = nil,
        container: ModelContainer,
        config: CaptainsLogConfig = CaptainsLogConfig.load(),
        promptPath: String = defaultPromptPath
    ) async throws -> String {
        let renderedPrompt = try renderedPrompt(
            logText: logText,
            date: date,
            recordingTime: recordingTime,
            config: config,
            promptPath: promptPath
        )

        Logger.llm.info("Enriching...")
        let start = Date()

        let yaml = try await LLM.generate(
            container: container,
            systemPrompt: renderedPrompt.systemPrompt,
            userMessage: renderedPrompt.userMessage,
            maxTokens: defaultMaxTokens,
            temperature: defaultTemperature
        )

        let elapsed = Date().timeIntervalSince(start)
        Logger.llm.info("Enriched in \(String(format: "%.1f", elapsed))s")

        return "---\n\(yaml)\n---\n\n\(logText)"
    }

    public static func renderedPrompt(
        logText: String,
        date: String,
        recordingTime: String? = nil,
        config: CaptainsLogConfig = CaptainsLogConfig.load(),
        promptPath: String = defaultPromptPath
    ) throws -> RenderedPrompt {
        RenderedPrompt(
            systemPrompt: try loadPrompt(
                from: promptPath,
                date: date,
                recordingTime: recordingTime,
                config: config
            ),
            userMessage: userMessage(logText: logText)
        )
    }

    /// Runs the file and output part of the enrich CLI command with an injectable inference operation.
    public static func runCommand(
        inputPath: String,
        outputPath: String? = nil,
        date: String,
        recordingTime: String? = nil,
        promptPath: String = defaultPromptPath,
        config: CaptainsLogConfig = CaptainsLogConfig.load(),
        printPrompt: Bool = false,
        operation: CommandOperation
    ) async throws -> String? {
        let logText = try String(contentsOfFile: inputPath, encoding: .utf8)
        let renderedPrompt = try renderedPrompt(
            logText: logText,
            date: date,
            recordingTime: recordingTime,
            config: config,
            promptPath: promptPath
        )
        if printPrompt {
            print(PromptDebug.render(renderedPrompt))
            return nil
        }

        let result = try await operation(logText, date, recordingTime, config, promptPath)
        let resolvedOutputPath = outputPath ?? URL(fileURLWithPath: inputPath).lastPathComponent
        try FileSystemGuard.writeText(result, to: resolvedOutputPath)
        print("Saved to \(resolvedOutputPath)")
        return result
    }

    static func loadPrompt(
        from path: String,
        date: String,
        recordingTime: String? = nil,
        config: CaptainsLogConfig = CaptainsLogConfig.load()
    ) throws -> String {
        var replacements: [String: String] = [
            "{date}": date,
            "{ENRICH_SPEAKER_CONTEXT_SECTION}": Cleanup.speakerContextSection(config.readPersonalInfo()),
        ]
        if let recordingTime {
            replacements["{recording_time}"] = recordingTime
        } else {
            replacements["{recording_time}"] = ""
        }
        var prompt = try PromptLoader.load(path: path, replacements: replacements)
        // Strip recording_time field from prompt when no value is provided,
        // so the model doesn't output an empty or hallucinated time.
        if recordingTime == nil || recordingTime!.isEmpty {
            prompt = prompt.components(separatedBy: CharacterSet.newlines)
                .filter { line in
                    let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                    let yamlField = trimmedLine.hasPrefix("- ")
                        ? String(trimmedLine.dropFirst(2))
                        : trimmedLine
                    return !yamlField.hasPrefix("recording_time:")
                }
                .joined(separator: "\n")
        }
        return prompt
    }

    static func userMessage(logText: String) -> String {
        PromptXML.document([
            PromptXML.element("log_entry", logText),
        ])
    }

}

import Foundation

public enum Cleanup {

    public static let defaultPromptPath = "prompts/cleanup.md"

    public typealias CommandOperation = @Sendable (
        _ transcript: String,
        _ config: CaptainsLogConfig,
        _ promptPath: String
    ) async throws -> String

    public static func cleanup(
        transcript: String,
        container: ModelContainer,
        config: CaptainsLogConfig = CaptainsLogConfig.load(),
        promptPath: String = defaultPromptPath
    ) async throws -> String {
        let renderedPrompt = try renderedPrompt(transcript: transcript, config: config, promptPath: promptPath)

        Logger.llm.info("Running cleanup...")
        let start = Date()

        let result = try await LLM.generate(
            container: container,
            systemPrompt: renderedPrompt.systemPrompt,
            userMessage: renderedPrompt.userMessage
        )

        let elapsed = Date().timeIntervalSince(start)
        Logger.llm.info("Cleanup done in \(String(format: "%.1f", elapsed))s")

        return result
    }

    public static func renderedPrompt(
        transcript: String,
        config: CaptainsLogConfig = CaptainsLogConfig.load(),
        promptPath: String = defaultPromptPath
    ) throws -> RenderedPrompt {
        RenderedPrompt(
            systemPrompt: try loadPrompt(from: promptPath, config: config),
            userMessage: userMessage(transcript: transcript)
        )
    }

    /// Runs the file and output part of the cleanup CLI command with an injectable inference operation.
    public static func runCommand(
        inputPath: String,
        outputPath: String? = nil,
        promptPath: String = defaultPromptPath,
        config: CaptainsLogConfig = CaptainsLogConfig.load(),
        printPrompt: Bool = false,
        operation: CommandOperation
    ) async throws -> String? {
        let transcript = try String(contentsOfFile: inputPath, encoding: .utf8)
        let renderedPrompt = try renderedPrompt(transcript: transcript, config: config, promptPath: promptPath)
        if printPrompt {
            print(PromptDebug.render(renderedPrompt))
            return nil
        }

        let result = try await operation(transcript, config, promptPath)
        let resolvedOutputPath = outputPath ?? URL(fileURLWithPath: inputPath).lastPathComponent
        try FileSystemGuard.writeText(result, to: resolvedOutputPath)
        print("Saved to \(resolvedOutputPath)")
        return result
    }

    static func loadPrompt(from path: String, config: CaptainsLogConfig = CaptainsLogConfig.load()) throws -> String {
        try PromptLoader.load(
            path: path,
            replacements: [
                "{CLEANUP_SPEAKER_CONTEXT_SECTION}": speakerContextSection(config.readPersonalInfo()),
                "{CLEANUP_NAME_CORRECTIONS_SECTION}": nameCorrectionsSection(config.readCorrections()),
            ]
        )
    }

    static func speakerContextSection(_ text: String?) -> String {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        return PromptXML.element("speaker_context", text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func nameCorrectionsSection(_ text: String?) -> String {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        return PromptXML.element(
            "name_corrections",
            """
            Apply these corrections when the transcript contains obvious misspellings of these names or terms:

            \(text.trimmingCharacters(in: .whitespacesAndNewlines))
            """
        )
    }

    static func userMessage(transcript: String) -> String {
        PromptXML.document([
            PromptXML.element("transcript", transcript),
        ])
    }
}

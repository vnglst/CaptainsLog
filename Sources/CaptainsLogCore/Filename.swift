import Foundation

public enum Filename {

    public static let defaultPromptPath = "prompts/filename.md"
    public static let defaultMaxTokens = 0
    public static let defaultTemperature: Float = 0.3

    public typealias CommandOperation = @Sendable (
        _ logText: String,
        _ date: String,
        _ promptPath: String
    ) async throws -> String

    public static func generateFilename(
        logText: String,
        date: String,
        container: ModelContainer,
        promptPath: String = defaultPromptPath
    ) async throws -> String {
        let renderedPrompt = try renderedPrompt(logText: logText, date: date, promptPath: promptPath)

        Logger.llm.info("Generating filename...")
        let start = Date()

        let result = try await LLM.generate(
            container: container,
            systemPrompt: renderedPrompt.systemPrompt,
            userMessage: renderedPrompt.userMessage,
            maxTokens: defaultMaxTokens,
            temperature: defaultTemperature
        )

        let elapsed = Date().timeIntervalSince(start)
        Logger.llm.info("Filename generated in \(String(format: "%.1f", elapsed))s")

        return cleanFilename(result)
    }

    public static func renderedPrompt(
        logText: String,
        date: String,
        promptPath: String = defaultPromptPath
    ) throws -> RenderedPrompt {
        RenderedPrompt(
            systemPrompt: try loadPrompt(from: promptPath, date: date),
            userMessage: userMessage(logText: logText)
        )
    }

    /// Runs the file and output part of the filename CLI command with an injectable inference operation.
    public static func runCommand(
        inputPath: String,
        date: String,
        promptPath: String = defaultPromptPath,
        printPrompt: Bool = false,
        operation: CommandOperation
    ) async throws -> String? {
        let logText = try String(contentsOfFile: inputPath, encoding: .utf8)
        let renderedPrompt = try renderedPrompt(logText: logText, date: date, promptPath: promptPath)
        if printPrompt {
            print(PromptDebug.render(renderedPrompt))
            return nil
        }

        let filename = try await operation(logText, date, promptPath)
        print(filename)
        return filename
    }

    static func loadPrompt(from path: String, date: String) throws -> String {
        try PromptLoader.load(path: path, replacements: ["{date}": date])
    }

    static func userMessage(logText: String) -> String {
        PromptXML.document([
            PromptXML.element("log_entry", logText),
        ])
    }

    static func cleanFilename(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        name = name.replacingOccurrences(of: "`", with: "")
        if !name.hasSuffix(".md") {
            name += ".md"
        }
        return name
    }
}

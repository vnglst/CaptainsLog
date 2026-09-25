import Foundation

public struct RenderedPrompt: Sendable {
    public let systemPrompt: String
    public let userMessage: String

    public init(systemPrompt: String, userMessage: String) {
        self.systemPrompt = systemPrompt
        self.userMessage = userMessage
    }
}

public enum PromptDebug {
    public static func render(_ prompt: RenderedPrompt) -> String {
        PromptXML.document([
            PromptXML.element("system_prompt", prompt.systemPrompt),
            PromptXML.element("user_prompt", prompt.userMessage),
        ])
    }
}

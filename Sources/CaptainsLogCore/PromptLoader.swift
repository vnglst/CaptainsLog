import Foundation

public enum PromptLoader {
    public static func load(
        path: String,
        replacements: [String: String] = [:]
    ) throws -> String {
        guard let url = resolvePromptPath(path) else {
            throw Pipeline.PipelineError.promptNotFound(stage: "PromptLoader", path: path)
        }
        var prompt = try String(contentsOf: url, encoding: .utf8)
        for (key, value) in replacements {
            prompt = prompt.replacingOccurrences(of: key, with: value)
        }
        return prompt
    }
}

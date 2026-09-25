import Foundation

enum PromptXML {
    static func element(_ name: String, _ content: String) -> String {
        """
        <\(name)>
        \(content)
        </\(name)>
        """
    }

    static func optionalElement(_ name: String, _ content: String?) -> String? {
        guard let content else { return nil }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return element(name, trimmed)
    }

    static func document(_ sections: [String?]) -> String {
        sections
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}

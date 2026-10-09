import Foundation

/// Keeps the CLI's Markdown format and preserves lines that are not spelling pairs.
public struct CorrectionDocument {
    public struct Entry: Identifiable {
        public let id: UUID
        public var misspelling: String
        public var spelling: String
        fileprivate var original: String
        fileprivate var originalMisspelling: String
        fileprivate var originalSpelling: String

        fileprivate var text: String {
            if misspelling == originalMisspelling && spelling == originalSpelling { return original }
            return "\(misspelling) → \(spelling)"
        }
    }

    private enum Line {
        case entry(UUID)
        case preserved(String)
    }
    public var entries: [Entry] = []
    private var lines: [Line] = []

    public init(_ text: String) {
        guard !text.isEmpty else { return }
        for line in text.components(separatedBy: "\n") {
            let separator = line.range(of: "→") ?? line.range(of: "->")
            if let separator {
                let wrong = String(line[..<separator.lowerBound]).trimmingCharacters(in: .whitespaces)
                let right = String(line[separator.upperBound...]).trimmingCharacters(in: .whitespaces)
                let entry = Entry(id: UUID(), misspelling: wrong, spelling: right,
                                  original: line, originalMisspelling: wrong, originalSpelling: right)
                entries.append(entry)
                lines.append(.entry(entry.id))
            } else {
                lines.append(.preserved(line))
            }
        }
    }

    public var text: String {
        lines.compactMap { line in
            switch line {
            case .preserved(let text): return text
            case .entry(let id): return entries.first { $0.id == id }?.text
            }
        }.joined(separator: "\n")
    }

    public var preservedText: String {
        lines.compactMap { line in
            if case .preserved(let text) = line { return text }
            return nil
        }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public mutating func add() {
        let entry = Entry(id: UUID(), misspelling: "", spelling: "", original: " → ",
                          originalMisspelling: "", originalSpelling: "")
        entries.append(entry)
        // Keep a trailing newline at the end, rather than between new entries.
        if let last = lines.last, case .preserved("") = last {
            lines.insert(.entry(entry.id), at: lines.count - 1)
        } else {
            lines.append(.entry(entry.id))
        }
    }

    public mutating func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
        lines.removeAll { if case .entry(let entryID) = $0 { return entryID == id }; return false }
    }
}

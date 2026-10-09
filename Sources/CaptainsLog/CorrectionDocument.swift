import Foundation

/// Keeps spelling pairs in the CLI's Markdown format, discarding legacy notes.
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

    public var entries: [Entry] = []

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
            }
        }
    }

    public var text: String {
        entries.map(\.text).joined(separator: "\n")
    }

    public mutating func add() {
        let entry = Entry(id: UUID(), misspelling: "", spelling: "", original: " → ",
                          originalMisspelling: "", originalSpelling: "")
        entries.append(entry)
    }

    public mutating func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
    }
}

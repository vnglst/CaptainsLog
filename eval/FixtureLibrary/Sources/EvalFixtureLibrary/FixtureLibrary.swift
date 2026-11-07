import Foundation

/// Copies the canonical evaluation library into writable, isolated demo/UI storage.
public enum EvalFixtureLibrary {
    private struct Library: Decodable {
        let context: Context?
        let completed: [Completed]
        let pending: [Pending]
    }

    private struct Context: Decodable {
        let personalInfo: String
        let corrections: String
    }

    private struct Completed: Decodable {
        let stem: String
        let slug: String?
        let slugFile: String?
        let category: String
        let transcript: String
        let cleaned: String
        let enriched: String
        let audio: String?
    }

    private struct Pending: Decodable {
        let stem: String
        let transcript: String?
        let audio: String?
    }

    /// Existing runtime files are retained so edits and processing survive relaunches.
    public static func prepare(evalRoot: URL, dataRoot: URL) throws {
        let fm = FileManager.default
        func component(_ value: String) throws -> String {
            guard !value.isEmpty, value != ".", value != "..",
                  !value.contains("/"), !value.contains("\\") else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return value
        }
        func source(_ relative: String) throws -> URL {
            guard !relative.hasPrefix("/"),
                  relative.split(separator: "/").allSatisfy({ $0 != ".." && $0 != "." }) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return evalRoot.appendingPathComponent(relative)
        }
        func read(_ relative: String) throws -> String {
            try String(contentsOf: source(relative), encoding: .utf8)
        }
        func write(_ relative: String, _ data: Data) throws {
            let destination = dataRoot.appendingPathComponent(relative)
            guard !fm.fileExists(atPath: destination.path) else { return }
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: destination, options: .atomic)
        }
        func text(_ relative: String, _ content: String) throws {
            try write(relative, Data(content.utf8))
        }
        func audio(_ relative: String, _ stem: String) throws {
            let original = try source(relative)
            let ext = try component(original.pathExtension)
            let destination = dataRoot.appendingPathComponent("audio/\(stem).\(ext)")
            guard !fm.fileExists(atPath: destination.path) else { return }
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: original, to: destination)
        }

        let library = try JSONDecoder().decode(Library.self, from: Data(contentsOf: source("demo-library.json")))
        if let context = library.context {
            try text("context/personal_info.md", read(context.personalInfo))
            try text("context/corrections.md", read(context.corrections))
        }
        for entry in library.completed {
            let stem = try component(entry.stem)
            let category = try component(entry.category)
            let rawSlug: String
            if let slug = entry.slug {
                rawSlug = slug
            } else if let file = entry.slugFile {
                rawSlug = try read(file).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let slug = try component(rawSlug.hasSuffix(".md") ? String(rawSlug.dropLast(3)) : rawSlug)
            let cleaned = try read(entry.cleaned)
            try text(".pipeline/01-transcribed/\(stem).md", read(entry.transcript))
            try text(".pipeline/02-logs/\(stem).md", cleaned)
            try write(".pipeline/03-category/\(stem).json", JSONSerialization.data(withJSONObject: ["sourceStem": stem, "category": category]))
            try text(".pipeline/04-rename/\(stem).slug.txt", slug + "\n")
            try text(".pipeline/04-rename/\(slug).md", cleaned)
            try text("logs/\(category.replacingOccurrences(of: "_", with: "-"))/\(slug).md", read(entry.enriched) + cleaned)
            if let original = entry.audio { try audio(original, stem) }
        }
        for entry in library.pending {
            let stem = try component(entry.stem)
            if let transcript = entry.transcript {
                try text(".pipeline/01-transcribed/\(stem).md", read(transcript))
            }
            if let original = entry.audio { try audio(original, stem) }
        }
    }
}

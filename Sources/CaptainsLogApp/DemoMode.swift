#if DEBUG
import CaptainsLogCore
import Foundation

/// Seeds a writable, ignored copy of the repository's synthetic TNG notes.
/// Explicit CAPTAINS_LOG_CONFIG_PATH remains available for isolated integration runs.
enum DemoMode {
    static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let runtime = repository.appendingPathComponent("tmp/demo-runtime", isDirectory: true)

    static func prepare() throws {
        let fm = FileManager.default
        let source = repository.appendingPathComponent("demo/entries", isDirectory: true)
        let configURL = runtime.appendingPathComponent("config.json")
        let dataURL = runtime.appendingPathComponent("data", isDirectory: true)
        guard fm.fileExists(atPath: source.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try fm.createDirectory(at: dataURL, withIntermediateDirectories: true)
        setenv("CAPTAINS_LOG_CONFIG_PATH", configURL.path, 1)
        setenv("CAPTAINSLOG_DEMO_MODE", "1", 1)

        var config = CaptainsLogConfig.load()
        // Enforce the demo directory on every launch, even if its local config
        // was edited or a previous run was interrupted during a settings save.
        config.dataDir = dataURL.path
        try config.save()
        let categoryFolders: [(String, Categorize.Category)] = [
            ("personal", .personal),
            ("professional", .professional),
            ("side-project", .sideProject),
        ]
        for (folder, category) in categoryFolders {
            let folderURL = source.appendingPathComponent(folder)
            let files = try fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "md" }
            for file in files {
                let slug = file.deletingPathExtension().lastPathComponent
                guard slug.count > 16, slug[slug.index(slug.startIndex, offsetBy: 15)] == "-" else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                let stem = String(slug.prefix(15))
                let content = try String(contentsOf: file, encoding: .utf8)
                guard let bodyStart = content.range(of: "\n---\n") else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                let body = String(content[bodyStart.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
                let artifacts: [(String, String)] = [
                    (".pipeline/01-transcribed/\(stem).md", body),
                    (".pipeline/02-logs/\(stem).md", body),
                    (".pipeline/04-rename/\(slug).md", body),
                    (".pipeline/04-rename/\(stem).slug.txt", slug + "\n"),
                    ("logs/\(folder)/\(slug).md", content),
                ]
                for (relativePath, value) in artifacts {
                    let destination = dataURL.appendingPathComponent(relativePath)
                    if !fm.fileExists(atPath: destination.path) {
                        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try value.write(to: destination, atomically: true, encoding: .utf8)
                    }
                }
                let manifestURL = dataURL.appendingPathComponent(".pipeline/03-category/\(stem).json")
                if !fm.fileExists(atPath: manifestURL.path) {
                    try fm.createDirectory(at: manifestURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    let manifest = Categorize.Manifest(sourceStem: stem, category: category)
                    try JSONEncoder().encode(manifest).write(to: manifestURL)
                }
            }
        }
        let audioSource = repository.appendingPathComponent("demo/audio")
        let audioDestination = dataURL.appendingPathComponent("audio")
        try fm.createDirectory(at: audioDestination, withIntermediateDirectories: true)
        for file in try fm.contentsOfDirectory(at: audioSource, includingPropertiesForKeys: nil)
            where file.pathExtension == "m4a" {
            let destination = audioDestination.appendingPathComponent(file.lastPathComponent)
            if !fm.fileExists(atPath: destination.path) {
                try fm.copyItem(at: file, to: destination)
            }
        }
    }
}
#endif

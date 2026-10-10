import Darwin
import Foundation

/// A durable, sequential batch. Each recording is reset only immediately before
/// it runs; successful recordings are skipped when an interrupted batch resumes.
public enum Reprocessing {
    public struct Item: Codable, Sendable {
        public let stem: String
        public let slug: String?
    }

    public struct Run: Codable, Sendable {
        public let id: UUID
        public let items: [Item]
        public var completed: Set<String> = []
        public var failures: [String: String] = [:]
        public var remaining: Int { items.count - completed.count }
    }

    public typealias Resume = @Sendable (String, String, Pipeline.Stage?, (@Sendable (Pipeline.Progress) -> Void)?) async throws -> Pipeline.Result

    public static func manifestURL(dataDir: String) -> URL {
        URL(fileURLWithPath: dataDir).appendingPathComponent(".pipeline/reprocessing.json")
    }

    public static func savedRun(dataDir: String) -> Run? {
        guard let data = try? Data(contentsOf: manifestURL(dataDir: dataDir)) else { return nil }
        return try? JSONDecoder().decode(Run.self, from: data)
    }

    public static func audioItems(dataDir: String) throws -> [Item] {
        let directory = URL(fileURLWithPath: dataDir).appendingPathComponent("audio")
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
        let extensions = Set(["m4a", "mov", "qt", "qta", "wav", "mp3"])
        let stems = Set(try urls.filter {
            guard extensions.contains($0.pathExtension.lowercased()) else { return false }
            return try $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true
        }.map { $0.deletingPathExtension().lastPathComponent })
        let listings = Dictionary(uniqueKeysWithValues: Pipeline.listEntries(dataDir: dataDir).map { ($0.stem, $0) })
        return stems.sorted().map { Item(stem: $0, slug: listings[$0]?.slug) }
    }

    public static func run(
        dataDir: String,
        resumeSaved: Bool = false,
        resume: @escaping Resume,
        onUpdate: @Sendable (Run, String?) -> Void = { _, _ in },
        progress: (@Sendable (Pipeline.Progress) -> Void)? = nil
    ) async throws -> Run {
        let fm = FileManager.default
        let manifest = manifestURL(dataDir: dataDir)
        try fm.createDirectory(at: manifest.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = open(manifest.appendingPathExtension("lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw failure("Cannot open the reprocessing lock.") }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { throw failure("Another reprocessing run is already active.") }
        defer { flock(descriptor, LOCK_UN) }

        var run: Run
        if resumeSaved {
            // Decode explicitly so a corrupt checkpoint cannot silently start over.
            run = try JSONDecoder().decode(Run.self, from: Data(contentsOf: manifest))
        } else {
            run = Run(id: UUID(), items: try audioItems(dataDir: dataDir))
        }
        func save(_ run: Run) throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(run).write(to: manifest, options: .atomic)
        }
        try save(run)
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled], reason: "Reprocessing CaptainsLog recordings")
        defer { ProcessInfo.processInfo.endActivity(activity) }

        for item in run.items where !run.completed.contains(item.stem) {
            try Task.checkCancellation()
            onUpdate(run, item.stem)
            do {
                // Retain previous generated files before replacement, including
                // user edits, and never overwrite a backup on retry.
                let backup = manifest.deletingLastPathComponent()
                    .appendingPathComponent("reprocessing-backups/\(run.id.uuidString)/\(item.stem)")
                let paths = Pipeline.reprocessingCandidatePaths(stem: item.stem, slug: item.slug, dataDir: dataDir)
                for path in paths where fm.fileExists(atPath: path) {
                    let relative = String(path.dropFirst(URL(fileURLWithPath: dataDir).path.count + 1))
                    let destination = backup.appendingPathComponent(relative)
                    if !fm.fileExists(atPath: destination.path) {
                        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try fm.copyItem(atPath: path, toPath: destination.path)
                    }
                }
                try Pipeline.resetForReprocessing(stem: item.stem, slug: item.slug, dataDir: dataDir)
                _ = try await resume(item.stem, dataDir, .transcribing, progress)
                try Task.checkCancellation()
                run.completed.insert(item.stem)
                run.failures.removeValue(forKey: item.stem)
            } catch {
                if Task.isCancelled || error is CancellationError { throw CancellationError() }
                run.failures[item.stem] = error.localizedDescription
            }
            try save(run)
            onUpdate(run, nil)
        }
        return run
    }

    private static func failure(_ message: String) -> NSError {
        NSError(domain: "Reprocessing", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

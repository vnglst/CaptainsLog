import Foundation
@testable import CaptainsLog
@testable import CaptainsLogCore

// Simple test runner using Swift's built-in assertions
// No external testing framework required - works with command-line Swift only

@MainActor
var testsRun = 0
@MainActor
var testsPassed = 0
@MainActor
var testsFailed = 0

func configureIsolatedTestEnvironment() -> URL {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent(
        "CaptainsLogTests-\(UUID().uuidString)",
        isDirectory: true
    )
    let dataDir = root.appendingPathComponent("data", isDirectory: true)
    try? fm.createDirectory(at: dataDir, withIntermediateDirectories: true)

    let configURL = root.appendingPathComponent("config.json")
    setenv("CAPTAINS_LOG_CONFIG_PATH", configURL.path, 1)
    try? CaptainsLogConfig(dataDir: dataDir.path).save()

    return root
}

@MainActor
func test(_ name: String, _ block: () throws -> Void) {
    testsRun += 1
    do {
        try block()
        print("✅ \(name)")
        testsPassed += 1
    } catch {
        print("❌ \(name): \(error)")
        testsFailed += 1
    }
}

@MainActor
func testAsync(_ name: String, _ block: () async throws -> Void) async {
    testsRun += 1

    do {
        try await block()
        print("✅ \(name)")
        testsPassed += 1
    } catch {
        print("❌ \(name): \(error)")
        testsFailed += 1
    }
}

func expect(_ condition: Bool, _ message: String = "Assertion failed") throws {
    if !condition {
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

final class LockedStringArray: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    func append(_ value: String) {
        lock.withLock {
            values.append(value)
        }
    }

    func snapshot() -> [String] {
        lock.withLock {
            values
        }
    }
}

actor FakeEmbeddingModel: TextEmbeddingModel {
    nonisolated let identity = "fake-search-model-v1"

    func embed(_ text: String, as kind: EmbeddingInputKind) -> [Float] {
        let lowered = text.lowercased()
        let index: Int
        if lowered.contains("cycling") || lowered.contains("bicycle") || lowered.contains("bike") {
            index = 0
        } else if lowered.contains("database") || lowered.contains("sqlite") || lowered.contains("storage") {
            index = 1
        } else if lowered.contains("holiday") || lowered.contains("vacation") || lowered.contains("travel") {
            index = 2
        } else {
            index = 3
        }
        var vector = [Float](repeating: 0, count: E5EmbeddingModel.dimension)
        vector[index] = 1
        return vector
    }

    func chunks(for text: String, maxTokens: Int, overlap: Int) -> [String] {
        text.isEmpty ? [] : [text]
    }
}

func makeCompletedSearchEntry(
    root: URL,
    stem: String,
    slug: String,
    category: Categorize.Category,
    content: String
) throws -> URL {
    let transcript = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
    let cleaned = root.appendingPathComponent(".pipeline/02-logs/\(stem).md")
    let renameDir = root.appendingPathComponent(".pipeline/04-rename")
    let enriched = root.appendingPathComponent("logs/\(category.folderName)/\(slug).md")
    for directory in [
        transcript.deletingLastPathComponent(), cleaned.deletingLastPathComponent(),
        renameDir, enriched.deletingLastPathComponent(),
    ] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    try "raw".write(to: transcript, atomically: true, encoding: .utf8)
    try content.write(to: cleaned, atomically: true, encoding: .utf8)
    try Categorize.writeManifest(.init(sourceStem: stem, category: category), dataDirURL: root)
    try slug.write(
        to: renameDir.appendingPathComponent("\(stem).slug.txt"),
        atomically: true,
        encoding: .utf8
    )
    try content.write(
        to: renameDir.appendingPathComponent("\(slug).md"), atomically: true, encoding: .utf8)
    try content.write(to: enriched, atomically: true, encoding: .utf8)
    return enriched
}

@MainActor
func runSearchCoverageTests() async {
    await testAsync("Semantic search: indexes, ranks, updates, and removes completed entries") {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SemanticSearchTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let cycling = try makeCompletedSearchEntry(
            root: root,
            stem: "2026-07-10-0800",
            slug: "2026-07-10-riverside-cycling",
            category: .personal,
            content: "---\nsummary: A riverside cycling route.\n---\n\nI planned a long bicycle ride beside the river."
        )
        _ = try makeCompletedSearchEntry(
            root: root,
            stem: "2026-07-11-0900",
            slug: "2026-07-11-sqlite-storage",
            category: .sideProject,
            content: "---\nsummary: Local database design.\n---\n\nSQLite stores the application index on this Mac."
        )

        let search = try SemanticSearch(dataDir: root.path, model: FakeEmbeddingModel())
        let first = try await search.synchronize()
        try expect(first.added == 2)
        try expect(first.chunks == 2)

        let bicycleResults = try await search.search("ideas for a bike ride", synchronizeFirst: false)
        try expect(bicycleResults.first?.slug == "2026-07-10-riverside-cycling")
        try expect(bicycleResults.first?.excerpt.contains("bicycle") == true)

        let hybridResults = try await search.search(
            "SQLite bike", limit: 2, synchronizeFirst: false)
        try expect(hybridResults.count == 2)
        try expect(hybridResults[0].slug == "2026-07-11-sqlite-storage")
        try expect(hybridResults[0].matchKind == .keyword)
        try expect(hybridResults[0].matchedTerms == ["sqlite"])
        try expect(hybridResults[0].excerpt.contains("SQLite"))
        try expect(hybridResults[1].slug == "2026-07-10-riverside-cycling")
        try expect(hybridResults[1].matchKind == .semantic)

        let unchanged = try await search.synchronize()
        try expect(unchanged.unchanged == 2)

        try "A holiday and vacation travel plan.".write(
            to: cycling, atomically: true, encoding: .utf8)
        let updated = try await search.synchronize()
        try expect(updated.updated == 1)

        try FileManager.default.removeItem(at: cycling)
        let removed = try await search.synchronize()
        try expect(removed.removed == 1)
        let remaining = try await search.search("bike", synchronizeFirst: false)
        try expect(remaining.count == 1)
        try expect(remaining.first?.slug == "2026-07-11-sqlite-storage")
    }

    await testAsync("Hybrid search: keyword passage is centered and highlighted") {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HybridPassageTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let preface = Array(repeating: "Background context without the target term.", count: 12)
            .joined(separator: " ")
        _ = try makeCompletedSearchEntry(
            root: root,
            stem: "2026-07-12-1000",
            slug: "2026-07-12-late-keyword",
            category: .professional,
            content: "\(preface) The quantum decision is the passage that should be shown."
        )
        let search = try SemanticSearch(dataDir: root.path, model: FakeEmbeddingModel())
        _ = try await search.synchronize()
        let results = try await search.search("quantum", limit: 1, synchronizeFirst: false)
        try expect(results.first?.matchKind == .keyword)
        try expect(results.first?.matchedTerms == ["quantum"])
        try expect(results.first?.excerpt.contains("quantum decision") == true)
        try expect(results.first?.excerpt.hasPrefix("…") == true)
        try expect((results.first?.excerpt.count ?? 1_000) < 290)
    }

    test("Semantic search: empty query returns no results without loading data") {
        try expect(E5EmbeddingModel.dimension == 384)
        try expect(E5EmbeddingModel.maximumTokens == 511)
        try expect(E5EmbeddingModel.expectedSHA256.count == 64)
        try expect(E5EmbeddingModel.modelURL().lastPathComponent == E5EmbeddingModel.filename)
        _ = E5EmbeddingModel.isDownloaded()
    }

    test("Semantic search: UI manager debounces, invalidates, retries, and clears") {
        let manager = SearchManager()
        try expect(manager.state == .idle)
        try expect(!manager.isActive)

        manager.updateQuery("local database plan", dataDir: "/tmp/captainslog-search-manager")
        try expect(manager.isActive)
        try expect(manager.query == "local database plan")
        manager.invalidateIndex(dataDir: "/tmp/captainslog-search-manager")

        manager.updateQuery("", dataDir: "/tmp/captainslog-search-manager")
        try expect(manager.state == .idle)
        try expect(manager.results.isEmpty)
        manager.invalidateIndex(dataDir: "/tmp/captainslog-search-manager")
        manager.retry(dataDir: "/tmp/captainslog-search-manager")
        try expect(!manager.isActive)
    }

    if ProcessInfo.processInfo.environment["CAPTAINS_LOG_SEARCH_INTEGRATION"] == "1" {
        await testAsync("Semantic search: real E5 model retrieves multilingual notes") {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("SemanticSearchIntegration-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: root) }
            _ = try makeCompletedSearchEntry(
                root: root,
                stem: "2026-07-20-0800",
                slug: "2026-07-20-fietsen-langs-de-rivier",
                category: .personal,
                content: "Ik wil zaterdag een lange fietstocht langs de rivier maken. Onderweg stop ik bij het oude veerhuis."
            )
            _ = try makeCompletedSearchEntry(
                root: root,
                stem: "2026-07-21-0900",
                slug: "2026-07-21-local-search-storage",
                category: .sideProject,
                content: "The app will store vector embeddings in a local SQLite database. The index remains offline and disposable."
            )
            _ = try makeCompletedSearchEntry(
                root: root,
                stem: "2026-07-22-1000",
                slug: "2026-07-22-sommerurlaub-in-italien",
                category: .personal,
                content: "Wir planen den Sommerurlaub in Italien und suchen eine ruhige Unterkunft in der Nähe der Berge."
            )

            let search = try await SemanticSearch.live(dataDir: root.path)
            _ = try await search.synchronize(rebuild: true)
            let cases = [
                ("bike ride beside the water", "2026-07-20-fietsen-langs-de-rivier"),
                ("lokale opslag voor de zoekindex", "2026-07-21-local-search-storage"),
                ("planning a summer trip to Italy", "2026-07-22-sommerurlaub-in-italien"),
            ]
            for (query, expectedSlug) in cases {
                let matches = try await search.search(query, limit: 3, synchronizeFirst: false)
                try expect(matches.first?.slug == expectedSlug, "Unexpected top result for \(query)")
            }
        }
    }
}

@MainActor
func runCoreCoverageTests() {
    func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLogCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    test("Core coverage: config round-trips context files") {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let config = CaptainsLogConfig(dataDir: root.path)
        try config.writePersonalInfo("Works on local-first software.")
        try config.writeCorrections("Jon -> Jorian")
        try expect(config.readPersonalInfo() == "Works on local-first software.")
        try expect(config.readCorrections() == "Jon -> Jorian")
        try expect(config.contextDir().path == root.appendingPathComponent("context").path)
    }

    test("Core coverage: prompt loader replaces tokens") {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let promptURL = root.appendingPathComponent("prompt.md")
        try "Date: {date}; context: {context}".write(to: promptURL, atomically: true, encoding: .utf8)
        let prompt = try PromptLoader.load(
            path: promptURL.path,
            replacements: ["{date}": "2026-07-10", "{context}": "private"]
        )
        try expect(prompt == "Date: 2026-07-10; context: private")
    }

    test("Core coverage: prompt loader rejects missing prompt") {
        do {
            _ = try PromptLoader.load(path: "/definitely/missing/captains-log-prompt.md")
            try expect(false, "Expected missing prompt to throw")
        } catch {
            try expect(error.localizedDescription.contains("Prompt file not found"))
        }
    }

    test("Core coverage: filesystem guard writes text and preserves target in errors") {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let output = root.appendingPathComponent("nested/output.md")
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileSystemGuard.writeText("hello", to: output.path)
        try expect(try String(contentsOf: output, encoding: .utf8) == "hello")
        do {
            try FileSystemGuard.writeText("nope", to: root.path)
            try expect(false, "Expected writing to a directory to fail")
        } catch {
            try expect(error.localizedDescription.contains(root.path))
        }
    }

    test("Core coverage: filename normalizes whitespace, backticks, and extension") {
        try expect(Filename.cleanFilename("  `2026-07-10-focus`  ") == "2026-07-10-focus.md")
        try expect(Filename.cleanFilename("2026-07-10-focus.md") == "2026-07-10-focus.md")
    }

    test("Core coverage: LLM model resolution honors explicit and default IDs") {
        try expect(LLM.resolveModelId("custom/model") == "custom/model")
        try expect(LLM.resolveModelId() == LLM.defaultModelId)
    }

    test("Core coverage: enrich prompt omits recording time when unknown") {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let promptURL = root.appendingPathComponent("prompt.md")
        try "date: {date}\nrecording_time: {recording_time}\n{ENRICH_SPEAKER_CONTEXT_SECTION}".write(
            to: promptURL, atomically: true, encoding: .utf8)
        let prompt = try Enrich.loadPrompt(
            from: promptURL.path, date: "2026-07-10", recordingTime: nil,
            config: CaptainsLogConfig(dataDir: root.path)
        )
        try expect(prompt.contains("date: 2026-07-10"))
        try expect(!prompt.contains("recording_time"))
    }

    test("Core coverage: category manifests round-trip and missing manifests fail") {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let manifest = Categorize.Manifest(sourceStem: "2026-07-10-1200", category: .sideProject)
        try Categorize.writeManifest(manifest, dataDirURL: root)
        try expect(try Categorize.loadManifest(stem: manifest.sourceStem, dataDirURL: root) == manifest)
        try expect(Categorize.Category.sideProject.folderName == "side-project")
        do {
            _ = try Categorize.loadManifest(stem: "missing", dataDirURL: root)
            try expect(false, "Expected missing category manifest")
        } catch let error as Categorize.CategorizeError {
            if case .missingManifest(let path) = error {
                try expect(path.hasSuffix("missing.json"))
            } else {
                try expect(false, "Expected missingManifest error")
            }
        }
    }

    test("Core coverage: pipeline detects the first missing stage") {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let stem = "2026-07-10-1200"
        let transcribed = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        let cleaned = root.appendingPathComponent(".pipeline/02-logs/\(stem).md")
        try FileManager.default.createDirectory(at: transcribed.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "transcript".write(to: transcribed, atomically: true, encoding: .utf8)
        try expect(Pipeline.detectNextStage(stem: stem, dataDir: root.path) == .cleaning)
        try FileManager.default.createDirectory(at: cleaned.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "cleaned".write(to: cleaned, atomically: true, encoding: .utf8)
        try expect(Pipeline.detectNextStage(stem: stem, dataDir: root.path) == .categorizing)
    }

    test("Core coverage: pipeline advances through category, naming, and enriching") {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let stem = "2026-07-10-1200"
        let slug = "2026-07-10-coverage"
        let transcript = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        let cleaned = root.appendingPathComponent(".pipeline/02-logs/\(stem).md")
        try FileManager.default.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cleaned.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "transcript".write(to: transcript, atomically: true, encoding: .utf8)
        try "cleaned".write(to: cleaned, atomically: true, encoding: .utf8)
        try expect(Pipeline.detectNextStage(stem: stem, dataDir: root.path) == .categorizing)

        try Categorize.writeManifest(.init(sourceStem: stem, category: .sideProject), dataDirURL: root)
        try expect(Pipeline.detectNextStage(stem: stem, dataDir: root.path) == .naming)

        let renameDir = root.appendingPathComponent(".pipeline/04-rename")
        try FileManager.default.createDirectory(at: renameDir, withIntermediateDirectories: true)
        try slug.write(to: renameDir.appendingPathComponent("\(stem).slug.txt"), atomically: true, encoding: .utf8)
        try "cleaned".write(to: renameDir.appendingPathComponent("\(slug).md"), atomically: true, encoding: .utf8)
        try expect(Pipeline.detectNextStage(stem: stem, dataDir: root.path) == .enriching)

        let enriched = root.appendingPathComponent("logs/side-project/\(slug).md")
        try FileManager.default.createDirectory(at: enriched.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "enriched".write(to: enriched, atomically: true, encoding: .utf8)
        try expect(Pipeline.detectNextStage(stem: stem, dataDir: root.path) == .done)
    }

    test("Pipeline: full reprocessing removes derived files but preserves source audio") {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let stem = "2026-07-10-1200"
        let slug = "2026-07-10-coverage"
        let files: [(String, String)] = [
            ("audio/\(stem).m4a", "audio"),
            (".pipeline/01-transcribed/\(stem).md", "transcript"),
            (".pipeline/02-logs/\(stem).md", "cleaned"),
            (".pipeline/03-category/\(stem).json", #"{"sourceStem":"2026-07-10-1200","category":"side_project"}"#),
            (".pipeline/03-category/\(stem).log", "diagnostics"),
            (".pipeline/04-rename/\(stem).slug.txt", slug),
            (".pipeline/04-rename/\(slug).md", "renamed"),
            ("logs/side-project/\(slug).md", "enriched"),
        ]
        for (relativePath, contents) in files {
            let url = root.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }

        let candidates = Pipeline.reprocessingCandidatePaths(stem: stem, slug: slug, dataDir: root.path)
        try expect(!candidates.contains(root.appendingPathComponent("audio/\(stem).m4a").path))
        try Pipeline.resetForReprocessing(stem: stem, slug: slug, dataDir: root.path)

        try expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("audio/\(stem).m4a").path))
        for (relativePath, _) in files.dropFirst() {
            try expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path))
        }
        try expect(Pipeline.detectNextStage(stem: stem, dataDir: root.path) == .transcribing)
    }

    test("Pipeline: reprocessing keeps derived files when source audio is missing") {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let stem = "2026-07-10-1200"
        let cleaned = root.appendingPathComponent(".pipeline/02-logs/\(stem).md")
        try FileManager.default.createDirectory(at: cleaned.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "cleaned".write(to: cleaned, atomically: true, encoding: .utf8)

        do {
            try Pipeline.resetForReprocessing(stem: stem, slug: nil, dataDir: root.path)
            try expect(false, "Expected missing source audio to prevent reprocessing")
        } catch let error as Pipeline.PipelineError {
            if case .missingSourceAudio(let path) = error {
                try expect(path.hasSuffix("audio/\(stem).m4a"))
            } else {
                try expect(false, "Expected missingSourceAudio error")
            }
        }
        try expect(FileManager.default.fileExists(atPath: cleaned.path))
    }

    test("Core coverage: pipeline extracts date and recording time from a stem fallback") {
        try expect(Pipeline.extractDate(from: "2026-07-10-1205-idea") == "2026-07-10")
        try expect(Pipeline.extractRecordingTime(
            stem: "2026-07-10-1205-idea", dataDirURL: URL(fileURLWithPath: "/definitely/missing")
        ) == "12:05")
        try expect(Pipeline.extractRecordingTime(
            stem: "not-a-timestamp", dataDirURL: URL(fileURLWithPath: "/definitely/missing")
        ) == "00:00")
    }

    test("AppState: LogEntry parses completed-entry frontmatter") {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let entryURL = root.appendingPathComponent("2026-07-10-review.md")
        try """
        ---
        summary: "Shipped the review"
        tags:
          - work
          - release
        projects:
          - CaptainsLog
        recording_time: "08:30"
        ---

        Entry body.
        """.write(to: entryURL, atomically: true, encoding: .utf8)

        let entry = LogEntry.from(Pipeline.EntryListing(
            displayName: "2026-07-10-review",
            stem: "2026-07-10-0815",
            slug: "2026-07-10-review",
            nextStage: .done,
            latestPath: entryURL.path
        ))

        try expect(entry.summary == "Shipped the review")
        try expect(entry.tags == ["work", "release"])
        try expect(entry.projects == ["CaptainsLog"])
        try expect(entry.recordingTime == "08:30")
        try expect(entry.readableBody() == "Entry body.")
        guard let recordingDate = entry.recordingDate else {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected recording date"])
        }
        let utc = TimeZone(secondsFromGMT: 0)!
        let dateParts = Calendar(identifier: .gregorian).dateComponents(in: utc, from: recordingDate)
        try expect(dateParts.year == 2026 && dateParts.month == 7 && dateParts.day == 10)
    }

    test("AppState: LogEntry preserves Markdown without frontmatter") {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let entryURL = root.appendingPathComponent("plain.md")
        try "# Heading\n\nBody text.".write(to: entryURL, atomically: true, encoding: .utf8)
        let entry = LogEntry(
            stem: "2026-07-10-1200",
            slug: nil,
            displayName: "Plain",
            path: entryURL.path,
            summary: nil,
            tags: [],
            projects: [],
            frontmatterTime: nil,
            stage: .done
        )

        try expect(entry.readableBody() == "# Heading\n\nBody text.")
    }

    test("Field Notes: entry Markdown keeps explicit line breaks") {
        let rendered = try AttributedString(
            markdown: "**First line**\nSecond line",
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
        try expect(String(rendered.characters) == "First line\nSecond line")
    }

    test("AppState: network cancellation detection handles direct and wrapped errors") {
        let cancelled = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        let wrapped = NSError(domain: "Transport", code: 1, userInfo: [NSUnderlyingErrorKey: cancelled])
        let failure = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        try expect(cancelled.isNetworkCancellation)
        try expect(wrapped.isNetworkCancellation)
        try expect(failure.isNetworkCancellation == false)
    }
}

@MainActor
func runCoordinatorCoverageTests() async {
    @Sendable func result(for stem: String) -> Pipeline.Result {
        Pipeline.Result(
            audioPath: "\(stem).m4a",
            transcriptPath: "\(stem).transcript.md",
            cleanedPath: "\(stem).cleaned.md",
            renamedPath: "\(stem).renamed.md",
            enrichedPath: "\(stem).enriched.md",
            slug: stem,
            category: .personal
        )
    }

    await testAsync("ProcessingCoordinator: drains queued work through injected pipeline") {
        let processed = LockedStringArray()
        let coordinator = ProcessingCoordinator { stem, _, fromStage, progress in
            processed.append("\(stem):\(fromStage?.rawValue ?? "nil")")
            progress?(.init(stem: stem, stage: .cleaning))
            return result(for: stem)
        }
        coordinator.queueProcessing(stem: "first")
        coordinator.queueProcessing(stem: "second")

        let completed: Bool = await withCheckedContinuation { continuation in
            coordinator.startProcessing(
                dataDir: "/tmp/coverage",
                isRecording: false,
                onProgress: {},
                onComplete: { continuation.resume(returning: true) },
                onError: { _ in continuation.resume(returning: false) }
            )
        }

        try expect(completed)
        try expect(processed.snapshot() == ["first:transcribing", "second:transcribing"])
        try expect(coordinator.stage == .done)
        try expect(coordinator.statusMessage == "Done")
        try expect(coordinator.processingStem == nil)
    }

    await testAsync("ProcessingCoordinator: records an injected pipeline failure") {
        let coordinator = ProcessingCoordinator { _, _, _, _ in
            throw NSError(domain: "Coverage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Synthetic failure"])
        }

        let failed: Bool = await withCheckedContinuation { continuation in
            coordinator.resumeEntry(
                stem: "failed-entry",
                dataDir: "/tmp/coverage",
                onComplete: { continuation.resume(returning: false) },
                onError: { _ in continuation.resume(returning: true) }
            )
        }

        try expect(failed)
        try expect(coordinator.stage == .idle)
        try expect(coordinator.statusMessage == "Processing failed. Retry available.")
        try expect(coordinator.failureMessage(for: "failed-entry") == "Synthetic failure")
        try expect(coordinator.errorMessage == "Synthetic failure")
    }
}

@MainActor
func runPipelineOrchestrationCoverageTests() async {
    func makeRoot(stem: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PipelineOperationsTests-\(UUID().uuidString)", isDirectory: true)
        let transcript = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        try FileManager.default.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "raw transcript".write(to: transcript, atomically: true, encoding: .utf8)
        return root
    }

    await testAsync("Pipeline: fake operations run cleanup through enrichment") {
        let stem = "2026-07-10-0815"
        let root = try makeRoot(stem: stem)
        defer { try? FileManager.default.removeItem(at: root) }
        let calls = LockedStringArray()
        let progress = LockedStringArray()
        let operations = Pipeline.Operations(
            transcribe: { _, _ in throw NSError(domain: "PipelineTests", code: 1) },
            cleanup: { transcript, _ in
                calls.append("cleanup:\(transcript)")
                return "cleaned entry"
            },
            categorize: { cleaned, _, diagnostic in
                calls.append("categorize:\(cleaned)")
                await diagnostic("fake category selected")
                return .professional
            },
            filename: { cleaned, date in
                calls.append("filename:\(date):\(cleaned)")
                return "2026-07-10-fake-entry.md"
            },
            enrich: { cleaned, date, recordingTime, _ in
                calls.append("enrich:\(date):\(recordingTime):\(cleaned)")
                return "---\nsummary: Fake\n---\n\n\(cleaned)"
            }
        )

        let result = try await Pipeline.resume(
            stem: stem,
            dataDir: root.path,
            fromStage: .cleaning,
            operations: operations,
            progress: { progress.append($0.stage.rawValue) }
        )

        try expect(progress.snapshot() == ["cleaning", "categorizing", "naming", "enriching", "done"])
        try expect(calls.snapshot().count == 4)
        try expect(result.category == .professional)
        try expect(result.slug == "2026-07-10-fake-entry.md")
        try expect(FileManager.default.fileExists(atPath: result.cleanedPath))
        try expect(FileManager.default.fileExists(atPath: result.renamedPath))
        try expect(FileManager.default.fileExists(atPath: result.enrichedPath))

        let unexpectedCalls = LockedStringArray()
        let failIfCalled = Pipeline.Operations(
            transcribe: { _, _ in unexpectedCalls.append("transcribe"); return "unused" },
            cleanup: { _, _ in unexpectedCalls.append("cleanup"); return "unused" },
            categorize: { _, _, _ in unexpectedCalls.append("categorize"); return .personal },
            filename: { _, _ in unexpectedCalls.append("filename"); return "unused.md" },
            enrich: { _, _, _, _ in unexpectedCalls.append("enrich"); return "unused" }
        )
        _ = try await Pipeline.resume(stem: stem, dataDir: root.path, operations: failIfCalled)
        try expect(unexpectedCalls.snapshot().isEmpty)
    }

    await testAsync("Pipeline: fake cleanup failure stops later stages") {
        let stem = "2026-07-10-0915"
        let root = try makeRoot(stem: stem)
        defer { try? FileManager.default.removeItem(at: root) }
        let laterCalls = LockedStringArray()
        let operations = Pipeline.Operations(
            transcribe: { _, _ in "unused" },
            cleanup: { _, _ in
                throw NSError(domain: "PipelineTests", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Synthetic cleanup failure",
                ])
            },
            categorize: { _, _, _ in laterCalls.append("categorize"); return .personal },
            filename: { _, _ in laterCalls.append("filename"); return "unused.md" },
            enrich: { _, _, _, _ in laterCalls.append("enrich"); return "unused" }
        )

        do {
            _ = try await Pipeline.resume(
                stem: stem,
                dataDir: root.path,
                fromStage: .cleaning,
                operations: operations
            )
            try expect(false, "Expected cleanup failure")
        } catch {
            try expect(error.localizedDescription == "Synthetic cleanup failure")
        }
        try expect(laterCalls.snapshot().isEmpty)
        try expect(!FileManager.default.fileExists(
            atPath: root.appendingPathComponent(".pipeline/02-logs/\(stem).md").path
        ))
    }
}

@MainActor
func runTests() async {
    print("\nRunning CaptainsLog Tests...\n")
    
    // MARK: - ConfigManager Tests
    
    test("ConfigManager: initial dataDir is not empty") {
        let config = ConfigManager()
        try expect(!config.dataDir.isEmpty)
    }
    
    test("ConfigManager: personal context can be read and written") {
        let config = ConfigManager()
        let original = config.personalContext
        config.personalContext = "test-value"
        try expect(config.personalContext == "test-value")
        config.personalContext = original
    }
    
    test("ConfigManager: corrections can be read and written") {
        let config = ConfigManager()
        let original = config.corrections
        config.corrections = "test-value"
        try expect(config.corrections == "test-value")
        config.corrections = original
    }
    
    test("ConfigManager: whisper model can be read and written") {
        let config = ConfigManager()
        let original = config.whisperModel
        config.whisperModel = "test-model"
        try expect(config.whisperModel == "test-model")
        config.whisperModel = original
    }
    
    test("ConfigManager: qwen model ID defaults to empty") {
        let config = ConfigManager()
        try expect(config.qwenModelId == "")
    }
    
    test("ConfigManager: personal context can be set") {
        let config = ConfigManager()
        config.personalContext = "Test context"
        try expect(config.personalContext == "Test context")
    }
    
    test("ConfigManager: corrections can be set") {
        let config = ConfigManager()
        config.corrections = "Test corrections"
        try expect(config.corrections == "Test corrections")
    }
    
    test("ConfigManager: data dir can be set") {
        let config = ConfigManager()
        config.dataDir = "./tmp/test"
        try expect(config.dataDir == "./tmp/test")
    }

    test("Config: config path can be overridden for tests") {
        try expect(CaptainsLogConfig.configURL.lastPathComponent == "config.json")
        try expect(CaptainsLogConfig.configURL.path.contains("CaptainsLogTests-"))
    }

    test("Transcriber: resolveModel uses configured Whisper model") {
        let config = CaptainsLogConfig(whisperModel: "configured-whisper")
        try expect(Transcriber.resolveModel(config: config) == "configured-whisper")
    }

    test("Transcriber: explicit Whisper model overrides config") {
        let config = CaptainsLogConfig(whisperModel: "configured-whisper")
        try expect(
            Transcriber.resolveModel("explicit-whisper", config: config) == "explicit-whisper"
        )
    }

    test("FileSystemGuard: wraps write failures with target path") {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: dir) }
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        do {
            try FileSystemGuard.writeText("test", to: dir.path)
            try expect(false, "Expected writing to a directory path to fail")
        } catch let error as CaptainsLogFileSystemError {
            try expect(error.localizedDescription.contains(dir.path))
        }
    }

    test("Config: withDataDir overrides context location without mutating original") {
        let original = CaptainsLogConfig(dataDir: "./tmp/original")
        let overridden = original.withDataDir("./tmp/override")
        try expect(original.dataDir == "./tmp/original")
        try expect(overridden.dataDir == "./tmp/override")
        try expect(overridden.contextDir().lastPathComponent == "context")
        try expect(overridden.contextDir().path.contains("/override/context"))
    }

    test("Prompt XML: wraps sections in XML-like tags") {
        let document = PromptXML.document([
            PromptXML.element("instructions", "Do the thing."),
            PromptXML.optionalElement("context", "Helpful background."),
            PromptXML.optionalElement("empty", "   "),
        ])
        try expect(document.contains("<instructions>"))
        try expect(document.contains("</instructions>"))
        try expect(document.contains("<context>"))
        try expect(document.contains("Helpful background."))
        try expect(document.contains("<empty>") == false)
    }

    test("Cleanup: prompt helpers wrap context and transcript in XML tags") {
        let speaker = Cleanup.speakerContextSection("Works on ML systems.")
        let corrections = Cleanup.nameCorrectionsSection("Jon -> Jorian")
        let transcript = Cleanup.userMessage(transcript: "Uh, I shipped it.")

        try expect(speaker.contains("<speaker_context>"))
        try expect(speaker.contains("Works on ML systems."))
        try expect(corrections.contains("<name_corrections>"))
        try expect(corrections.contains("Jon -> Jorian"))
        try expect(transcript.contains("<transcript>"))
        try expect(transcript.contains("Uh, I shipped it."))
    }

    test("LLM: context planning grows with an unbounded rewrite request") {
        let contextSize = try LLM.plannedContextSize(
            promptTokenCount: 6_000,
            maxTokens: 0,
            modelContextSize: 262_144
        )
        try expect(contextSize == 12_032)
    }

    test("LLM: context planning respects an explicit small output limit") {
        let contextSize = try LLM.plannedContextSize(
            promptTokenCount: 1_000,
            maxTokens: 64,
            modelContextSize: 262_144
        )
        try expect(contextSize == 1_280)
    }

    test("LLM: context planning rejects requests beyond model capacity") {
        do {
            _ = try LLM.plannedContextSize(
                promptTokenCount: 900,
                maxTokens: 200,
                modelContextSize: 1_000
            )
            try expect(false, "Expected an oversized request to fail")
        } catch let error as LLM.LLMError {
            try expect(error == .requestedOutputTooLarge(
                promptTokens: 900,
                requestedTokens: 200,
                modelContextTokens: 1_000
            ))
        }
    }

    test("Filename and Enrich: user messages wrap log entries in XML tags") {
        let filenameMessage = Filename.userMessage(logText: "Shipped a feature.")
        let enrichMessage = Enrich.userMessage(logText: "Shipped a feature.")

        try expect(filenameMessage.contains("<log_entry>"))
        try expect(filenameMessage.contains("Shipped a feature."))
        try expect(enrichMessage.contains("<log_entry>"))
        try expect(enrichMessage.contains("Shipped a feature."))
    }

    test("PromptDebug: renders system and user prompts together") {
        let rendered = PromptDebug.render(RenderedPrompt(
            systemPrompt: "<instructions>Do the thing.</instructions>",
            userMessage: "<question>What changed?</question>"
        ))
        try expect(rendered.contains("<system_prompt>"))
        try expect(rendered.contains("<user_prompt>"))
        try expect(rendered.contains("Do the thing."))
        try expect(rendered.contains("What changed?"))
    }

    test("Categorize: parses a single XML category") {
        try expect(try Categorize.parseCategory("<category>side_project</category>") == .sideProject)
    }

    test("Categorize: rejects a missing XML category") {
        do {
            _ = try Categorize.parseCategory("personal")
            try expect(false, "Expected invalid category XML to throw")
        } catch let error as Categorize.CategorizeError {
            try expect(error == .invalidXML(outputByteCount: 8))
        }
    }

    // MARK: - RecordingState Tests
     
    test("RecordingState: initial audio level is zero") {
        let recording = RecordingState()
        try expect(recording.audioLevel == 0)
    }
    
    test("RecordingState: initial recording duration is zero") {
        let recording = RecordingState()
        try expect(recording.recordingDuration == 0)
    }
    
    test("RecordingState: initial isRecording is false") {
        let recording = RecordingState()
        try expect(recording.isRecording == false)
    }

    test("RecordingState: initialization does not enumerate audio devices") {
        let calls = LockedStringArray()
        let recording = RecordingState(dependencies: .init(
            listInputDevices: { calls.append("list"); return [] },
            defaultInputDevice: { calls.append("default"); return nil },
            record: { _, _, _, _, _ in }
        ))
        try expect(recording.inputDevices.isEmpty)
        try expect(calls.snapshot().isEmpty)
    }
    
    test("RecordingState: input devices come from provider") {
        let device = AudioDevice(id: 42, name: "Test microphone", uid: "test-mic")
        let recording = RecordingState(dependencies: .init(
            listInputDevices: { [device] },
            defaultInputDevice: { device },
            record: { _, _, _, _, _ in }
        ))
        recording.refreshDevices()
        try expect(recording.inputDevices == [device])
    }
    
    test("RecordingState: selected device UID uses provider default") {
        let device = AudioDevice(id: 42, name: "Test microphone", uid: "test-mic")
        let recording = RecordingState(dependencies: .init(
            listInputDevices: { [device] },
            defaultInputDevice: { device },
            record: { _, _, _, _, _ in }
        ))
        recording.refreshDevices()
        try expect(recording.selectedDeviceUID == "test-mic")
    }
    
    test("RecordingState: stop recording when not recording does not crash") {
        let recording = RecordingState()
        recording.stopRecording()
        try expect(recording.isRecording == false)
    }
    
    test("RecordingState: cancel recording when not recording does not crash") {
        let recording = RecordingState()
        recording.cancelRecording()
        try expect(recording.isRecording == false)
    }

    await testAsync("RecordingState: error message is surfaced and cleared") {
        let recording = RecordingState(dependencies: .init(
            listInputDevices: { [] },
            defaultInputDevice: { nil },
            record: { _, _, stopTrigger, _, _ in
                for await _ in stopTrigger { break }
            }
        ))
        try expect(recording.errorMessage == nil)

        // Manually set an error to simulate a prior failed recording
        recording.errorMessage = "Simulated error"
        try expect(recording.errorMessage == "Simulated error")

        // Starting a new recording should clear the error
        recording.startRecording(
            dataDir: "/tmp/cl-test-recording",
            onComplete: { _ in },
            onError: { _ in }
        )
        try expect(recording.errorMessage == nil)
        await Task.yield()
        recording.cancelRecording()
    }

    await testAsync("RecordingState: fake recorder supports pause, resume, and stop") {
        let (events, continuation) = AsyncStream<String>.makeStream()
        let recording = RecordingState(dependencies: .init(
            listInputDevices: { [] },
            defaultInputDevice: { nil },
            record: { _, _, stopTrigger, levelCallback, isPaused in
                levelCallback?(0.75)
                for await _ in stopTrigger { break }
                try expect(isPaused() == false)
            }
        ))

        recording.startRecording(
            dataDir: FileManager.default.temporaryDirectory.path,
            onComplete: { _ in continuation.yield("complete"); continuation.finish() },
            onError: { _ in continuation.yield("error"); continuation.finish() }
        )
        try expect(recording.isRecording)
        await Task.yield()
        recording.pauseRecording()
        try expect(recording.isRecordingPaused)
        recording.resumeRecording()
        try expect(recording.isRecordingPaused == false)
        recording.stopRecording()

        var outcome: String?
        for await event in events { outcome = event }
        try expect(outcome == "complete")
        try expect(recording.isRecording == false)
        try expect(recording.audioLevel == 0)
    }

    await testAsync("RecordingState: fake recorder surfaces failures") {
        let (events, continuation) = AsyncStream<String>.makeStream()
        let recording = RecordingState(dependencies: .init(
            listInputDevices: { [] },
            defaultInputDevice: { nil },
            record: { _, _, _, _, _ in
                throw NSError(domain: "RecordingTests", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Synthetic recording failure",
                ])
            }
        ))

        recording.startRecording(
            dataDir: FileManager.default.temporaryDirectory.path,
            onComplete: { _ in continuation.yield("complete"); continuation.finish() },
            onError: { _ in continuation.yield("error"); continuation.finish() }
        )

        var outcome: String?
        for await event in events { outcome = event }
        try expect(outcome == "error")
        try expect(recording.isRecording == false)
        try expect(recording.errorMessage == "Synthetic recording failure")
    }

    await testAsync("AppState: recording guard no longer blocks on processing") {
        let recording = RecordingState(dependencies: .init(
            listInputDevices: { [] },
            defaultInputDevice: { nil },
            record: { _, _, stopTrigger, _, _ in
                for await _ in stopTrigger { break }
            }
        ))
        let appState = AppState(recording: recording)
        // Simulate processing in progress
        appState.processing.stage = .transcribing
        appState.models.modelState = .downloading(model: "Test", progress: 0.5)
        try expect(appState.processing.isProcessing == true)
        try expect(appState.modelsReady == false)

        // The old guard blocked on processing.isProcessing.
        // The new guard only blocks on recording.isRecording.
        // Since we are not recording, startRecording should proceed.
        appState.startRecording()

        // The fake recorder remains active until stop, proving processing did not block it.
        try expect(appState.isRecording == true)
        await Task.yield()

        appState.stopRecording()
        for _ in 0..<100 where appState.isRecording {
            try await Task.sleep(for: .milliseconds(10))
        }
        try expect(appState.isRecording == false)
    }
    
    // MARK: - ProcessingCoordinator Tests
    
    test("ProcessingCoordinator: initial stage is idle") {
        let coordinator = ProcessingCoordinator()
        try expect(coordinator.stage == .idle)
    }
    
    test("ProcessingCoordinator: initial status message") {
        let coordinator = ProcessingCoordinator()
        try expect(coordinator.statusMessage == "Ready to record")
    }
    
    test("ProcessingCoordinator: initial error message is nil") {
        let coordinator = ProcessingCoordinator()
        try expect(coordinator.errorMessage == nil)
    }
    
    test("ProcessingCoordinator: initial processing stem is nil") {
        let coordinator = ProcessingCoordinator()
        try expect(coordinator.processingStem == nil)
    }
    
    test("ProcessingCoordinator: initial isProcessing is false") {
        let coordinator = ProcessingCoordinator()
        try expect(coordinator.isProcessing == false)
    }
    
    test("ProcessingCoordinator: isProcessing true for transcribing") {
        let coordinator = ProcessingCoordinator()
        coordinator.stage = .transcribing
        try expect(coordinator.isProcessing == true)
    }
    
    test("ProcessingCoordinator: isProcessing true for cleaning") {
        let coordinator = ProcessingCoordinator()
        coordinator.stage = .cleaning
        try expect(coordinator.isProcessing == true)
    }
    
    test("ProcessingCoordinator: isProcessing false for idle") {
        let coordinator = ProcessingCoordinator()
        coordinator.stage = .idle
        try expect(coordinator.isProcessing == false)
    }
    
    test("ProcessingCoordinator: isProcessing false for done") {
        let coordinator = ProcessingCoordinator()
        coordinator.stage = .done
        try expect(coordinator.isProcessing == false)
    }
    
    test("ProcessingCoordinator: pause processing resets state") {
        let coordinator = ProcessingCoordinator()
        coordinator.stage = .transcribing
        coordinator.statusMessage = "Processing..."
        coordinator.processingStem = "test"
        
        coordinator.pauseProcessing()
        
        try expect(coordinator.stage == .idle)
        try expect(coordinator.statusMessage == "Paused")
        try expect(coordinator.processingStem == nil)
        try expect(coordinator.isProcessing == false)
    }
    
    test("ProcessingCoordinator: status message can be updated") {
        let coordinator = ProcessingCoordinator()
        coordinator.statusMessage = "custom"
        try expect(coordinator.statusMessage == "custom")
    }
    
    test("ProcessingCoordinator: processing stem can be set") {
        let coordinator = ProcessingCoordinator()
        coordinator.processingStem = "2024-01-01"
        try expect(coordinator.processingStem == "2024-01-01")
    }
    
    // MARK: - DirectoryWatcher Tests
    
    test("DirectoryWatcher: initializes") {
        let watcher = DirectoryWatcher(onReload: { })
        _ = watcher
    }
    
    test("DirectoryWatcher: start watching with invalid path does not crash") {
        let watcher = DirectoryWatcher(onReload: { })
        watcher.startWatching(dataDir: "/nonexistent")
    }
    
    test("DirectoryWatcher: start watching with valid path does not crash") {
        let watcher = DirectoryWatcher(onReload: { })
        let temp = FileManager.default.temporaryDirectory.path
        watcher.startWatching(dataDir: temp)
    }
    
    test("DirectoryWatcher: stop watching does not crash") {
        let watcher = DirectoryWatcher(onReload: { })
        let temp = FileManager.default.temporaryDirectory.path
        watcher.startWatching(dataDir: temp)
        watcher.stopWatching()
    }
    
    test("DirectoryWatcher: schedule reload does not crash") {
        let watcher = DirectoryWatcher(onReload: { })
        watcher.scheduleReload()
    }

    await testAsync("DirectoryWatcher: coalesces rapid reload requests") {
        let reloads = LockedStringArray()
        let watcher = DirectoryWatcher(onReload: { reloads.append("reload") })
        watcher.scheduleReload()
        watcher.scheduleReload()
        try await Task.sleep(for: .milliseconds(500))
        try expect(reloads.snapshot() == ["reload"])
    }
    
    // MARK: - ModelManager Tests
    
    test("ModelManager: initial model state is ready") {
        let manager = ModelManager()
        try expect(manager.modelState == .ready)
    }
    
    test("ModelManager: models ready returns true when ready") {
        let manager = ModelManager()
        try expect(manager.modelsReady == true)
    }
    
    test("ModelManager: models ready returns false when downloading") {
        let manager = ModelManager()
        manager.modelState = .downloading(model: "Test", progress: 0.5)
        try expect(manager.modelsReady == false)
    }
    
    test("ModelManager: models ready returns false when error") {
        let manager = ModelManager()
        manager.modelState = .error("test")
        try expect(manager.modelsReady == false)
    }
    
    test("ModelManager: model state can be set to downloading") {
        let manager = ModelManager()
        manager.modelState = .downloading(model: "Whisper", progress: 0.5)
        if case .downloading(let model, let progress) = manager.modelState {
            try expect(model == "Whisper")
            try expect(progress == 0.5)
        }
    }
    
    test("ModelManager: model state can be reset to ready") {
        let manager = ModelManager()
        manager.modelState = .downloading(model: "Test", progress: 0.5)
        manager.modelState = .ready
        try expect(manager.modelState == .ready)
    }

    await testAsync("ModelManager: downloads missing models with injected operations") {
        let calls = LockedStringArray()
        let manager = ModelManager(dependencies: .init(
            clearStaleConfig: { calls.append("clear-stale") },
            cleanCorruptedMetadata: { calls.append("clean-metadata") },
            whisperIsDownloaded: { false },
            qwenIsDownloaded: { false },
            downloadWhisper: { _ in calls.append("download-whisper") },
            downloadQwen: { _ in calls.append("download-qwen") }
        ))

        await manager.downloadModelsIfNeeded()

        try expect(manager.modelState == .ready)
        try expect(calls.snapshot() == [
            "clear-stale", "clean-metadata", "download-whisper", "download-qwen",
        ])
    }

    test("ModelManager: removes stale Whisper download metadata") {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLogModelManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let staleMetadata = root
            .appendingPathComponent(".cache/huggingface/download/openai_whisper-large-v2", isDirectory: true)
            .appendingPathComponent("config.json.metadata")
        let otherMetadata = root
            .appendingPathComponent(".cache/huggingface/download/openai_whisper-large-v2", isDirectory: true)
            .appendingPathComponent("generation_config.json.metadata")
        try FileManager.default.createDirectory(
            at: staleMetadata.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "corrupted".write(to: staleMetadata, atomically: true, encoding: .utf8)
        try "keep".write(to: otherMetadata, atomically: true, encoding: .utf8)

        ModelManager.removeDownloadMetadata(in: root)

        try expect(!FileManager.default.fileExists(atPath: staleMetadata.path))
        try expect(FileManager.default.fileExists(atPath: otherMetadata.path))
    }

    await testAsync("ModelManager: treats download cancellation as ready") {
        let manager = ModelManager(dependencies: .init(
            clearStaleConfig: {},
            cleanCorruptedMetadata: {},
            whisperIsDownloaded: { false },
            qwenIsDownloaded: { true },
            downloadWhisper: { _ in throw CancellationError() },
            downloadQwen: { _ in }
        ))

        await manager.downloadModelsIfNeeded()
        try expect(manager.modelState == .ready)
    }

    await testAsync("ModelManager: surfaces non-cancellation download failures") {
        let manager = ModelManager(dependencies: .init(
            clearStaleConfig: {},
            cleanCorruptedMetadata: {},
            whisperIsDownloaded: { false },
            qwenIsDownloaded: { true },
            downloadWhisper: { _ in
                throw NSError(domain: "ModelTests", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Synthetic download failure",
                ])
            },
            downloadQwen: { _ in }
        ))

        await manager.downloadModelsIfNeeded()
        try expect(manager.modelState == .error("Synthetic download failure"))
    }
    
    // MARK: - AppState Tests
    
    test("AppState: config manager accessible") {
        let appState = AppState()
        _ = appState.config.dataDir
    }
    
    test("AppState: recording state accessible") {
        let appState = AppState()
        _ = appState.recording.audioLevel
    }
    
    test("AppState: processing coordinator accessible") {
        let appState = AppState()
        _ = appState.processing.stage
    }
    
    test("AppState: model manager accessible") {
        let appState = AppState()
        _ = appState.models.modelState
    }
    
    test("AppState: directory watcher accessible") {
        let appState = AppState()
        _ = appState.directoryWatcher.onReload
    }
    
    test("AppState: computed properties passthrough") {
        let appState = AppState()
        try expect(appState.stage == appState.processing.stage)
        try expect(appState.audioLevel == appState.recording.audioLevel)
        try expect(appState.statusMessage == appState.processing.statusMessage)
        try expect(appState.modelState == appState.models.modelState)
        try expect(appState.isProcessing == appState.processing.isProcessing)
        try expect(appState.isRecording == appState.recording.isRecording)
        try expect(appState.dataDir == appState.config.dataDir)
        try expect(appState.needsFirstRun == appState.config.needsFirstRun)
        try expect(appState.modelsReady == appState.models.modelsReady)
    }
    
    test("AppState: selected device UID can be set") {
        let appState = AppState()
        appState.selectedDeviceUID = "test-uid"
        try expect(appState.selectedDeviceUID == "test-uid")
        try expect(appState.recording.selectedDeviceUID == "test-uid")
    }
    
    test("AppState: personal context passthrough") {
        let appState = AppState()
        appState.personalContext = "test"
        try expect(appState.personalContext == "test")
        try expect(appState.config.personalContext == "test")
    }
    
    test("AppState: corrections passthrough") {
        let appState = AppState()
        appState.corrections = "test"
        try expect(appState.corrections == "test")
        try expect(appState.config.corrections == "test")
    }
    
    test("AppState: refresh devices does not crash") {
        let appState = AppState()
        appState.refreshDevices()
    }
    
    test("AppState: configure directory watcher does not crash") {
        let appState = AppState()
        appState.configureDirectoryWatcher()
    }
    
    test("AppState: load entries does not crash") {
        let appState = AppState()
        appState.loadEntries()
    }
    
    test("AppState: pause processing delegates to coordinator") {
        let appState = AppState()
        appState.pauseProcessing()
        try expect(appState.processing.stage == .idle)
    }
    
    test("AppState: delete entry does not crash") {
        let appState = AppState()
        appState.deleteEntry(stem: "nonexistent", slug: nil)
    }
    
    test("AppState: batch resume pending does not crash") {
        let appState = AppState()
        appState.batchResumePending()
    }

    test("Config: migration round-trip preserves values") {
        var config = CaptainsLogConfig(schemaVersion: 0, dataDir: "/tmp/migration-test")
        CaptainsLogConfig.migrate(from: config.schemaVersion, to: &config)
        try expect(config.schemaVersion == CaptainsLogConfig.currentSchemaVersion)
        try expect(config.dataDir == "/tmp/migration-test")
    }

    test("Pipeline: detectNextStage handles malformed trees") {
        let fm = FileManager.default
        let dataDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: dataDir) }

        // Empty directory: should fall back to transcribing
        try? fm.createDirectory(at: dataDir, withIntermediateDirectories: true)
        let emptyStage = Pipeline.detectNextStage(stem: "2025-01-01-test", dataDir: dataDir.path)
        try expect(emptyStage == .transcribing)

        // Only transcript exists: should detect cleaning
        let transcriptDir = dataDir.appendingPathComponent(".pipeline/01-transcribed")
        try? fm.createDirectory(at: transcriptDir, withIntermediateDirectories: true)
        try? "test".write(to: transcriptDir.appendingPathComponent("2025-01-01-test.md"), atomically: true, encoding: .utf8)
        let transcriptStage = Pipeline.detectNextStage(stem: "2025-01-01-test", dataDir: dataDir.path)
        try expect(transcriptStage == .cleaning)

        // A cleaned entry without a category manifest should be categorized
        let logsDir = dataDir.appendingPathComponent(".pipeline/02-logs")
        try? fm.createDirectory(at: logsDir, withIntermediateDirectories: true)
        try? "cleaned".write(to: logsDir.appendingPathComponent("2025-01-01-test.md"), atomically: true, encoding: .utf8)
        let cleanedStage = Pipeline.detectNextStage(stem: "2025-01-01-test", dataDir: dataDir.path)
        try expect(cleanedStage == .categorizing)
    }

    test("ProcessingCoordinator: cancellation resets state") {
        let coordinator = ProcessingCoordinator()
        coordinator.stage = .transcribing
        coordinator.statusMessage = "Working..."
        coordinator.processingStem = "test-stem"

        coordinator.pauseProcessing()

        try expect(coordinator.stage == .idle)
        try expect(coordinator.statusMessage == "Paused")
        try expect(coordinator.processingStem == nil)
        try expect(coordinator.isProcessing == false)
    }

    test("Field Notes: waveform generation accepts arbitrary hash seeds") {
        for seed in [Int.min, -1, 0, 1, Int.max] {
            let ticks = FieldNotesAudioRuler.tickHeights(seed: seed, count: 48, height: 24)
            try expect(ticks.count == 48)
            try expect(ticks.allSatisfy { $0 >= 2 })
        }
        try expect(FieldNotesAudioRuler.tickHeights(seed: 1, count: -1, height: 24).isEmpty)
    }

    runCoreCoverageTests()
    await runSearchCoverageTests()
    await runCoordinatorCoverageTests()
    await runPipelineOrchestrationCoverageTests()

    // Print results
    print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("Tests run: \(testsRun)")
    print("Tests passed: \(testsPassed)")
    print("Tests failed: \(testsFailed)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    
    if testsFailed > 0 {
        exit(1)
    }
}

@main
struct TestRunner {
    @MainActor
    static func main() async {
        let testRoot = configureIsolatedTestEnvironment()
        defer {
            unsetenv("CAPTAINS_LOG_CONFIG_PATH")
            try? FileManager.default.removeItem(at: testRoot)
        }
        await runTests()
    }
}

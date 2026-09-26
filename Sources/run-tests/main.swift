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
@MainActor
var lightweightUnitOnly = false

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

final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) { self.value = value }

    func get() -> Value { lock.withLock { value } }
    func set(_ newValue: Value) { lock.withLock { value = newValue } }
}

private final class TestRecorderAudioEngine: RecorderAudioEngine, @unchecked Sendable {
    let inputFormat = RecorderAudioFormat(sampleRate: 48_000, channelCount: 1)
    let events: LockedStringArray
    let started: @Sendable () -> Void
    let installError: Error?
    let startError: Error?
    private let lock = NSLock()
    private var tapHandler: (@Sendable (RecorderAudioBuffer) -> Void)?

    init(
        events: LockedStringArray,
        installError: Error? = nil,
        startError: Error? = nil,
        started: @escaping @Sendable () -> Void = {}
    ) {
        self.events = events
        self.installError = installError
        self.startError = startError
        self.started = started
    }

    func installTap(
        bufferSize: UInt32,
        handler: @escaping @Sendable (RecorderAudioBuffer) -> Void
    ) throws {
        events.append("install:\(bufferSize)")
        if let installError { throw installError }
        lock.withLock { tapHandler = handler }
    }

    func start() throws {
        events.append("start")
        started()
        if let startError { throw startError }
    }

    func stop() { events.append("stop") }
    func removeTap() { events.append("removeTap") }

    func emit(_ samples: [Float]) {
        let handler = lock.withLock { tapHandler }
        handler?(RecorderAudioBuffer(
            frameLength: samples.count,
            rootMeanSquare: samples.withUnsafeBufferPointer {
                AudioLevel.rootMeanSquare(of: $0)
            }
        ))
    }
}

private final class TestRecorderAudioWriter: RecorderAudioWriter, @unchecked Sendable {
    let events: LockedStringArray
    let writeError: Error?

    init(events: LockedStringArray, writeError: Error? = nil) {
        self.events = events
        self.writeError = writeError
    }

    func write(from buffer: RecorderAudioBuffer) throws {
        events.append("write:\(buffer.frameLength)")
        if let writeError { throw writeError }
    }
}

actor FakeEmbeddingModel: TextEmbeddingModel {
    nonisolated let identity = "fake-search-model-v1"
    private(set) var embedCallCount = 0
    private(set) var chunkCallCount = 0
    private(set) var embeddedTexts: [String] = []

    func embed(_ text: String, as kind: EmbeddingInputKind) -> [Float] {
        embedCallCount += 1
        embeddedTexts.append(text)
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
        chunkCallCount += 1
        return text.isEmpty ? [] : [text]
    }
}

actor AsyncTestGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }
}

actor GatedEmbeddingModel: TextEmbeddingModel {
    nonisolated let identity = "gated-search-model-v1"
    private let gate: AsyncTestGate
    private let queryLog: LockedStringArray

    init(gate: AsyncTestGate, queryLog: LockedStringArray) {
        self.gate = gate
        self.queryLog = queryLog
    }

    func embed(_ text: String, as kind: EmbeddingInputKind) async throws -> [Float] {
        if case .query = kind {
            queryLog.append(text)
            if text == "bike" { await gate.wait() }
        }

        let lowered = text.lowercased()
        let index = lowered.contains("bicycle") || lowered.contains("bike") ? 0
            : lowered.contains("sqlite") ? 1 : 2
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

    await testAsync("Semantic search: frontmatter remains searchable when the body is empty") {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SemanticSearchFrontmatter-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try makeCompletedSearchEntry(
            root: root,
            stem: "2026-07-13-1000",
            slug: "2026-07-13-passport-planning",
            category: .personal,
            content: "---\nsummary: Renew passport before the Lisbon trip.\ntags: travel\n---\n\n"
        )

        let search = try SemanticSearch(dataDir: root.path, model: FakeEmbeddingModel())
        let indexed = try await search.synchronize()
        let results = try await search.search("Lisbon passport", synchronizeFirst: false)

        try expect(indexed.added == 1 && indexed.chunks == 1)
        try expect(results.count == 1, "Frontmatter summary should be indexed as the fallback passage")
        try expect(results[0].slug == "2026-07-13-passport-planning")
        try expect(results[0].matchKind == .keyword)
        try expect(results[0].excerpt.contains("Lisbon trip"))
    }

    await testAsync("Semantic search: blank and zero-limit queries return without inference") {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SemanticSearchEmptyQuery-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = FakeEmbeddingModel()
        let search = try SemanticSearch(dataDir: root.path, model: model)

        let blankResults = try await search.search(" \n\t", synchronizeFirst: true)
        let zeroLimitResults = try await search.search("bike", limit: 0, synchronizeFirst: true)
        try expect(blankResults.isEmpty)
        try expect(zeroLimitResults.isEmpty)
        let embedCallCount = await model.embedCallCount
        let chunkCallCount = await model.chunkCallCount
        try expect(embedCallCount == 0, "Invalid queries must not embed text")
        try expect(chunkCallCount == 0, "Invalid queries must not index documents")

        try expect(E5EmbeddingModel.dimension == 384)
        try expect(E5EmbeddingModel.maximumTokens == 511)
        try expect(E5EmbeddingModel.expectedSHA256.count == 64)
        try expect(E5EmbeddingModel.modelURL().lastPathComponent == E5EmbeddingModel.filename)
    }

    await testAsync("Semantic search: manager debounces, invalidates, retries, and cancels stale queries") {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SearchManagerDebounce-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = FakeEmbeddingModel()
        let factories = LockedStringArray()
        let manager = SearchManager(debounceInterval: .milliseconds(400)) { dataDir, _ in
            factories.append(dataDir)
            return try SemanticSearch(dataDir: dataDir, model: model)
        }
        try expect(manager.state == .idle)
        try expect(!manager.isActive)

        manager.updateQuery("bike", dataDir: root.path)
        try await Task.sleep(for: .milliseconds(20))
        let initialFactories = factories.snapshot()
        try expect(initialFactories.isEmpty, "Search must wait for the debounce interval")

        manager.updateQuery("sqlite", dataDir: root.path)
        try await Task.sleep(for: .milliseconds(20))
        let supersededFactories = factories.snapshot()
        try expect(supersededFactories.isEmpty, "Updating a query restarts the debounce interval")
        try expect(manager.isActive)
        try expect(manager.query == "sqlite")

        for _ in 0..<100 where manager.state != .ready {
            try await Task.sleep(for: .milliseconds(10))
        }
        try expect(manager.state == .ready, "Debounced query should complete")
        try expect(factories.snapshot() == [root.path], "Only the latest query should create an engine")
        var embeddedTexts = await model.embeddedTexts
        try expect(embeddedTexts == ["sqlite"], "The superseded query must not run")

        manager.invalidateIndex(dataDir: root.path)
        for _ in 0..<100 where (await model.embedCallCount) < 2 {
            try await Task.sleep(for: .milliseconds(10))
        }
        let invalidationCount = await model.embedCallCount
        try expect(invalidationCount == 2, "Invalidating the index should rerun the current query")
        try expect(factories.snapshot().count == 1, "Index invalidation should reuse the loaded engine")

        manager.retry(dataDir: root.path)
        for _ in 0..<100 where factories.snapshot().count < 2 {
            try await Task.sleep(for: .milliseconds(10))
        }
        try expect(factories.snapshot().count == 2, "Retry should reload the search engine")
        for _ in 0..<100 where (await model.embedCallCount) < 3 {
            try await Task.sleep(for: .milliseconds(10))
        }
        let retryEmbedCount = await model.embedCallCount
        try expect(retryEmbedCount == 3, "Retry should execute a search with the reloaded engine")
        embeddedTexts = await model.embeddedTexts
        try expect(embeddedTexts.count == 3, "Retry should run the current query again")

        manager.updateQuery("", dataDir: root.path)
        try expect(manager.state == .idle)
        try expect(manager.results.isEmpty)
        try expect(!manager.isActive)
        try await Task.sleep(for: .milliseconds(450))
        let finalEmbedCount = await model.embedCallCount
        try expect(finalEmbedCount == 3, "Clearing the query should cancel pending work")
    }

    await testAsync("Semantic search: in-flight canceled query cannot replace the newer result") {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SearchManagerInFlightCancel-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try makeCompletedSearchEntry(
            root: root,
            stem: "2026-07-14-0800",
            slug: "2026-07-14-riverside-cycling",
            category: .personal,
            content: "A long bicycle ride beside the river."
        )
        _ = try makeCompletedSearchEntry(
            root: root,
            stem: "2026-07-15-0900",
            slug: "2026-07-15-sqlite-storage",
            category: .sideProject,
            content: "SQLite stores the local application index."
        )

        let gate = AsyncTestGate()
        let queryLog = LockedStringArray()
        let model = GatedEmbeddingModel(gate: gate, queryLog: queryLog)
        let manager = SearchManager(debounceInterval: .milliseconds(250)) { dataDir, _ in
            try SemanticSearch(dataDir: dataDir, model: model)
        }

        manager.updateQuery("bike", dataDir: root.path)
        for _ in 0..<150 where !queryLog.snapshot().contains("bike") {
            try await Task.sleep(for: .milliseconds(10))
        }
        try expect(queryLog.snapshot() == ["bike"], "The first query should be blocked inside embedding")

        manager.updateQuery("sqlite", dataDir: root.path)
        await gate.open()
        try await Task.sleep(for: .milliseconds(80))
        try expect(
            manager.results.isEmpty,
            "The completed but canceled query must not publish its stale results"
        )
        try expect(manager.query == "sqlite")

        for _ in 0..<150 where manager.state != .ready {
            try await Task.sleep(for: .milliseconds(10))
        }
        try expect(manager.state == .ready, "The newer query should finish after the canceled one")
        try expect(manager.results.first?.slug == "2026-07-15-sqlite-storage")
        try expect(queryLog.snapshot() == ["bike", "sqlite"])
    }

    test("Semantic search: visible result and error states retain the query and clear cleanly") {
        let manager = SearchManager()
        let result = SearchResult(
            stem: "2025-01-15-1200",
            slug: "2025-01-15-weekend-with-family",
            displayName: "2025-01-15-weekend-with-family",
            path: "/tmp/2025-01-15-weekend-with-family.md",
            excerpt: "A relaxing weekend spent at the beach with the family.",
            distance: 0,
            matchKind: .keyword,
            matchedTerms: ["family"]
        )

        manager.applyFixture(query: "time with family", results: [result])
        try expect(manager.isActive)
        try expect(manager.state == .ready)
        try expect(manager.results.count == 1)
        try expect(manager.results[0].displayName == result.displayName)

        manager.applyFixture(query: "time with family", results: [], state: .error("Index unavailable"))
        try expect(manager.state == .error("Index unavailable"))
        try expect(manager.query == "time with family")

        manager.updateQuery("", dataDir: "/tmp/captainslog-search-manager")
        try expect(manager.state == .idle)
        try expect(manager.results.isEmpty)
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
func runAppWorkflowCoverageTests() async {
    await testAsync("Transcribe CLI: fake inference uses its options and default output path") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogTranscribeCommand-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let audioDir = root.appendingPathComponent("audio", isDirectory: true)
        try fm.createDirectory(at: audioDir, withIntermediateDirectories: true)

        let repository = URL(fileURLWithPath: fm.currentDirectoryPath)
        let audioFixture = repository.appendingPathComponent("eval/transcribe/audio/durins-volk.m4a")
        let audioInput = audioDir.appendingPathComponent("synthetic-recording.m4a")
        try fm.copyItem(at: audioFixture, to: audioInput)
        let transcriptFixture = repository.appendingPathComponent("eval/transcribe/expected/durins-volk.md")
        let expectedTranscript = try String(contentsOf: transcriptFixture, encoding: .utf8)
        let expectedOutput = audioDir.appendingPathComponent("synthetic-recording.md")
        let calls = LockedStringArray()

        let transcript = try await Transcriber.runCommand(
            inputPath: audioInput.path,
            model: "synthetic-whisper-model",
            language: "nl"
        ) { path, model, language in
            try expect(path == audioInput.path)
            try expect(model == "synthetic-whisper-model")
            try expect(language == "nl")
            calls.append("transcribe")
            return expectedTranscript
        }

        try expect(transcript == expectedTranscript)
        try expect(calls.snapshot() == ["transcribe"])
        try expect(try String(contentsOf: expectedOutput, encoding: .utf8) == expectedTranscript)
    }

    await testAsync("Transcribe CLI: failed fake inference preserves an existing output") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogTranscribeFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let audioInput = root.appendingPathComponent("synthetic-recording.m4a")
        try Data([0, 1, 2, 3]).write(to: audioInput)
        let output = root.appendingPathComponent("transcript.md")
        try "Previous transcript".write(to: output, atomically: true, encoding: .utf8)

        do {
            _ = try await Transcriber.runCommand(inputPath: audioInput.path, outputPath: output.path) { _, _, _ in
                throw NSError(domain: "TranscribeCommandTests", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Synthetic transcription failure",
                ])
            }
            try expect(false, "The injected transcription error should propagate")
        } catch let error as NSError {
            try expect(error.localizedDescription == "Synthetic transcription failure")
        }

        try expect(try String(contentsOf: output, encoding: .utf8) == "Previous transcript")
    }

    await testAsync("Transcribe CLI: output write failure is surfaced after inference") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogTranscribeWriteFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let fixture = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("eval/transcribe/audio/durins-volk.m4a")
        let input = root.appendingPathComponent("synthetic-recording.m4a")
        try fm.copyItem(at: fixture, to: input)
        let originalAudio = try Data(contentsOf: input)
        let outputDirectory = root.appendingPathComponent("transcript.md", isDirectory: true)
        try fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let inferenceCalls = LockedStringArray()

        do {
            _ = try await Transcriber.runCommand(
                inputPath: input.path,
                outputPath: outputDirectory.path,
                model: "synthetic-whisper-model",
                language: "nl"
            ) { audioPath, model, language in
                try expect(audioPath == input.path)
                try expect(model == "synthetic-whisper-model")
                try expect(language == "nl")
                inferenceCalls.append("transcribe")
                return "Synthetic transcript."
            }
            try expect(false, "A directory at the transcript path should cause a write error")
        } catch let error as CaptainsLogFileSystemError {
            guard case .writeFailed(let path, _) = error else {
                try expect(false, "Expected a writeFailed filesystem error")
                return
            }
            try expect(path == outputDirectory.path)
        }

        try expect(inferenceCalls.snapshot() == ["transcribe"], "Inference should complete before the output write fails")
        try expect(fm.fileExists(atPath: outputDirectory.path), "The pre-existing output directory must be preserved")
        try expect(try Data(contentsOf: input) == originalAudio, "The eval audio input must remain unchanged")
    }

    await testAsync("Filename CLI: fake inference receives the date and returns its slug") {
        let repository = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let input = repository.appendingPathComponent("eval/filename/input/01_single_topic.md")
        let expectedText = try String(contentsOf: input, encoding: .utf8)
        let calls = LockedStringArray()
        let expectedFilename = "2025-01-14-garden-planning.md"

        let filename = try await Filename.runCommand(
            inputPath: input.path,
            date: "2025-01-14"
        ) { logText, date, promptPath in
            try expect(logText == expectedText)
            try expect(date == "2025-01-14")
            try expect(promptPath == Filename.defaultPromptPath)
            calls.append("filename")
            return expectedFilename
        }

        try expect(filename == expectedFilename)
        try expect(calls.snapshot() == ["filename"])
    }

    await testAsync("Filename CLI: print-prompt renders the request without running inference") {
        let input = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("eval/filename/input/01_single_topic.md")
        let calls = LockedStringArray()

        let result = try await Filename.runCommand(
            inputPath: input.path,
            date: "2025-01-14",
            printPrompt: true
        ) { _, _, _ in
            calls.append("inference")
            throw NSError(domain: "FilenameCommandTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Prompt-only mode must not run inference",
            ])
        }

        try expect(result == nil, "Prompt-only mode should not return a generated filename")
        try expect(calls.snapshot().isEmpty, "Prompt-only mode must not invoke inference")
    }

    await testAsync("Filename CLI: fake inference errors propagate without returning a slug") {
        let input = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("eval/filename/input/01_single_topic.md")
        do {
            _ = try await Filename.runCommand(inputPath: input.path, date: "2025-01-14") { _, _, _ in
                throw NSError(domain: "FilenameCommandTests", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Synthetic filename failure",
                ])
            }
            try expect(false, "The injected filename error should propagate")
        } catch let error as NSError {
            try expect(error.localizedDescription == "Synthetic filename failure")
        }
    }

    await testAsync("Enrich CLI: fake inference receives metadata and writes the requested output") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogEnrichCommand-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        let repository = URL(fileURLWithPath: fm.currentDirectoryPath)
        let input = repository.appendingPathComponent("eval/enrich/input/01_work_week.md")
        let expectedText = try String(contentsOf: input, encoding: .utf8)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let output = root.appendingPathComponent("enriched.md")
        let config = CaptainsLogConfig(dataDir: root.path)
        let calls = LockedStringArray()
        let expectedEnriched = "---\nsummary: synthetic\n---\n\n\(expectedText)"

        let result = try await Enrich.runCommand(
            inputPath: input.path,
            outputPath: output.path,
            date: "2025-01-14",
            recordingTime: "08:30",
            config: config
        ) { logText, date, recordingTime, receivedConfig, promptPath in
            try expect(logText == expectedText)
            try expect(date == "2025-01-14")
            try expect(recordingTime == "08:30")
            try expect(receivedConfig.dataDir == root.path)
            try expect(promptPath == Enrich.defaultPromptPath)
            calls.append("enrich")
            return expectedEnriched
        }

        try expect(result == expectedEnriched)
        try expect(calls.snapshot() == ["enrich"])
        try expect(try String(contentsOf: output, encoding: .utf8) == expectedEnriched)
    }

    await testAsync("Cleanup and Enrich CLI: omitted output paths write to the isolated working directory") {
        let fm = FileManager.default
        let originalDirectory = fm.currentDirectoryPath
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogDefaultCommandOutputs-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            _ = fm.changeCurrentDirectoryPath(originalDirectory)
            try? fm.removeItem(at: root)
        }
        try expect(fm.changeCurrentDirectoryPath(root.path), "The test should isolate relative CLI outputs")

        let repository = URL(fileURLWithPath: originalDirectory)
        let cleanupInput = repository.appendingPathComponent("eval/cleanup/input/book-reference.md")
        let cleanupOutput = root.appendingPathComponent(cleanupInput.lastPathComponent)
        let cleanupPrompt = repository.appendingPathComponent(Cleanup.defaultPromptPath).path
        let cleanupResult = try await Cleanup.runCommand(inputPath: cleanupInput.path, promptPath: cleanupPrompt) { _, _, _ in
            return "synthetic cleaned transcript"
        }
        try expect(cleanupResult == "synthetic cleaned transcript")
        try expect(
            try String(contentsOf: cleanupOutput, encoding: .utf8) == "synthetic cleaned transcript",
            "Cleanup should use the input basename when no output path is supplied"
        )

        let enrichInput = repository.appendingPathComponent("eval/enrich/input/01_work_week.md")
        let enrichOutput = root.appendingPathComponent(enrichInput.lastPathComponent)
        let enrichPrompt = repository.appendingPathComponent(Enrich.defaultPromptPath).path
        let enrichResult = try await Enrich.runCommand(
            inputPath: enrichInput.path,
            date: "2025-01-14",
            promptPath: enrichPrompt
        ) {
            _, _, _, _, _ in "synthetic enriched entry"
        }
        try expect(enrichResult == "synthetic enriched entry")
        try expect(
            try String(contentsOf: enrichOutput, encoding: .utf8) == "synthetic enriched entry",
            "Enrich should use the input basename when no output path is supplied"
        )
    }

    await testAsync("Enrich CLI: failed fake inference preserves an existing output") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogEnrichFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        let input = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("eval/enrich/input/01_work_week.md")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let output = root.appendingPathComponent("enriched.md")
        try "Previous enriched text".write(to: output, atomically: true, encoding: .utf8)

        do {
            _ = try await Enrich.runCommand(
                inputPath: input.path,
                outputPath: output.path,
                date: "2025-01-14",
                recordingTime: "08:30",
                config: CaptainsLogConfig(dataDir: root.path)
            ) { _, _, _, _, _ in
                throw NSError(domain: "EnrichCommandTests", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Synthetic enrichment failure",
                ])
            }
            try expect(false, "The injected enrichment error should propagate")
        } catch let error as NSError {
            try expect(error.localizedDescription == "Synthetic enrichment failure")
        }

        try expect(try String(contentsOf: output, encoding: .utf8) == "Previous enriched text")
    }

    await testAsync("Enrich CLI: output write failure is surfaced after inference") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogEnrichWriteFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        let input = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("eval/enrich/input/01_work_week.md")
        let originalInput = try String(contentsOf: input, encoding: .utf8)
        let outputDirectory = root.appendingPathComponent("enriched.md", isDirectory: true)
        try fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let inferenceCalls = LockedStringArray()

        do {
            _ = try await Enrich.runCommand(
                inputPath: input.path,
                outputPath: outputDirectory.path,
                date: "2025-01-14",
                recordingTime: "08:30",
                config: CaptainsLogConfig(dataDir: root.path)
            ) { logText, date, recordingTime, _, _ in
                try expect(logText == originalInput)
                try expect(date == "2025-01-14")
                try expect(recordingTime == "08:30")
                inferenceCalls.append("enrich")
                return "Synthetic enriched output."
            }
            try expect(false, "A directory at the output path should cause a write error")
        } catch let error as CaptainsLogFileSystemError {
            guard case .writeFailed(let path, _) = error else {
                try expect(false, "Expected a writeFailed filesystem error")
                return
            }
            try expect(path == outputDirectory.path)
        }

        try expect(inferenceCalls.snapshot() == ["enrich"], "Inference should complete before the output write fails")
        try expect(fm.fileExists(atPath: outputDirectory.path), "The pre-existing output directory must be preserved")
        try expect(try String(contentsOf: input, encoding: .utf8) == originalInput, "The eval input must remain unchanged")
    }

    await testAsync("Cleanup CLI: fake inference writes the requested output") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogCleanupCommand-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        let repository = URL(fileURLWithPath: fm.currentDirectoryPath)
        let input = repository.appendingPathComponent("eval/cleanup/input/book-reference.md")
        let expectedTranscript = try String(contentsOf: input, encoding: .utf8)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let output = root.appendingPathComponent("cleaned.md")
        let config = CaptainsLogConfig(dataDir: root.path)
        let calls = LockedStringArray()
        let expectedCleanup = "Cleaned synthetic transcript."

        let result = try await Cleanup.runCommand(
            inputPath: input.path,
            outputPath: output.path,
            config: config
        ) { transcript, receivedConfig, promptPath in
            try expect(transcript == expectedTranscript)
            try expect(receivedConfig.dataDir == root.path)
            try expect(promptPath == Cleanup.defaultPromptPath)
            calls.append("cleanup")
            return expectedCleanup
        }

        try expect(result == expectedCleanup)
        try expect(calls.snapshot() == ["cleanup"])
        try expect(try String(contentsOf: output, encoding: .utf8) == expectedCleanup)
    }

    await testAsync("Cleanup CLI: failed fake inference preserves an existing output") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogCleanupFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        let input = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("eval/cleanup/input/book-reference.md")
        let output = root.appendingPathComponent("cleaned.md")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try "Previous cleaned text".write(to: output, atomically: true, encoding: .utf8)

        do {
            _ = try await Cleanup.runCommand(
                inputPath: input.path,
                outputPath: output.path,
                config: CaptainsLogConfig(dataDir: root.path)
            ) { _, _, _ in
                throw NSError(domain: "CleanupCommandTests", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Synthetic cleanup failure",
                ])
            }
            try expect(false, "The injected cleanup error should propagate")
        } catch let error as NSError {
            try expect(error.localizedDescription == "Synthetic cleanup failure")
        }

        try expect(try String(contentsOf: output, encoding: .utf8) == "Previous cleaned text")
    }

    await testAsync("Cleanup CLI: output write failure is surfaced after inference") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogCleanupWriteFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        let input = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("eval/cleanup/input/book-reference.md")
        let originalInput = try String(contentsOf: input, encoding: .utf8)
        let outputDirectory = root.appendingPathComponent("cleaned.md", isDirectory: true)
        try fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let inferenceCalls = LockedStringArray()

        do {
            _ = try await Cleanup.runCommand(
                inputPath: input.path,
                outputPath: outputDirectory.path,
                config: CaptainsLogConfig(dataDir: root.path)
            ) { transcript, _, _ in
                try expect(transcript == originalInput)
                inferenceCalls.append("cleanup")
                return "Cleaned synthetic transcript."
            }
            try expect(false, "A directory at the output path should cause a write error")
        } catch let error as CaptainsLogFileSystemError {
            guard case .writeFailed(let path, _) = error else {
                try expect(false, "Expected a writeFailed filesystem error")
                return
            }
            try expect(path == outputDirectory.path)
        }

        try expect(inferenceCalls.snapshot() == ["cleanup"], "Inference should complete before the output write fails")
        try expect(fm.fileExists(atPath: outputDirectory.path), "The pre-existing output directory must be preserved")
        try expect(try String(contentsOf: input, encoding: .utf8) == originalInput, "The eval input must remain unchanged")
    }

    await testAsync("Categorize CLI: fake inference writes its manifest and diagnostics") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogCategorizeCommand-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        let repository = URL(fileURLWithPath: fm.currentDirectoryPath)
        let input = repository.appendingPathComponent("eval/categorize/input/side-project-voice-app.md")
        let expectedText = try String(contentsOf: input, encoding: .utf8)
        let output = root.appendingPathComponent("nested/custom-manifest.json")
        let config = CaptainsLogConfig(dataDir: root.path)
        let calls = LockedStringArray()

        let category = try await Categorize.runCommand(
            inputPath: input.path,
            outputPath: output.path,
            config: config
        ) { text, receivedConfig, promptPath, diagnostic in
            try expect(text == expectedText, "The categorize command should pass the fixture text to its operation")
            try expect(receivedConfig.dataDir == root.path, "The command should pass through its configured data folder")
            try expect(promptPath == Categorize.defaultPromptPath)
            calls.append("inference")
            await diagnostic("Synthetic category operation completed")
            return .sideProject
        }

        try expect(category == .sideProject)
        try expect(calls.snapshot() == ["inference"], "The injected operation should run exactly once")
        let manifest = try JSONDecoder().decode(Categorize.Manifest.self, from: Data(contentsOf: output))
        try expect(manifest.sourceStem == "side-project-voice-app")
        try expect(manifest.category == .sideProject)
        let diagnosticText = try String(contentsOfFile: output.path + ".log", encoding: .utf8)
        try expect(diagnosticText.contains("Synthetic category operation completed"))
    }

    await testAsync("Categorize CLI: fake inference failure preserves diagnostics without a manifest") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogCategorizeFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        let input = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("eval/categorize/input/side-project-voice-app.md")
        let output = root.appendingPathComponent("nested/category.json")
        do {
            _ = try await Categorize.runCommand(
                inputPath: input.path,
                outputPath: output.path,
                config: CaptainsLogConfig(dataDir: root.path)
            ) { _, _, _, diagnostic in
                await diagnostic("Synthetic category inference failed")
                throw NSError(domain: "CategorizeCommandTests", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Synthetic inference failure",
                ])
            }
            try expect(false, "The injected inference error should propagate")
        } catch let error as NSError {
            try expect(error.localizedDescription == "Synthetic inference failure")
        }

        try expect(!fm.fileExists(atPath: output.path), "A failed command must not leave a category manifest")
        let diagnosticText = try String(contentsOfFile: output.path + ".log", encoding: .utf8)
        try expect(diagnosticText.contains("Synthetic category inference failed"))
    }

    await testAsync("Categorize CLI: manifest write failure preserves diagnostics and the existing directory") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogCategorizeWriteFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        let input = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("eval/categorize/input/side-project-voice-app.md")
        let originalInput = try String(contentsOf: input, encoding: .utf8)
        let outputDirectory = root.appendingPathComponent("nested/category.json", isDirectory: true)
        try fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let calls = LockedStringArray()

        do {
            _ = try await Categorize.runCommand(
                inputPath: input.path,
                outputPath: outputDirectory.path,
                config: CaptainsLogConfig(dataDir: root.path)
            ) { text, _, _, diagnostic in
                try expect(text == originalInput)
                calls.append("categorize")
                await diagnostic("Synthetic category completed before manifest write")
                return .sideProject
            }
            try expect(false, "A directory at the manifest path should cause a write error")
        } catch let error as CaptainsLogFileSystemError {
            guard case .writeFailed(let path, _) = error else {
                try expect(false, "Expected a writeFailed filesystem error")
                return
            }
            try expect(path == outputDirectory.path)
        }

        try expect(calls.snapshot() == ["categorize"], "Inference should complete before the manifest write fails")
        try expect(fm.fileExists(atPath: outputDirectory.path), "The pre-existing manifest directory must be preserved")
        let diagnosticText = try String(contentsOfFile: outputDirectory.path + ".log", encoding: .utf8)
        try expect(diagnosticText.contains("Synthetic category completed before manifest write"))
        try expect(try String(contentsOf: input, encoding: .utf8) == originalInput, "The eval input must remain unchanged")
    }

    test("AppState: loads completed and pending eval entries for the Logs screen") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogAppWorkflow-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        let repository = URL(fileURLWithPath: fm.currentDirectoryPath)
        let completedFixture = repository.appendingPathComponent("eval/enrich/expected/02_personal_only.md")
        let pendingFixture = repository.appendingPathComponent("eval/transcribe/expected/durins-volk.md")
        try expect(fm.fileExists(atPath: completedFixture.path), "Missing repository enrichment fixture")
        try expect(fm.fileExists(atPath: pendingFixture.path), "Missing repository transcription fixture")

        let completedStem = "2025-01-15-1200"
        let completedSlug = "2025-01-15-weekend-with-family"
        let completedURL = root.appendingPathComponent("logs/personal/\(completedSlug).md")
        try fm.createDirectory(at: completedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: completedFixture, to: completedURL)
        let markerDir = root.appendingPathComponent(".pipeline/04-rename")
        try fm.createDirectory(at: markerDir, withIntermediateDirectories: true)
        try fm.copyItem(at: completedURL, to: markerDir.appendingPathComponent("\(completedSlug).md"))
        let cleanedDir = root.appendingPathComponent(".pipeline/02-logs")
        try fm.createDirectory(at: cleanedDir, withIntermediateDirectories: true)
        try fm.copyItem(at: completedURL, to: cleanedDir.appendingPathComponent("\(completedStem).md"))
        let completedTranscript = root.appendingPathComponent(".pipeline/01-transcribed/\(completedStem).md")
        try fm.createDirectory(at: completedTranscript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: pendingFixture, to: completedTranscript)
        try completedSlug.write(
            to: markerDir.appendingPathComponent("\(completedStem).slug.txt"),
            atomically: true,
            encoding: .utf8
        )
        try Categorize.writeManifest(
            .init(sourceStem: completedStem, category: .personal), dataDirURL: root
        )

        let pendingStem = "2025-01-14-0830"
        let transcriptURL = root.appendingPathComponent(".pipeline/01-transcribed/\(pendingStem).md")
        try fm.createDirectory(at: transcriptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: pendingFixture, to: transcriptURL)

        let config = ConfigManager()
        config.dataDir = root.path
        let coordinator = ProcessingCoordinator()
        let appState = AppState(config: config, processing: coordinator)
        appState.loadEntries()

        try expect(appState.allEntries.count == 2, "Expected one completed and one pending log")
        try expect(appState.pendingEntries.count == 1, "Expected transcript-only log to remain pending")
        guard let completed = appState.allEntries.first(where: { $0.stem == completedStem }),
              let pending = appState.pendingEntries.first else {
            throw NSError(domain: "TestError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Expected completed and pending log entries",
            ])
        }
        try expect(completed.stage == .done, "Completed eval note should be marked done")
        try expect(completed.slug == completedSlug, "Completed note should retain its display slug")
        try expect(completed.path == completedURL.path, "Completed note should point at the enriched Markdown")
        try expect(completed.summary?.contains("relaxing weekend") == true, "Completed note summary should load")
        try expect(completed.tags.contains("family"), "Completed note tags should load")
        try expect(completed.projects.isEmpty, "Completed note without projects should show none")
        try expect(completed.recordingTime == "12:00", "Frontmatter recording time should be shown")
        try expect(try completed.readableBody().isEmpty, "Entry without a body should present its empty-content state")

        try expect(pending.stem == pendingStem, "Pending note should retain its recording stem")
        try expect(pending.stage == .cleaning, "Transcript-only note should offer cleanup as next step")
        try expect(pending.slug == nil, "Un-named note should not have a slug")
        try expect(pending.recordingTime == "08:30", "Pending note time should fall back to timestamp")
        try expect(pending.path == transcriptURL.path, "Pending note should open its latest transcript")

        coordinator.recordPreparationFailure(
            NSError(domain: "SyntheticPipeline", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Synthetic retryable failure",
            ]),
            for: pendingStem
        )
        let displayedPending = appState.allEntries.first(where: { $0.stem == pendingStem })
        try expect(displayedPending?.processingError == "Synthetic retryable failure", "Pending row should show a retryable processing error")
        try expect(displayedPending?.isActive == false)
        try expect(appState.pendingEntries.count == 1)
    }

    test("AppState: deleting a completed eval log moves every artifact and removes its row") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogDeleteWorkflow-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let repository = URL(fileURLWithPath: fm.currentDirectoryPath)
        let completedFixture = repository.appendingPathComponent("eval/enrich/expected/02_personal_only.md")
        let transcriptFixture = repository.appendingPathComponent("eval/transcribe/expected/durins-volk.md")
        let audioFixture = repository.appendingPathComponent("eval/transcribe/audio/durins-volk.m4a")
        let stem = "2025-01-15-1200"
        let slug = "2025-01-15-weekend-with-family"

        let enriched = root.appendingPathComponent("logs/personal/\(slug).md")
        let renamedDir = root.appendingPathComponent(".pipeline/04-rename")
        let cleaned = root.appendingPathComponent(".pipeline/02-logs/\(stem).md")
        let transcript = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        let audio = root.appendingPathComponent("audio/\(stem).m4a")
        try fm.createDirectory(at: enriched.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.createDirectory(at: renamedDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: cleaned.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.createDirectory(at: audio.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: completedFixture, to: enriched)
        try fm.copyItem(at: completedFixture, to: renamedDir.appendingPathComponent("\(slug).md"))
        try fm.copyItem(at: completedFixture, to: cleaned)
        try fm.copyItem(at: transcriptFixture, to: transcript)
        try fm.copyItem(at: audioFixture, to: audio)
        try slug.write(
            to: renamedDir.appendingPathComponent("\(stem).slug.txt"),
            atomically: true,
            encoding: .utf8
        )
        try Categorize.writeManifest(.init(sourceStem: stem, category: .personal), dataDirURL: root)

        let moved = LockedStringArray()
        let config = ConfigManager()
        config.dataDir = root.path
        let appState = AppState(config: config, moveToTrash: { url in
            moved.append(url.path)
            if fm.fileExists(atPath: url.path) { try? fm.removeItem(at: url) }
        })
        appState.loadEntries()
        try expect(appState.allEntries.count == 1, "Completed log should appear before deletion")
        try expect(appState.allEntries[0].stage == .done, "Fixture entry should be complete before deletion")

        let candidates = Pipeline.deletionCandidatePaths(stem: stem, slug: slug, dataDir: root.path)
        appState.deleteEntry(stem: stem, slug: slug)

        try expect(moved.snapshot().sorted() == candidates.sorted(), "Delete should send every pipeline artifact to Trash")
        try expect(appState.allEntries.isEmpty, "Deleted entry should disappear from the Logs list")
        try expect(candidates.allSatisfy { !fm.fileExists(atPath: $0) }, "Delete should remove all fixture artifacts from the data directory")
    }

    test("AppState: cannot delete an entry while its pipeline is processing it") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogDeleteActive-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let stem = "2025-01-14-0830"
        let transcript = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        let fixture = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("eval/transcribe/expected/durins-volk.md")
        try fm.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: fixture, to: transcript)

        let moved = LockedStringArray()
        let config = ConfigManager()
        config.dataDir = root.path
        let processing = ProcessingCoordinator()
        processing.processingStem = stem
        let appState = AppState(config: config, processing: processing, moveToTrash: { moved.append($0.path) })
        appState.loadEntries()

        appState.deleteEntry(stem: stem, slug: nil)

        try expect(moved.snapshot().isEmpty, "Active entry artifacts must not be sent to Trash")
        try expect(fm.fileExists(atPath: transcript.path), "Active transcript must remain on disk")
        try expect(appState.allEntries.map(\.stem) == [stem], "Active entry must remain visible")
    }

    test("AppState: a failed Trash move leaves the fixture entry visible") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogDeleteFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let stem = "2025-01-14-0830"
        let transcript = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        let fixture = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("eval/transcribe/expected/durins-volk.md")
        try fm.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: fixture, to: transcript)

        let attempted = LockedStringArray()
        let config = ConfigManager()
        config.dataDir = root.path
        let appState = AppState(config: config, moveToTrash: { attempted.append($0.path) })
        appState.loadEntries()
        try expect(appState.allEntries.map(\.stem) == [stem], "Fixture entry should be listed before deletion")

        appState.deleteEntry(stem: stem, slug: nil)

        try expect(attempted.snapshot().contains(transcript.path), "Deletion should attempt to move the transcript")
        try expect(fm.fileExists(atPath: transcript.path), "Fake failed move should preserve the source artifact")
        try expect(appState.allEntries.map(\.stem) == [stem], "Entry should remain visible when its artifact remains")
    }

    test("AppState: reprocess without source audio preserves files and exposes a retryable error") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogReprocessMissingAudio-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let stem = "2025-01-14-0830"
        let transcript = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        let fixture = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("eval/transcribe/expected/durins-volk.md")
        try fm.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: fixture, to: transcript)

        let config = ConfigManager()
        config.dataDir = root.path
        let appState = AppState(config: config, processing: ProcessingCoordinator())
        appState.loadEntries()
        try expect(appState.allEntries.map(\.stem) == [stem])

        appState.reprocessEntry(stem: stem, slug: nil)

        try expect(fm.fileExists(atPath: transcript.path), "Missing audio must not delete the existing transcript")
        try expect(appState.allEntries.map(\.stem) == [stem], "Failed reprocess must leave the entry listed")
        try expect(
            appState.allEntries.first?.processingError?.contains("source recording is missing") == true,
            "The entry should expose the missing-audio failure for retry or explanation"
        )
        try expect(appState.errorMessage?.contains("source recording is missing") == true)
        try expect(appState.statusMessage == "Processing failed. Retry available.")
        try expect(appState.processing.processingStem == nil)
    }

    test("AppState: reprocess does not reset an entry while another entry is active") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogReprocessWhileActive-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let stem = "2025-01-14-0830"
        let transcript = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        try fm.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "fixture transcript".write(to: transcript, atomically: true, encoding: .utf8)

        let config = ConfigManager(loadContextFiles: false)
        config.dataDir = root.path
        let processing = ProcessingCoordinator()
        processing.processingStem = "2025-01-15-0900"
        let appState = AppState(config: config, processing: processing)

        appState.reprocessEntry(stem: stem, slug: nil)

        try expect(try String(contentsOf: transcript, encoding: .utf8) == "fixture transcript")
        try expect(processing.processingStem == "2025-01-15-0900")
        try expect(Pipeline.detectNextStage(stem: stem, dataDir: root.path) == .cleaning)
    }

    await testAsync("AppState: failed resume keeps the log pending and reports its stage") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogPreparationFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let stem = "2025-01-14-0830"
        let transcript = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        let fixture = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("eval/transcribe/expected/durins-volk.md")
        try fm.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: fixture, to: transcript)

        let config = ConfigManager()
        config.dataDir = root.path
        let processing = ProcessingCoordinator { _, _, _, _ in
            throw NSError(domain: "SyntheticPipeline", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "cleanup prompt unavailable",
            ])
        }
        let appState = AppState(config: config, processing: processing)
        appState.loadEntries()
        appState.resumeProcessing(stem: stem, fromStage: .cleaning)
        for _ in 0..<1_000 where appState.errorMessage == nil {
            try await Task.sleep(for: .milliseconds(1))
        }

        try expect(appState.allEntries.count == 1)
        try expect(appState.allEntries[0].stage == .cleaning, "Failed preparation should retain cleanup as the next stage")
        try expect(appState.allEntries[0].processingError?.contains("prompt") == true, "A missing cleanup prompt should be attached to the pending row")
        try expect(appState.errorMessage?.contains("prompt") == true)
        try expect(appState.statusMessage == "Processing failed. Retry available.")
        try expect(fm.fileExists(atPath: transcript.path), "A failed resume must preserve its source transcript")
    }

    await testAsync("AppState: resumes a pending log through injected pipeline operations") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogResumeWorkflow-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let repository = URL(fileURLWithPath: fm.currentDirectoryPath)
        let fixture = repository.appendingPathComponent("eval/transcribe/expected/durins-volk.md")
        let stem = "2025-01-14-0830"
        let transcriptURL = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        try fm.createDirectory(at: transcriptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: fixture, to: transcriptURL)

        let calls = LockedStringArray()
        let operations = Pipeline.Operations(
            transcribe: { _, _ in calls.append("transcribe"); return "unexpected" },
            cleanup: { transcript, _ in
                calls.append("cleanup")
                try await Task.sleep(for: .milliseconds(80))
                return "A synthetic completed entry derived from the repository fixture."
            },
            categorize: { _, _, _ in calls.append("categorize"); return .personal },
            filename: { _, date in calls.append("filename"); return "\(date)-fixture-resume.md" },
            enrich: { cleaned, date, time, _ in
                calls.append("enrich")
                return """
                ---
                date: "\(date)"
                recording_time: "\(time)"
                summary: "Fixture resumed"
                ---

                \(cleaned)
                """
            }
        )
        let coordinator = ProcessingCoordinator { stem, dataDir, fromStage, progress in
            try await Pipeline.resume(
                stem: stem,
                dataDir: dataDir,
                fromStage: fromStage,
                operations: operations,
                progress: progress
            )
        }
        let config = ConfigManager()
        config.dataDir = root.path
        let appState = AppState(config: config, processing: coordinator)
        appState.loadEntries()
        try expect(appState.pendingEntries.count == 1)

        appState.resumeProcessing(stem: stem)
        for _ in 0..<100 where coordinator.processingStem != stem || coordinator.stage != .cleaning {
            await Task.yield()
        }
        try expect(coordinator.processingStem == stem, "Resume action should set the active stem")
        try expect(coordinator.stage == .cleaning, "Resume action should expose the active pipeline stage")
        try expect(appState.allEntries.first?.isActive == true, "Logs row should show the active state")

        for _ in 0..<200 where coordinator.processingStem != nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        try expect(coordinator.processingStem == nil, "Completed resume should clear the active stem")
        try expect(coordinator.stage == .done, "Completed resume should report done")
        try expect(appState.allEntries.count == 1, "Resume should preserve one log entry")
        try expect(appState.allEntries[0].stage == .done, "Enriched eval should no longer be pending; stage is \(appState.allEntries[0].stage.rawValue)")
        try expect(appState.allEntries[0].displayName == "2025-01-14-fixture-resume", "Logs row should adopt the generated display name")
        try expect(appState.pendingEntries.isEmpty, "Completed resume should clear the queue")
        try expect(calls.snapshot() == ["cleanup", "categorize", "filename", "enrich"], "Resume should run each remaining local stage once")
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

    test("Core coverage: CLI data directory follows explicit-config-environment-default precedence") {
        try expect(
            CaptainsLogConfig.resolveDataDir(
                explicit: "/explicit", configured: "/configured", environment: "/environment"
            ) == "/explicit"
        )
        try expect(
            CaptainsLogConfig.resolveDataDir(
                explicit: nil, configured: "/configured", environment: "/environment"
            ) == "/configured"
        )
        try expect(
            CaptainsLogConfig.resolveDataDir(
                explicit: nil, configured: nil, environment: "/environment"
            ) == "/environment"
        )
        try expect(
            CaptainsLogConfig.resolveDataDir(explicit: nil, configured: nil, environment: nil)
                == "processed"
        )
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

    test("Core coverage: LLM model resolution prioritizes explicit, configured, then default IDs") {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let priorConfigPath = getenv("CAPTAINS_LOG_CONFIG_PATH").map { String(cString: $0) }
        let isolatedConfigPath = root.appendingPathComponent("config.json").path
        setenv("CAPTAINS_LOG_CONFIG_PATH", isolatedConfigPath, 1)
        defer {
            if let priorConfigPath {
                setenv("CAPTAINS_LOG_CONFIG_PATH", priorConfigPath, 1)
            } else {
                unsetenv("CAPTAINS_LOG_CONFIG_PATH")
            }
        }

        try CaptainsLogConfig(dataDir: root.path, qwenModelId: "configured/model").save()
        try expect(LLM.resolveModelId() == "configured/model")
        try expect(LLM.resolveModelId("custom/model") == "custom/model")

        try CaptainsLogConfig(dataDir: root.path).save()
        try expect(LLM.resolveModelId() == LLM.defaultModelId)
    }

    test("Core coverage: enrich prompt omits recording time when unknown") {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let promptURL = root.appendingPathComponent("prompt.md")
        try "date: {date}\nrecording_time: {recording_time}\ninstruction: Preserve mentions of recording_time in prose.\n{ENRICH_SPEAKER_CONTEXT_SECTION}".write(
            to: promptURL, atomically: true, encoding: .utf8)
        let prompt = try Enrich.loadPrompt(
            from: promptURL.path, date: "2026-07-10", recordingTime: nil,
            config: CaptainsLogConfig(dataDir: root.path)
        )
        try expect(prompt.contains("date: 2026-07-10"))
        try expect(!prompt.contains("recording_time:"), "The empty YAML field should be removed")
        try expect(
            prompt.contains("Preserve mentions of recording_time in prose."),
            "Unrelated instructions mentioning the field should remain in the prompt"
        )
    }

    test("Core coverage: category manifests round-trip and missing manifests fail") {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let expectedFolders: [Categorize.Category: String] = [
            .personal: "personal",
            .professional: "professional",
            .sideProject: "side-project",
        ]
        for (index, category) in Categorize.Category.allCases.enumerated() {
            let stem = "2026-07-10-category-\(index)"
            let manifest = Categorize.Manifest(sourceStem: stem, category: category)
            try Categorize.writeManifest(manifest, dataDirURL: root)
            try expect(try Categorize.loadManifest(stem: stem, dataDirURL: root) == manifest)
            try expect(category.folderName == expectedFolders[category])
        }
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

        let invalidCalendarDate = LogEntry(
            stem: "2026-02-30-0815",
            slug: nil,
            displayName: "Impossible date",
            path: entryURL.path,
            summary: nil,
            tags: [],
            projects: [],
            frontmatterTime: nil,
            stage: .cleaning
        )
        try expect(invalidCalendarDate.recordingDate == nil, "Impossible stem dates should not normalize into a different day")
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

    test("AppState: LogEntry tolerates incomplete frontmatter and preserves the note") {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let entryURL = root.appendingPathComponent("incomplete.md")
        let content = "---\nsummary: [unfinished YAML\ntags:\n  - work\n\nDraft body."
        try content.write(to: entryURL, atomically: true, encoding: .utf8)

        let entry = LogEntry.from(Pipeline.EntryListing(
            displayName: "Incomplete note",
            stem: "2026-07-10-1200",
            slug: "incomplete-note",
            nextStage: .done,
            latestPath: entryURL.path
        ))

        try expect(entry.summary == nil && entry.tags.isEmpty && entry.projects.isEmpty)
        try expect(entry.recordingTime == "12:00", "Timestamp fallback should remain available when frontmatter is incomplete")
        try expect(entry.readableBody() == content, "Malformed frontmatter should not make the note unreadable")
    }

    test("Entry row behavior: actions and status follow active, paused, failed, and completed state") {
        func entry(
            stage: Pipeline.Stage,
            isActive: Bool = false,
            error: String? = nil,
            path: String = "/tmp/eval-entry.md"
        ) -> LogEntry {
            LogEntry(
                stem: "2025-01-14-0830",
                slug: "2025-01-14-eval-entry",
                displayName: "Eval entry",
                path: path,
                summary: nil,
                tags: [],
                projects: [],
                frontmatterTime: nil,
                stage: stage,
                isActive: isActive,
                processingError: error
            )
        }

        let active = EntryRowBehavior(entry: entry(stage: .cleaning, isActive: true))
        try expect(active.status == .active("Cleaning"), "active stage should be shown")
        try expect(active.compactStatusLabel == "LIVE", "active row should show LIVE")
        try expect(!active.canOpen && !active.canResume && !active.canReprocess, "active row should not expose completed or retry actions")

        let paused = EntryRowBehavior(entry: entry(stage: .transcribing))
        try expect(paused.status == .paused, "inactive unfinished entry should be paused")
        try expect(paused.compactStatusLabel == "PAUSED", "paused row should show PAUSED")
        try expect(paused.canResume && paused.resumeTitle == "Resume processing", "paused row should offer resume")
        try expect(!paused.canOpen && !paused.canReprocess, "paused row should not expose completed actions")

        let failed = EntryRowBehavior(entry: entry(stage: .cleaning, error: "fixture failure"))
        try expect(failed.status == .failed, "error should take status precedence over paused")
        try expect(failed.compactStatusLabel == "ERROR" && failed.isFailure, "failed row should show its error status")
        try expect(failed.canResume && failed.resumeTitle == "Retry processing", "failed row should offer retry")
        try expect(!failed.canOpen && !failed.canReprocess, "failed row should not expose completed actions")

        let completed = EntryRowBehavior(entry: entry(stage: .done))
        try expect(completed.status == .processed, "done entries should be processed")
        try expect(completed.canOpen && completed.canReprocess, "done entries should open and reprocess")
        try expect(!completed.canResume && completed.resumeTitle == nil, "done entries should not resume")
        try expect(completed.canRevealInFinder, "non-empty path should be revealable")

        let pathless = EntryRowBehavior(entry: entry(stage: .done, path: ""))
        try expect(!pathless.canRevealInFinder, "pathless entry should not reveal in Finder")
    }

    test("Entry navigation state: selecting a log opens detail and back clears selection") {
        let entry = LogEntry(
            stem: "2025-01-14-0830",
            slug: "2025-01-14-eval-entry",
            displayName: "Eval entry",
            path: "/tmp/eval-entry.md",
            summary: nil,
            tags: [],
            projects: [],
            frontmatterTime: nil,
            stage: .done
        )
        var navigation = EntryNavigationState()
        try expect(navigation.selectedStem == nil, "The initial view should show the list")
        navigation.show(entry)
        try expect(navigation.selectedStem == entry.stem, "Selecting an entry should open its detail")
        navigation.returnToList()
        try expect(navigation.selectedStem == nil, "Returning should restore the list")
    }

    test("Record dock behavior: start, stop, pause, input selection, and meter follow recorder state") {
        let idle = RecordDockBehavior(isRecording: false, isPaused: false, inputDeviceCount: 0)
        try expect(idle.primaryAction == .start && idle.pauseAction == nil)
        try expect(!idle.canSelectInputDevice && !idle.showsAudioLevel)

        let recording = RecordDockBehavior(isRecording: true, isPaused: false, inputDeviceCount: 1)
        try expect(recording.primaryAction == .stop && recording.pauseAction == .pause)
        try expect(recording.canSelectInputDevice && recording.showsAudioLevel)

        let paused = RecordDockBehavior(isRecording: true, isPaused: true, inputDeviceCount: 1)
        try expect(paused.primaryAction == .stop && paused.pauseAction == .resume)
        try expect(!paused.showsAudioLevel)
    }

    test("Queue strip behavior: processing pauses; an idle queue offers pending work") {
        let processing = QueueStripBehavior(isProcessing: true, statusMessage: "Cleaning up", pendingCount: 3)
        try expect(processing.action == .pause && processing.statusLabel == "Cleaning up")

        let idle = QueueStripBehavior(isProcessing: false, statusMessage: "Stale status", pendingCount: 3)
        try expect(idle.action == .processPending && idle.statusLabel == "3 logs waiting")
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

    await testAsync("ProcessingCoordinator: retry clears a prior failure after success") {
        let attempts = LockedStringArray()
        let coordinator = ProcessingCoordinator { stem, _, _, _ in
            attempts.append(stem)
            if attempts.snapshot().count == 1 {
                throw NSError(domain: "Coverage", code: 2, userInfo: [NSLocalizedDescriptionKey: "Temporary failure"])
            }
            return result(for: stem)
        }

        let firstFailed: Bool = await withCheckedContinuation { continuation in
            coordinator.resumeEntry(
                stem: "retry-entry",
                dataDir: "/tmp/coverage",
                onComplete: { continuation.resume(returning: false) },
                onError: { _ in continuation.resume(returning: true) }
            )
        }
        try expect(firstFailed)
        try expect(coordinator.failureMessage(for: "retry-entry") == "Temporary failure")

        let retried: Bool = await withCheckedContinuation { continuation in
            coordinator.resumeEntry(
                stem: "retry-entry",
                dataDir: "/tmp/coverage",
                onComplete: { continuation.resume(returning: true) },
                onError: { _ in continuation.resume(returning: false) }
            )
        }
        try expect(retried)
        try expect(attempts.snapshot() == ["retry-entry", "retry-entry"], "Retry should invoke the failed entry again")
        try expect(coordinator.failureMessage(for: "retry-entry") == nil, "Successful retry should clear the entry failure")
        try expect(coordinator.errorMessage == nil, "Successful retry should clear the visible error")
        try expect(coordinator.stage == .done && coordinator.statusMessage == "Done")
        try expect(coordinator.processingStem == nil)
    }

    await testAsync("ProcessingCoordinator: process pending runs each discovered stage and reports completion") {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLogBatchResume-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fixture = repository.appendingPathComponent("eval/transcribe/expected/durins-volk.md")
        let stems = ["2025-01-14-0830", "2025-01-15-1015"]
        for stem in stems {
            let transcript = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
            try FileManager.default.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: fixture, to: transcript)
        }
        let processed = LockedStringArray()
        let coordinator = ProcessingCoordinator { stem, _, fromStage, progress in
            processed.append("\(stem):\(fromStage?.rawValue ?? "nil")")
            progress?(.init(stem: stem, stage: .cleaning))
            return result(for: stem)
        }
        let pending = stems.map { stem in
            LogEntry(
                stem: stem,
                slug: nil,
                displayName: stem,
                path: root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md").path,
                summary: nil,
                tags: [],
                projects: [],
                frontmatterTime: nil,
                stage: .cleaning
            )
        }
        var updates = 0
        let completed: Bool = await withCheckedContinuation { continuation in
            coordinator.batchResumePending(
                pendingEntries: pending,
                dataDir: root.path,
                onProgress: { updates += 1 },
                onComplete: { continuation.resume(returning: true) },
                onError: { _ in continuation.resume(returning: false) }
            )
        }

        try expect(completed, "Process pending should report completion")
        try expect(processed.snapshot() == stems.map { "\($0):cleaning" }, "Queue should resume in list order from each discovered stage")
        try expect(updates == stems.count, "Each completed entry should refresh the log list")
        try expect(coordinator.stage == .done, "Finished queue should show done")
        try expect(coordinator.statusMessage == "Done", "Finished queue should show completion status")
        try expect(coordinator.processingStem == nil, "Finished queue should clear the active stem")
    }

    await testAsync("ProcessingCoordinator: batch resume continues after one entry fails") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogBatchResumeFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let fixture = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("eval/transcribe/expected/durins-volk.md")
        let stems = ["2025-01-14-0830", "2025-01-15-1015"]
        let entries = try stems.map { stem -> LogEntry in
            let transcript = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
            try fm.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: fixture, to: transcript)
            return LogEntry(
                stem: stem,
                slug: nil,
                displayName: stem,
                path: transcript.path,
                summary: nil,
                tags: [],
                projects: [],
                frontmatterTime: nil,
                stage: .cleaning
            )
        }
        let processed = LockedStringArray()
        let coordinator = ProcessingCoordinator { stem, _, _, _ in
            processed.append(stem)
            if stem == stems[0] {
                throw NSError(domain: "Coverage", code: 3, userInfo: [NSLocalizedDescriptionKey: "First entry failed"])
            }
            return result(for: stem)
        }
        let errors = LockedStringArray()
        var updates = 0
        let completed: Bool = await withCheckedContinuation { continuation in
            coordinator.batchResumePending(
                pendingEntries: entries,
                dataDir: root.path,
                onProgress: { updates += 1 },
                onComplete: { continuation.resume(returning: true) },
                onError: { error in errors.append(error.localizedDescription) }
            )
        }

        try expect(completed, "A failed item should not prevent the rest of the batch from finishing")
        try expect(processed.snapshot() == stems, "Batch should attempt each pending entry in order")
        try expect(errors.snapshot() == ["First entry failed"], "Only the failed entry should report an error")
        try expect(updates == 2, "Both the failed and successful entries should refresh progress")
        try expect(coordinator.failureMessage(for: stems[0]) == "First entry failed")
        try expect(coordinator.failureMessage(for: stems[1]) == nil)
        try expect(coordinator.stage == .done && coordinator.statusMessage == "Done")
        try expect(coordinator.processingStem == nil)
    }

    await testAsync("ProcessingCoordinator: pausing an active queue stays paused after cancellation") {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLogPausedQueue-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fixture = repository.appendingPathComponent("eval/transcribe/expected/durins-volk.md")
        let stem = "2025-01-14-0830"
        let transcript = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        try FileManager.default.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: fixture, to: transcript)
        let coordinator = ProcessingCoordinator { stem, _, _, progress in
            progress?(.init(stem: stem, stage: .cleaning))
            try await Task.sleep(for: .seconds(30))
            return result(for: stem)
        }
        let appState = AppState(
            config: {
                let config = ConfigManager()
                config.dataDir = root.path
                return config
            }(),
            processing: coordinator
        )
        appState.loadEntries()
        try expect(appState.pendingEntries.count == 1)
        appState.batchResumePending()
        for _ in 0..<100 where coordinator.processingStem == nil {
            await Task.yield()
        }
        try expect(coordinator.processingStem == stem, "Queue should start the pending log")
        appState.pauseProcessing()
        try expect(coordinator.stage == .idle, "Pause should clear the active stage")
        try expect(coordinator.statusMessage == "Paused", "Pause should update the queue status")
        try expect(coordinator.processingStem == nil, "Pause should clear the active stem")
        try await Task.sleep(for: .milliseconds(30))
        try expect(coordinator.stage == .idle, "Cancelled queue should not overwrite Paused with Done")
        try expect(coordinator.statusMessage == "Paused", "Cancelled queue should preserve the paused status")
    }

    await testAsync("ProcessingCoordinator: pausing newly recorded work does not report completion") {
        let stem = "2025-01-14-0830"
        let coordinator = ProcessingCoordinator { stem, _, _, progress in
            progress?(.init(stem: stem, stage: .transcribing))
            try await Task.sleep(for: .seconds(30))
            return result(for: stem)
        }
        let completions = LockedStringArray()
        coordinator.queueProcessing(stem: stem)
        coordinator.startProcessing(
            dataDir: "/tmp/captainslog-paused-recording",
            isRecording: false,
            onProgress: {},
            onComplete: { completions.append("complete") },
            onError: { _ in completions.append("error") }
        )
        for _ in 0..<100 where coordinator.processingStem == nil {
            await Task.yield()
        }
        try expect(coordinator.processingStem == stem, "New recording should enter the processing queue")
        coordinator.pauseProcessing()
        try await Task.sleep(for: .milliseconds(30))
        try expect(coordinator.stage == .idle, "Paused recording queue should remain idle")
        try expect(coordinator.statusMessage == "Paused", "Paused recording queue should retain its status")
        try expect(coordinator.processingStem == nil, "Paused recording queue should clear its active stem")
        try expect(completions.snapshot().isEmpty, "Cancelled recording must not report completion")
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

    await testAsync("Resume CLI: batch resumes each pending fixture from its detected stage") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("PipelineBatchResumeCommand-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        func write(_ relativePath: String, _ text: String) throws {
            let url = root.appendingPathComponent(relativePath)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }

        let newerStem = "2025-01-15-0900"
        let olderStem = "2025-01-14-0800"
        try write(".pipeline/01-transcribed/\(newerStem).md", "newer raw")
        try write(".pipeline/02-logs/\(newerStem).md", "newer cleaned")
        try write(".pipeline/01-transcribed/\(olderStem).md", "older raw")

        let calls = LockedStringArray()
        let operations = Pipeline.Operations(
            transcribe: { _, _ in calls.append("transcribe"); return "unexpected" },
            cleanup: { transcript, _ in calls.append("cleanup:\(transcript)"); return "\(transcript) cleaned" },
            categorize: { cleaned, _, _ in calls.append("categorize:\(cleaned)"); return .professional },
            filename: { cleaned, date in
                calls.append("filename:\(cleaned)")
                return "\(date)-cli-\(cleaned.contains("newer") ? "newer" : "older").md"
            },
            enrich: { cleaned, date, recordingTime, _ in
                calls.append("enrich:\(cleaned):\(date):\(recordingTime)")
                return "---\nsummary: \(cleaned)\n---\n"
            }
        )

        let results = try await Pipeline.resumePendingCommand(dataDir: root.path, operations: operations)
        try expect(results.map { URL(fileURLWithPath: $0.audioPath).lastPathComponent } == [
            "\(newerStem).m4a", "\(olderStem).m4a",
        ])
        try expect(Pipeline.detectNextStage(stem: newerStem, dataDir: root.path) == .done)
        try expect(Pipeline.detectNextStage(stem: olderStem, dataDir: root.path) == .done)
        try expect(calls.snapshot() == [
            "categorize:newer cleaned",
            "filename:newer cleaned",
            "enrich:newer cleaned:2025-01-15:09:00",
            "cleanup:older raw",
            "categorize:older raw cleaned",
            "filename:older raw cleaned",
            "enrich:older raw cleaned:2025-01-14:08:00",
        ])

        let priorCalls = calls.snapshot()
        let noPendingResults = try await Pipeline.resumePendingCommand(dataDir: root.path, operations: operations)
        try expect(noPendingResults.isEmpty)
        try expect(calls.snapshot() == priorCalls, "An empty batch should not invoke any stage operations")
    }

    await testAsync("Pipeline CLI: injected operations require explicit audio input") {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PipelineCommandMissingInput-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let calls = LockedStringArray()
        let operations = Pipeline.Operations(
            transcribe: { _, _ in calls.append("transcribe"); return "unused" },
            cleanup: { _, _ in calls.append("cleanup"); return "unused" },
            categorize: { _, _, _ in calls.append("categorize"); return .personal },
            filename: { _, _ in calls.append("filename"); return "unused.md" },
            enrich: { _, _, _, _ in calls.append("enrich"); return "unused" }
        )

        do {
            _ = try await Pipeline.runCommand(dataDir: root.path, operations: operations)
            try expect(false, "Injected operations without audio must fail before recording")
        } catch let error as Pipeline.PipelineError {
            guard case .injectedOperationsRequireAudioInput = error else {
                throw NSError(domain: "TestError", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Unexpected pipeline command error: \(error)",
                ])
            }
        }

        try expect(calls.snapshot().isEmpty, "Missing audio should never start a model or recorder operation")
        try expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("audio").path))
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

    await testAsync("Pipeline CLI: fake fresh run copies eval audio and writes all stage artifacts") {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PipelineFreshRun-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("eval/transcribe/audio/2025-01-14 side project.m4a")
        let fixtureBytes = try Data(contentsOf: fixture)
        let stem = "2025-01-14 side project"
        let calls = LockedStringArray()
        let enrichMetadata = LockedStringArray()
        let progress = LockedStringArray()
        let operations = Pipeline.Operations(
            transcribe: { audioPath, _ in
                calls.append("transcribe")
                try expect(FileManager.default.fileExists(atPath: audioPath), "Transcriber should receive copied audio")
                try expect(try Data(contentsOf: URL(fileURLWithPath: audioPath)) == fixtureBytes, "Copied audio should match the eval fixture")
                return "fixture transcript"
            },
            cleanup: { transcript, _ in
                calls.append("cleanup")
                try expect(transcript == "fixture transcript")
                return "cleaned fixture entry"
            },
            categorize: { cleaned, _, _ in
                calls.append("categorize")
                try expect(cleaned == "cleaned fixture entry")
                return .sideProject
            },
            filename: { cleaned, date in
                calls.append("filename")
                try expect(date == "2025-01-14")
                try expect(cleaned == "cleaned fixture entry")
                return "\(date)-fixture-fresh-run.md"
            },
            enrich: { cleaned, date, recordingTime, _ in
                calls.append("enrich")
                enrichMetadata.append("\(date)|\(recordingTime)")
                try expect(cleaned == "cleaned fixture entry")
                return "---\nsummary: Fresh fixture run\n---\n\n\(cleaned)"
            }
        )

        let result = try await Pipeline.runCommand(
            audioInput: fixture.path,
            dataDir: root.path,
            language: "nl",
            operations: operations,
            progress: { progress.append($0.stage.rawValue) }
        )

        try expect(calls.snapshot() == ["transcribe", "cleanup", "categorize", "filename", "enrich"])
        try expect(enrichMetadata.snapshot().count == 1)
        try expect(enrichMetadata.snapshot()[0].hasPrefix("2025-01-14|"), "Enrich should receive the date parsed from the fixture name")
        try expect(enrichMetadata.snapshot()[0].split(separator: "|").last?.count == 5, "Enrich should receive an HH:mm recording time")
        try expect(progress.snapshot() == ["transcribing", "cleaning", "categorizing", "naming", "enriching", "done"])
        try expect(try Data(contentsOf: URL(fileURLWithPath: result.audioPath)) == fixtureBytes)
        try expect(try String(contentsOfFile: result.transcriptPath, encoding: .utf8) == "fixture transcript")
        try expect(try String(contentsOfFile: result.cleanedPath, encoding: .utf8) == "cleaned fixture entry")
        try expect(try String(contentsOfFile: result.renamedPath, encoding: .utf8) == "cleaned fixture entry")
        try expect(try String(contentsOfFile: result.enrichedPath, encoding: .utf8).contains("summary: Fresh fixture run"))
        try expect(result.category == .sideProject)
        try expect(result.slug == "2025-01-14-fixture-fresh-run.md")
        try expect(Pipeline.detectNextStage(stem: stem, dataDir: root.path) == .done)
    }

    await testAsync("Pipeline CLI: failure at each fresh stage preserves prior artifacts and retry stage") {
        let fm = FileManager.default
        let repository = URL(fileURLWithPath: fm.currentDirectoryPath)
        let fixture = repository.appendingPathComponent("eval/transcribe/audio/2025-01-14 side project.m4a")
        let stem = "2025-01-14 side project"
        let stages: [Pipeline.Stage] = [.transcribing, .cleaning, .categorizing, .naming, .enriching]
        let operationNames = ["transcribe", "cleanup", "categorize", "filename", "enrich"]

        for (failedIndex, failedStage) in stages.enumerated() {
            let root = fm.temporaryDirectory
                .appendingPathComponent("PipelineFreshFailure-\(failedStage.rawValue)-\(UUID().uuidString)", isDirectory: true)
            defer { try? fm.removeItem(at: root) }

            let failIfRequested: @Sendable (Pipeline.Stage) throws -> Void = { stage in
                guard failedStage == stage else { return }
                throw NSError(domain: "PipelineFreshCommandTests", code: failedIndex + 1, userInfo: [
                    NSLocalizedDescriptionKey: "Synthetic \(stage.rawValue) failure",
                ])
            }

            let calls = LockedStringArray()
            let progress = LockedStringArray()
            let operations = Pipeline.Operations(
                transcribe: { _, _ in
                    calls.append("transcribe")
                    try failIfRequested(.transcribing)
                    return "fixture transcript"
                },
                cleanup: { _, _ in
                    calls.append("cleanup")
                    try failIfRequested(.cleaning)
                    return "cleaned fixture"
                },
                categorize: { _, _, _ in
                    calls.append("categorize")
                    try failIfRequested(.categorizing)
                    return .sideProject
                },
                filename: { _, date in
                    calls.append("filename")
                    try failIfRequested(.naming)
                    return "\(date)-fake-failure.md"
                },
                enrich: { _, _, _, _ in
                    calls.append("enrich")
                    try failIfRequested(.enriching)
                    return "---\nsummary: should not be written\n---\n"
                }
            )

            do {
                _ = try await Pipeline.runCommand(
                    audioInput: fixture.path,
                    dataDir: root.path,
                    operations: operations,
                    progress: { progress.append($0.stage.rawValue) }
                )
                try expect(false, "Fresh pipeline should surface the injected \(failedStage.rawValue) failure")
            } catch let error as NSError {
                try expect(error.localizedDescription == "Synthetic \(failedStage.rawValue) failure")
            }

            try expect(calls.snapshot() == Array(operationNames.prefix(failedIndex + 1)))
            try expect(progress.snapshot() == stages.prefix(failedIndex + 1).map(\.rawValue))
            try expect(Pipeline.detectNextStage(stem: stem, dataDir: root.path) == failedStage)
            try expect(fm.fileExists(atPath: root.appendingPathComponent("audio/\(stem).m4a").path))
            try expect(
                fm.fileExists(atPath: root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md").path)
                    == (failedIndex >= 1),
                "Transcript existence should reflect whether transcription completed"
            )
            try expect(
                fm.fileExists(atPath: root.appendingPathComponent(".pipeline/02-logs/\(stem).md").path)
                    == (failedIndex >= 2),
                "Cleaned output should exist only after cleanup completed"
            )
            try expect(
                fm.fileExists(atPath: root.appendingPathComponent(".pipeline/03-category/\(stem).json").path)
                    == (failedIndex >= 3),
                "Category manifest should exist only after categorization completed"
            )
            try expect(
                fm.fileExists(atPath: root.appendingPathComponent(".pipeline/04-rename/\(stem).slug.txt").path)
                    == (failedIndex >= 4),
                "Slug marker should exist only after filename generation completed"
            )
            let enriched = root.appendingPathComponent("logs/side-project/2025-01-14-fake-failure.md")
            try expect(!fm.fileExists(atPath: enriched.path), "Failed pipeline must not leave enriched output")
        }
    }

    await testAsync("Pipeline CLI: importing destination audio preserves it and missing input fails safely") {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PipelineAudioSelfImport-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("eval/transcribe/audio/durins-volk.m4a")
        let expectedBytes = try Data(contentsOf: fixture)
        let stem = fixture.deletingPathExtension().lastPathComponent
        let audioURL = root.appendingPathComponent("audio/\(stem).m4a")
        try FileManager.default.createDirectory(
            at: audioURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: fixture, to: audioURL)

        let operations = Pipeline.Operations(
            transcribe: { _, _ in "fixture transcript" },
            cleanup: { _, _ in "fixture cleanup" },
            categorize: { _, _, _ in .personal },
            filename: { _, date in "\(date)-self-import.md" },
            enrich: { cleaned, _, _, _ in cleaned }
        )
        let result = try await Pipeline.runCommand(
            audioInput: audioURL.path, dataDir: root.path, operations: operations)
        try expect(result.audioPath == audioURL.path)
        try expect(try Data(contentsOf: audioURL) == expectedBytes)

        let missingInput = root.appendingPathComponent("not-present/\(stem).m4a")
        do {
            _ = try await Pipeline.runCommand(
                audioInput: missingInput.path, dataDir: root.path, operations: operations)
            try expect(false, "A missing source audio file should fail before processing")
        } catch {
            try expect(try Data(contentsOf: audioURL) == expectedBytes,
                "A failed import must not delete the existing destination audio")
        }
    }

    await testAsync("Resume CLI: auto-detects each stage and only runs remaining fake operations") {
        let resumeCases: [(Pipeline.Stage, [String])] = [
            (.transcribing, ["transcribe", "cleanup", "categorize", "filename", "enrich"]),
            (.cleaning, ["cleanup", "categorize", "filename", "enrich"]),
            (.categorizing, ["categorize", "filename", "enrich"]),
            (.naming, ["filename", "enrich"]),
            (.enriching, ["enrich"]),
            (.done, []),
        ]

        for (startStage, expectedCalls) in resumeCases {
            let stem = "2026-07-10-0815"
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("PipelineResume-\(startStage.rawValue)-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: root) }

            func write(_ relativePath: String, _ content: String) throws {
                let url = root.appendingPathComponent(relativePath)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try content.write(to: url, atomically: true, encoding: .utf8)
            }

            if startStage != .transcribing {
                try write(".pipeline/01-transcribed/\(stem).md", "raw transcript")
            } else {
                let audio = root.appendingPathComponent("audio/\(stem).m4a")
                try FileManager.default.createDirectory(at: audio.deletingLastPathComponent(), withIntermediateDirectories: true)
                let fixture = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent("eval/transcribe/audio/durins-volk.m4a")
                try FileManager.default.copyItem(at: fixture, to: audio)
            }
            let order: [Pipeline.Stage] = [.transcribing, .cleaning, .categorizing, .naming, .enriching, .done]
            let startIndex = order.firstIndex(of: startStage)!
            if startIndex >= order.firstIndex(of: .categorizing)! {
                try write(".pipeline/02-logs/\(stem).md", "cleaned entry")
            }
            if startIndex >= order.firstIndex(of: .naming)! {
                try Categorize.writeManifest(.init(sourceStem: stem, category: .professional), dataDirURL: root)
            }
            let slug = "2026-07-10-resume-\(startStage.rawValue)"
            if startIndex >= order.firstIndex(of: .enriching)! {
                try write(".pipeline/04-rename/\(stem).slug.txt", slug)
                try write(".pipeline/04-rename/\(slug).md", "renamed entry")
            }
            if startStage == .done {
                try write("logs/professional/\(slug).md", "---\nsummary: already complete\n---\n")
            }

            let calls = LockedStringArray()
            let progress = LockedStringArray()
            let operations = Pipeline.Operations(
                transcribe: { _, _ in calls.append("transcribe"); return "raw transcript" },
                cleanup: { _, _ in calls.append("cleanup"); return "cleaned entry" },
                categorize: { _, _, _ in calls.append("categorize"); return .professional },
                filename: { _, _ in calls.append("filename"); return "\(stem)-resume-\(startStage.rawValue).md" },
                enrich: { _, _, _, _ in calls.append("enrich"); return "---\nsummary: resumed\n---\n" }
            )

            _ = try await Pipeline.resumeCommand(
                stem: stem,
                dataDir: root.path,
                fromStage: startStage,
                language: "nl",
                operations: operations,
                progress: { progress.append($0.stage.rawValue) }
            )

            try expect(calls.snapshot() == expectedCalls, "Resume from \(startStage.rawValue) called \(calls.snapshot()), expected \(expectedCalls)")
            try expect(progress.snapshot().first == (startStage == .done ? "done" : startStage.rawValue), "Resume should report \(startStage.rawValue) as its first stage")
            try expect(progress.snapshot().last == "done", "Resume from \(startStage.rawValue) should finish at done")
        }
    }

    await testAsync("Resume CLI: an explicit later stage falls back when an intermediate artifact is missing") {
        let fm = FileManager.default
        let stem = "2026-07-10-1015"
        let root = fm.temporaryDirectory
            .appendingPathComponent("PipelineResumeMissingIntermediate-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let transcript = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        try fm.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "raw transcript".write(to: transcript, atomically: true, encoding: .utf8)

        let calls = LockedStringArray()
        let progress = LockedStringArray()
        let operations = Pipeline.Operations(
            transcribe: { _, _ in calls.append("transcribe"); return "unexpected transcript" },
            cleanup: { input, _ in
                calls.append("cleanup:\(input)")
                return "recovered cleaned entry"
            },
            categorize: { _, _, _ in calls.append("categorize"); return .personal },
            filename: { _, _ in calls.append("filename"); return "2026-07-10-recovered.md" },
            enrich: { _, _, _, _ in calls.append("enrich"); return "recovered enriched entry" }
        )

        let result = try await Pipeline.resumeCommand(
            stem: stem,
            dataDir: root.path,
            fromStage: .categorizing,
            operations: operations,
            progress: { progress.append($0.stage.rawValue) }
        )

        try expect(calls.snapshot() == [
            "cleanup:raw transcript", "categorize", "filename", "enrich",
        ], "Resume should fall back to cleanup when its output is absent")
        try expect(progress.snapshot().first == "cleaning", "The first reported stage must match the missing prerequisite")
        try expect(Pipeline.detectNextStage(stem: stem, dataDir: root.path) == .done)
        try expect(result.category == .personal)
        try expect(try String(contentsOf: transcript, encoding: .utf8) == "raw transcript")
    }

    await testAsync("Resume CLI: fake cleanup failure preserves the transcript and stage") {
        let stem = "2026-07-10-0915"
        let root = try makeRoot(stem: stem)
        defer { try? FileManager.default.removeItem(at: root) }
        let transcriptURL = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        let originalTranscript = try Data(contentsOf: transcriptURL)
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
            _ = try await Pipeline.resumeCommand(
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
        try expect(
            try Data(contentsOf: transcriptURL) == originalTranscript,
            "A failed cleanup stage must leave the transcript from the prior stage unchanged"
        )
        try expect(
            Pipeline.detectNextStage(stem: stem, dataDir: root.path) == .cleaning,
            "A failed cleanup stage should remain resumable at cleaning"
        )
        try expect(!FileManager.default.fileExists(
            atPath: root.appendingPathComponent(".pipeline/02-logs/\(stem).md").path
        ))
    }

    await testAsync("Resume CLI: cleanup cancellation preserves the transcript and remains retryable") {
        let stem = "2026-07-10-1115"
        let root = try makeRoot(stem: stem)
        defer { try? FileManager.default.removeItem(at: root) }
        let transcript = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        let originalTranscript = try Data(contentsOf: transcript)
        let calls = LockedStringArray()
        let progress = LockedStringArray()
        let operations = Pipeline.Operations(
            transcribe: { _, _ in calls.append("transcribe"); return "unused" },
            cleanup: { _, _ in
                calls.append("cleanup")
                throw CancellationError()
            },
            categorize: { _, _, _ in calls.append("categorize"); return .personal },
            filename: { _, _ in calls.append("filename"); return "unused.md" },
            enrich: { _, _, _, _ in calls.append("enrich"); return "unused" }
        )

        do {
            _ = try await Pipeline.resumeCommand(
                stem: stem,
                dataDir: root.path,
                fromStage: .cleaning,
                operations: operations,
                progress: { progress.append($0.stage.rawValue) }
            )
            try expect(false, "Cleanup cancellation should propagate")
        } catch is CancellationError {
            // Expected: cancellation is visible to the coordinator for cleanup.
        }

        try expect(calls.snapshot() == ["cleanup"], "Cancellation must stop later stages")
        try expect(progress.snapshot() == ["cleaning"], "Only the cancelled stage should be reported")
        try expect(try Data(contentsOf: transcript) == originalTranscript)
        try expect(Pipeline.detectNextStage(stem: stem, dataDir: root.path) == .cleaning)
        try expect(!FileManager.default.fileExists(
            atPath: root.appendingPathComponent(".pipeline/02-logs/\(stem).md").path
        ))
    }

    await testAsync("Resume CLI: malformed category manifest reruns categorization before later stages") {
        let stem = "2026-07-10-1215"
        let root = try makeRoot(stem: stem)
        defer { try? FileManager.default.removeItem(at: root) }
        let cleaned = root.appendingPathComponent(".pipeline/02-logs/\(stem).md")
        try FileManager.default.createDirectory(at: cleaned.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "cleaned entry".write(to: cleaned, atomically: true, encoding: .utf8)
        let manifestURL = Categorize.manifestURL(stem: stem, dataDirURL: root)
        try FileManager.default.createDirectory(at: manifestURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "{broken json".write(to: manifestURL, atomically: true, encoding: .utf8)

        let calls = LockedStringArray()
        let operations = Pipeline.Operations(
            transcribe: { _, _ in calls.append("transcribe"); return "unused" },
            cleanup: { _, _ in calls.append("cleanup"); return "unused" },
            categorize: { input, _, _ in
                try expect(input == "cleaned entry")
                calls.append("categorize")
                return .professional
            },
            filename: { _, _ in calls.append("filename"); return "2026-07-10-recovered-category.md" },
            enrich: { _, _, _, _ in calls.append("enrich"); return "recovered entry" }
        )

        let result = try await Pipeline.resumeCommand(
            stem: stem,
            dataDir: root.path,
            fromStage: .naming,
            operations: operations
        )

        try expect(calls.snapshot() == ["categorize", "filename", "enrich"])
        try expect(try Categorize.loadManifest(stem: stem, dataDirURL: root).category == .professional)
        try expect(result.category == .professional)
        try expect(Pipeline.detectNextStage(stem: stem, dataDir: root.path) == .done)
    }

    await testAsync("Resume CLI: failed categorization leaves a malformed manifest retryable") {
        let stem = "2026-07-10-1315"
        let root = try makeRoot(stem: stem)
        defer { try? FileManager.default.removeItem(at: root) }
        let cleaned = root.appendingPathComponent(".pipeline/02-logs/\(stem).md")
        try FileManager.default.createDirectory(at: cleaned.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "cleaned entry".write(to: cleaned, atomically: true, encoding: .utf8)
        let manifestURL = Categorize.manifestURL(stem: stem, dataDirURL: root)
        try FileManager.default.createDirectory(at: manifestURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let malformedManifest = "{incomplete category manifest"
        try malformedManifest.write(to: manifestURL, atomically: true, encoding: .utf8)
        let calls = LockedStringArray()
        let operations = Pipeline.Operations(
            transcribe: { _, _ in calls.append("transcribe"); return "unused" },
            cleanup: { _, _ in calls.append("cleanup"); return "unused" },
            categorize: { _, _, _ in
                calls.append("categorize")
                throw NSError(domain: "PipelineResumeTests", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Synthetic categorization failure",
                ])
            },
            filename: { _, _ in calls.append("filename"); return "unused.md" },
            enrich: { _, _, _, _ in calls.append("enrich"); return "unused" }
        )

        do {
            _ = try await Pipeline.resumeCommand(
                stem: stem,
                dataDir: root.path,
                fromStage: .naming,
                operations: operations
            )
            try expect(false, "Categorization failure should propagate")
        } catch let error as NSError {
            try expect(error.localizedDescription == "Synthetic categorization failure")
        }

        try expect(calls.snapshot() == ["categorize"])
        try expect(try String(contentsOf: manifestURL, encoding: .utf8) == malformedManifest)
        try expect(Pipeline.detectNextStage(stem: stem, dataDir: root.path) == .categorizing)
        try expect(!FileManager.default.fileExists(
            atPath: root.appendingPathComponent(".pipeline/04-rename/\(stem).slug.txt").path
        ))
    }

    await testAsync("Resume CLI: rejects unsafe filename values before writing in the rename stage") {
        let fm = FileManager.default
        let stem = "2026-07-10-1415"
        let root = try makeRoot(stem: stem)
        defer { try? fm.removeItem(at: root) }
        let cleaned = root.appendingPathComponent(".pipeline/02-logs/\(stem).md")
        try fm.createDirectory(at: cleaned.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "cleaned entry".write(to: cleaned, atomically: true, encoding: .utf8)
        try Categorize.writeManifest(.init(sourceStem: stem, category: .personal), dataDirURL: root)

        let outsideName = "escaped-\(UUID().uuidString).md"
        let outsidePath = root.deletingLastPathComponent().appendingPathComponent(outsideName)
        defer { try? fm.removeItem(at: outsidePath) }
        let invalidSlugs = ["../../../\(outsideName)", "..\\\(outsideName)", "", ".", ".."]
        let calls = LockedStringArray()
        for invalidSlug in invalidSlugs {
            let operations = Pipeline.Operations(
                transcribe: { _, _ in calls.append("transcribe"); return "unused" },
                cleanup: { _, _ in calls.append("cleanup"); return "unused" },
                categorize: { _, _, _ in calls.append("categorize"); return .professional },
                filename: { _, _ in calls.append("filename:\(invalidSlug)"); return invalidSlug },
                enrich: { _, _, _, _ in calls.append("enrich"); return "unused" }
            )

            do {
                _ = try await Pipeline.resumeCommand(
                    stem: stem,
                    dataDir: root.path,
                    fromStage: .naming,
                    operations: operations
                )
                try expect(false, "Unsafe generated filename should be rejected: \(invalidSlug)")
            } catch let error as Pipeline.PipelineError {
                guard case .invalidSlug(let value) = error else {
                    try expect(false, "Expected the invalidSlug error")
                    return
                }
                try expect(value == invalidSlug)
            }

            try expect(calls.snapshot().last == "filename:\(invalidSlug)")
            try expect(!fm.fileExists(atPath: root.appendingPathComponent(".pipeline/04-rename/\(stem).slug.txt").path))
            try expect(Pipeline.detectNextStage(stem: stem, dataDir: root.path) == .naming)
        }

        try expect(calls.snapshot().count == invalidSlugs.count, "Only filename generation should run for invalid values")
        try expect(!fm.fileExists(atPath: outsidePath.path), "The stage must not write outside the data folder")
    }

    test("Pipeline: unsafe stored slugs cannot expose or delete files outside the data folder") {
        let fm = FileManager.default
        let sandbox = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogStoredSlugBoundary-\(UUID().uuidString)", isDirectory: true)
        let root = sandbox.appendingPathComponent("data", isDirectory: true)
        let stem = "2026-07-10-1515"
        let unsafeSlug = "../../../outside-\(UUID().uuidString)"
        let victimName = "\(unsafeSlug).md"
        let renameVictim = root.appendingPathComponent(".pipeline/04-rename/\(victimName)").standardizedFileURL
        let enrichedVictim = root.appendingPathComponent("logs/\(victimName)").standardizedFileURL
        defer {
            try? fm.removeItem(at: sandbox)
            try? fm.removeItem(at: enrichedVictim)
        }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let marker = root.appendingPathComponent(".pipeline/04-rename/\(stem).slug.txt")
        try fm.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try unsafeSlug.write(to: marker, atomically: true, encoding: .utf8)

        let transcript = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        let cleaned = root.appendingPathComponent(".pipeline/02-logs/\(stem).md")
        try fm.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.createDirectory(at: cleaned.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "transcript".write(to: transcript, atomically: true, encoding: .utf8)
        try "cleaned".write(to: cleaned, atomically: true, encoding: .utf8)
        try Categorize.writeManifest(.init(sourceStem: stem, category: .personal), dataDirURL: root)

        for victim in [renameVictim, enrichedVictim] {
            try fm.createDirectory(at: victim.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "preserve synthetic outside file".write(to: victim, atomically: true, encoding: .utf8)
        }

        let entries = Pipeline.listEntries(dataDir: root.path).filter { $0.stem == stem }
        try expect(entries.count == 1)
        try expect(entries[0].slug == nil, "Invalid markers should be treated as incomplete naming state")
        try expect(entries[0].nextStage == .naming)
        try expect(entries[0].latestPath.hasPrefix(root.path + "/"))

        let protectedPaths = Set([renameVictim.path, enrichedVictim.path])
        for candidate in Pipeline.deletionCandidatePaths(stem: stem, slug: unsafeSlug, dataDir: root.path) {
            let standardized = URL(fileURLWithPath: candidate).standardizedFileURL.path
            try expect(!protectedPaths.contains(standardized))
        }
        let audio = root.appendingPathComponent("audio/\(stem).m4a")
        try fm.createDirectory(at: audio.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("synthetic source audio".utf8).write(to: audio)
        try Pipeline.resetForReprocessing(stem: stem, slug: nil, dataDir: root.path)

        try expect(!fm.fileExists(atPath: marker.path))
        try expect(try String(contentsOf: renameVictim, encoding: .utf8) == "preserve synthetic outside file")
        try expect(try String(contentsOf: enrichedVictim, encoding: .utf8) == "preserve synthetic outside file")
        try expect(try Data(contentsOf: audio) == Data("synthetic source audio".utf8))
    }
}

@MainActor
func runTests() async {
    let suiteName = lightweightUnitOnly ? "Lightweight CaptainsLog Unit Tests" : "Full CaptainsLog Tests"
    print("\nRunning \(suiteName)...\n")

    // MARK: - ConfigManager Tests

    test("ConfigManager: initial dataDir uses configured path or the documented default") {
        let priorConfig = CaptainsLogConfig.load()
        defer { try? priorConfig.save() }

        try priorConfig.withDataDir(nil).save()
        let defaultConfig = ConfigManager(loadContextFiles: false)
        let expectedDefault = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/CaptainsLog").path
        try expect(
            defaultConfig.dataDir == expectedDefault,
            "Missing configuration should use the documented Documents/CaptainsLog directory"
        )

        let expectedConfiguredPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLogConfiguredDataDir-\(UUID().uuidString)").path
        try priorConfig.withDataDir(expectedConfiguredPath).save()
        let configured = ConfigManager(loadContextFiles: false)
        try expect(
            configured.dataDir == expectedConfiguredPath,
            "ConfigManager should load the data folder saved in config.json"
        )
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

    test("ConfigManager: deferred context load reads files when requested") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "CaptainsLogDeferredContext-\(UUID().uuidString)", isDirectory: true
        )
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let priorConfigPath = getenv("CAPTAINS_LOG_CONFIG_PATH").map { String(cString: $0) }
        let isolatedConfigPath = root.appendingPathComponent("config.json").path
        setenv("CAPTAINS_LOG_CONFIG_PATH", isolatedConfigPath, 1)
        defer {
            if let priorConfigPath {
                setenv("CAPTAINS_LOG_CONFIG_PATH", priorConfigPath, 1)
            } else {
                unsetenv("CAPTAINS_LOG_CONFIG_PATH")
            }
        }

        let savedContext = "Synthetic project context."
        let savedCorrections = "Mira -> Myra"
        let persistedConfig = CaptainsLogConfig(dataDir: root.path)
        try persistedConfig.writePersonalInfo(savedContext)
        try persistedConfig.writeCorrections(savedCorrections)
        try persistedConfig.save()

        let manager = ConfigManager(loadContextFiles: false)
        try expect(manager.personalContext.isEmpty && manager.corrections.isEmpty)
        manager.loadContextFilesIfNeeded()
        try expect(manager.personalContext == savedContext)
        try expect(manager.corrections == savedCorrections)
    }

    await testAsync("Settings: data folder, model choices, context, and corrections persist") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogSettings-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let priorConfigPath = getenv("CAPTAINS_LOG_CONFIG_PATH").map { String(cString: $0) }
        let isolatedConfigPath = root.appendingPathComponent("config.json").path
        setenv("CAPTAINS_LOG_CONFIG_PATH", isolatedConfigPath, 1)
        defer {
            if let priorConfigPath {
                setenv("CAPTAINS_LOG_CONFIG_PATH", priorConfigPath, 1)
            } else {
                unsetenv("CAPTAINS_LOG_CONFIG_PATH")
            }
        }

        let manager = ConfigManager()
        manager.dataDir = root.path
        manager.whisperModel = "fixture-whisper-model"
        manager.whisperModelFolder = root.appendingPathComponent("whisper-model").path
        manager.qwenModelId = "fixture/qwen-model"
        manager.qwenModelFolder = root.appendingPathComponent("qwen-model.gguf").path
        let settingsFixtures = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("eval/settings/context")
        let personalContext = try String(contentsOf: settingsFixtures.appendingPathComponent("personal_info.md"), encoding: .utf8)
        let corrections = try String(contentsOf: settingsFixtures.appendingPathComponent("corrections.md"), encoding: .utf8)
        let transcript = try String(contentsOf: settingsFixtures.appendingPathComponent("transcript.md"), encoding: .utf8)
        manager.personalContext = personalContext
        manager.corrections = corrections

        try await Task.sleep(for: .milliseconds(450))
        let saved = CaptainsLogConfig.load()
        try expect(saved.dataDir == root.path)
        try expect(saved.whisperModel == "fixture-whisper-model")
        try expect(saved.whisperModelFolder == root.appendingPathComponent("whisper-model").path)
        try expect(saved.qwenModelId == "fixture/qwen-model")
        try expect(saved.qwenModelFolder == root.appendingPathComponent("qwen-model.gguf").path)
        try expect(saved.readPersonalInfo() == personalContext)
        try expect(saved.readCorrections() == corrections)

        let reloadedManager = ConfigManager()
        try expect(reloadedManager.dataDir == root.path, "Reloaded settings should restore the selected data folder")
        try expect(reloadedManager.whisperModel == "fixture-whisper-model", "Reloaded settings should restore the Whisper model choice")
        try expect(
            reloadedManager.whisperModelFolder == root.appendingPathComponent("whisper-model").path,
            "Reloaded settings should restore the local Whisper model folder"
        )
        try expect(reloadedManager.qwenModelId == "fixture/qwen-model", "Reloaded settings should restore the Qwen model choice")
        try expect(
            reloadedManager.qwenModelFolder == root.appendingPathComponent("qwen-model.gguf").path,
            "Reloaded settings should restore the local Qwen model file"
        )
        try expect(reloadedManager.personalContext == personalContext)
        try expect(reloadedManager.corrections == corrections)
        let rendered = try Cleanup.renderedPrompt(transcript: transcript)
        try expect(
            rendered.systemPrompt.contains("<speaker_context>")
                && rendered.systemPrompt.contains(personalContext.trimmingCharacters(in: .whitespacesAndNewlines)),
            "Saved personal context should appear in the cleanup system prompt"
        )
        try expect(rendered.systemPrompt.contains("<name_corrections>"), "Saved corrections should add a name-corrections section")
        try expect(rendered.systemPrompt.contains(corrections.trimmingCharacters(in: .whitespacesAndNewlines)), "Saved correction text should appear in the cleanup system prompt")
        try expect(
            rendered.userMessage.contains("<transcript>")
                && rendered.userMessage.contains(transcript.trimmingCharacters(in: .whitespacesAndNewlines)),
            "The raw transcript should appear in the cleanup user message"
        )

        let alternateDataDir = root.appendingPathComponent("alternate-data", isDirectory: true)
        try fm.createDirectory(at: alternateDataDir, withIntermediateDirectories: true)
        reloadedManager.dataDir = alternateDataDir.path
        try expect(reloadedManager.personalContext.isEmpty, "Switching folders should not carry over personal context")
        try expect(reloadedManager.corrections.isEmpty, "Switching folders should not carry over corrections")
        try expect(
            CaptainsLogConfig(dataDir: root.path).readPersonalInfo() == personalContext,
            "Switching folders must leave the prior context file intact"
        )
        try await Task.sleep(for: .milliseconds(450))
        let configAfterSwitch = CaptainsLogConfig.load()
        try expect(configAfterSwitch.dataDir == alternateDataDir.path, "Selected data folder should persist after switching")
        try expect(configAfterSwitch.readPersonalInfo() == "", "The alternate folder should retain its own empty context")
        try expect(configAfterSwitch.readCorrections() == "", "The alternate folder should retain its own empty corrections")
    }

    await testAsync("Settings: selecting a data folder loads its entries and context; cancel preserves the selection") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogDataFolderPicker-\(UUID().uuidString)", isDirectory: true)
        let currentDataDir = root.appendingPathComponent("current-data", isDirectory: true)
        let selectedDataDir = root.appendingPathComponent("selected-data", isDirectory: true)
        try fm.createDirectory(at: currentDataDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: selectedDataDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let priorConfigPath = getenv("CAPTAINS_LOG_CONFIG_PATH").map { String(cString: $0) }
        setenv("CAPTAINS_LOG_CONFIG_PATH", root.appendingPathComponent("config.json").path, 1)
        defer {
            if let priorConfigPath {
                setenv("CAPTAINS_LOG_CONFIG_PATH", priorConfigPath, 1)
            } else {
                unsetenv("CAPTAINS_LOG_CONFIG_PATH")
            }
        }
        let priorDemoMode = getenv("CAPTAINSLOG_DEMO_MODE").map { String(cString: $0) }
        setenv("CAPTAINSLOG_DEMO_MODE", "0", 1)
        defer {
            if let priorDemoMode {
                setenv("CAPTAINSLOG_DEMO_MODE", priorDemoMode, 1)
            } else {
                unsetenv("CAPTAINSLOG_DEMO_MODE")
            }
        }

        try CaptainsLogConfig(dataDir: currentDataDir.path).save()
        let selectedContext = "Synthetic selected-folder context."
        let selectedCorrections = "Nila -> Neela"
        let selectedConfig = CaptainsLogConfig(dataDir: selectedDataDir.path)
        try selectedConfig.writePersonalInfo(selectedContext)
        try selectedConfig.writeCorrections(selectedCorrections)
        let stem = "2025-01-14-0830"
        let transcript = selectedDataDir.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        let fixture = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("eval/transcribe/expected/durins-volk.md")
        try fm.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: fixture, to: transcript)

        let initialDirectories = LockedStringArray()
        let manager = ConfigManager(dataDirectoryPicker: { initialDirectory in
            initialDirectories.append(initialDirectory?.path ?? "nil")
            return selectedDataDir
        })
        let watcher = DirectoryWatcher()
        defer { watcher.stopWatching() }
        let appState = AppState(config: manager, directoryWatcher: watcher)
        appState.pickDataDirectory()

        try expect(initialDirectories.snapshot() == [currentDataDir.path], "The folder picker should open at the currently configured folder")
        try expect(appState.dataDir == selectedDataDir.path, "Selecting a folder should update the app data directory")
        try expect(appState.allEntries.map(\.stem) == [stem], "Selecting a folder should reload its pending Logs entries")
        try expect(manager.personalContext == selectedContext, "Selecting a folder should load its personal context")
        try expect(manager.corrections == selectedCorrections, "Selecting a folder should load its corrections")

        try await Task.sleep(for: .milliseconds(350))
        try expect(CaptainsLogConfig.load().dataDir == selectedDataDir.path, "The selected folder should persist to config.json")

        let cancelManager = ConfigManager(dataDirectoryPicker: { initialDirectory in
            initialDirectories.append(initialDirectory?.path ?? "nil")
            return nil
        })
        cancelManager.pickDataDirectory()
        try expect(cancelManager.dataDir == selectedDataDir.path, "Canceling the picker should preserve the current selection")
        try expect(
            initialDirectories.snapshot() == [currentDataDir.path, selectedDataDir.path],
            "A later picker should start at the newly selected folder"
        )

        setenv("CAPTAINSLOG_DEMO_MODE", "1", 1)
        let demoPickerCalls = LockedStringArray()
        let demoManager = ConfigManager(dataDirectoryPicker: { _ in
            demoPickerCalls.append("opened")
            return currentDataDir
        })
        demoManager.pickDataDirectory()
        try expect(demoPickerCalls.snapshot().isEmpty, "Demo mode should not open the data-folder picker")
        try expect(demoManager.dataDir == selectedDataDir.path, "Demo mode should preserve the configured data folder")

        setenv("CAPTAINSLOG_DEMO_MODE", "0", 1)
        let missingDataDir = root.appendingPathComponent("removed-data", isDirectory: true)
        try CaptainsLogConfig(dataDir: missingDataDir.path).save()
        let missingInitialDirectories = LockedStringArray()
        let missingFolderManager = ConfigManager(dataDirectoryPicker: { initialDirectory in
            missingInitialDirectories.append(initialDirectory?.path ?? "nil")
            return nil
        })
        missingFolderManager.pickDataDirectory()
        try expect(missingInitialDirectories.snapshot() == ["nil"], "A missing configured folder should not be sent as the picker start location")
        try expect(missingFolderManager.dataDir == missingDataDir.path, "Canceling with a missing configured folder should preserve the saved path")
    }

    test("Config: config path can be overridden for tests") {
        try expect(CaptainsLogConfig.configURL.lastPathComponent == "config.json")
        try expect(CaptainsLogConfig.configURL.path.contains("CaptainsLogTests-"))
    }

    test("Config: malformed JSON falls back to defaults without replacing the file") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "CaptainsLogMalformedConfig-\(UUID().uuidString)", isDirectory: true
        )
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let priorConfigPath = getenv("CAPTAINS_LOG_CONFIG_PATH").map { String(cString: $0) }
        let isolatedConfigPath = root.appendingPathComponent("config.json").path
        setenv("CAPTAINS_LOG_CONFIG_PATH", isolatedConfigPath, 1)
        defer {
            if let priorConfigPath {
                setenv("CAPTAINS_LOG_CONFIG_PATH", priorConfigPath, 1)
            } else {
                unsetenv("CAPTAINS_LOG_CONFIG_PATH")
            }
        }

        let malformed = Data("{not-json".utf8)
        try malformed.write(to: URL(fileURLWithPath: isolatedConfigPath))
        let loaded = CaptainsLogConfig.load()
        try expect(loaded.dataDir == nil, "Malformed config should fall back to the default data directory")
        try expect(loaded.whisperModel == nil && loaded.qwenModelId == nil, "Malformed config should not leak partially decoded values")
        try expect(
            try Data(contentsOf: URL(fileURLWithPath: isolatedConfigPath)) == malformed,
            "Loading malformed config should leave the user's file untouched"
        )
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

    test("FileSystem errors distinguish disk-full writes and report low-space details") {
        let path = "/tmp/synthetic-captainslog-output.md"
        let noSpace = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))
        let direct = CaptainsLogFileSystemError.writeFailed(path: path, underlying: noSpace)
        try expect(direct.localizedDescription.contains("disk is full"))

        let wrappedNoSpace = NSError(
            domain: "SyntheticWrapper",
            code: 1,
            userInfo: [NSUnderlyingErrorKey: noSpace]
        )
        let wrapped = CaptainsLogFileSystemError.writeFailed(path: path, underlying: wrappedNoSpace)
        try expect(wrapped.localizedDescription.contains("disk is full"))

        let textualNoSpace = NSError(
            domain: "SyntheticWrapper",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "No space left on device"]
        )
        let textual = CaptainsLogFileSystemError.writeFailed(path: path, underlying: textualNoSpace)
        try expect(textual.localizedDescription.contains("disk is full"))

        let lowSpace = CaptainsLogFileSystemError.insufficientDiskSpace(
            path: path,
            availableBytes: 10,
            requiredBytes: FileSystemGuard.minimumFreeBytesBeforeTranscription
        )
        try expect(lowSpace.localizedDescription.contains("Not enough free disk space"))
        try expect(lowSpace.localizedDescription.contains(path))
    }

    test("FileSystemGuard: transcription space check rejects low capacity and allows exact or unknown capacity") {
        let path = "/tmp/synthetic-captainslog-audio.m4a"
        let minimum = FileSystemGuard.minimumFreeBytesBeforeTranscription
        do {
            try FileSystemGuard.requireFreeSpaceForTranscription(paths: [path]) { _ in minimum - 1 }
            try expect(false, "Transcription must be rejected below the free-space threshold")
        } catch let error as CaptainsLogFileSystemError {
            guard case .insufficientDiskSpace(let failedPath, let available, let required) = error else {
                try expect(false, "Expected insufficientDiskSpace for a low-capacity volume")
                return
            }
            try expect(failedPath == path)
            try expect(available == minimum - 1)
            try expect(required == minimum)
        }

        try FileSystemGuard.requireFreeSpaceForTranscription(paths: [path]) { _ in minimum }
        try FileSystemGuard.requireFreeSpaceForTranscription(paths: [path]) { _ in nil }
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

    test("LLM: configured model lookup prefers the expected file then falls back deterministically") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "CaptainsLogGGUFSelection-\(UUID().uuidString)", isDirectory: true
        )
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let alpha = root.appendingPathComponent("a-model.gguf")
        let zeta = root.appendingPathComponent("z-model.gguf")
        let unrelated = root.appendingPathComponent("readme.txt")
        try Data("fixture model marker".utf8).write(to: alpha)
        try Data("fixture model marker".utf8).write(to: zeta)
        try Data("not a model".utf8).write(to: unrelated)

        try expect(LLM.configuredModelFile(in: root.path) == alpha.path)
        let preferred = root.appendingPathComponent(LLM.ggufFilename)
        try Data("preferred fixture marker".utf8).write(to: preferred)
        try expect(LLM.configuredModelFile(in: root.path) == preferred.path)
        try expect(LLM.configuredModelFile(in: "") == nil)
        try expect(LLM.configuredModelFile(in: root.appendingPathComponent("missing").path) == nil)
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
        let validOutputs: [(String, Categorize.Category)] = [
            ("<category>personal</category>", .personal),
            ("<category>professional</category>", .professional),
            ("<category>side_project</category>", .sideProject),
            ("<CATEGORY>  PERSONAL  </CATEGORY>", .personal),
            ("prefix\n<category> PROFESSIONAL </category>\nsuffix", .professional),
        ]
        for (raw, expected) in validOutputs {
            try expect(try Categorize.parseCategory(raw) == expected, "Failed to parse \(raw)")
        }
    }

    test("Categorize: rejects malformed and unsupported XML categories") {
        let invalidOutputs = [
            "personal",
            "<category></category>",
            "<category>side-project</category>",
            "<category><value>personal</value></category>",
        ]
        for raw in invalidOutputs {
            do {
                _ = try Categorize.parseCategory(raw)
                try expect(false, "Expected invalid category output to throw: \(raw)")
            } catch let error as Categorize.CategorizeError {
                try expect(error == .invalidXML(outputByteCount: raw.utf8.count))
            }
        }
    }

    test("Recorder audio level: RMS handles silence, mixed samples, and empty buffers") {
        let mixed = [1 as Float, 1, 0, 0]
        let rms = mixed.withUnsafeBufferPointer { AudioLevel.rootMeanSquare(of: $0) }
        try expect(rms != nil && abs(rms! - sqrt(0.5)) < 0.0001)
        let silence = [0 as Float, 0]
        try expect(silence.withUnsafeBufferPointer { AudioLevel.rootMeanSquare(of: $0) } == 0)
        let empty: [Float] = []
        try expect(empty.withUnsafeBufferPointer { AudioLevel.rootMeanSquare(of: $0) } == nil)
    }

    // MARK: - RecordingState Tests

    await testAsync("Recorder: selected device, tap writes, pause gating, and session release use injected audio operations") {
        let device = AudioDevice(id: 42, name: "Test microphone", uid: "test-mic")
        let events = LockedStringArray()
        let selectedUID = LockedValue<String?>(nil)
        let paused = LockedValue(false)
        let levels = LockedValue<[Float]>([])
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let (stopTrigger, stopContinuation) = AsyncStream<Void>.makeStream()
        let engine = TestRecorderAudioEngine(events: events) {
            startedContinuation.yield(())
            startedContinuation.finish()
        }
        let writer = TestRecorderAudioWriter(events: events)
        let operations = RecorderOperations(
            listInputDevices: { [device] },
            makeEngine: { selected in
                selectedUID.set(selected?.uid)
                return engine
            },
            makeWriter: { url, format in
                events.append("writer:\(url.lastPathComponent):\(format.sampleRate):\(format.channelCount)")
                return writer
            },
            waitForManualStop: { _ in events.append("manualWait") }
        )
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLogRecorderOperations-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let output = root.appendingPathComponent("audio/test-recording.m4a")

        let task = Task {
            try await Recorder.record(
                to: output,
                duration: nil,
                deviceUID: "test-mic",
                stopTrigger: stopTrigger,
                levelCallback: { level in levels.set(levels.get() + [level]) },
                isPaused: { paused.get() },
                operations: operations
            )
        }
        for await _ in started { break }

        engine.emit([1, 1, 0, 0])
        paused.set(true)
        engine.emit([1, 1, 1, 1])
        paused.set(false)
        stopContinuation.yield(())
        stopContinuation.finish()
        try await task.value

        try expect(selectedUID.get() == "test-mic", "The selected input must reach the engine adapter")
        try expect(levels.get().count == 1, "Paused buffers must not update the level meter")
        try expect(abs(levels.get()[0] - sqrt(0.5)) < 0.0001, "Audio level should be the input RMS")
        try expect(events.snapshot().contains("write:4"), "Unpaused input should be written")
        try expect(events.snapshot().filter { $0 == "write:4" }.count == 1, "Paused input must not be written")
        try expect(events.snapshot().contains("writer:test-recording.m4a:48000.0:1"), "Writer must receive the target and input format")
        try expect(events.snapshot().suffix(2).elementsEqual(["stop", "removeTap"]), "Stop must release the engine before removing its tap")
        try expect(FileManager.default.fileExists(atPath: output.deletingLastPathComponent().path))
    }

    await testAsync("Recorder: unavailable selected input falls back to default device") {
        let events = LockedStringArray()
        let selectedUID = LockedValue<String?>("not-called")
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let (stopTrigger, stopContinuation) = AsyncStream<Void>.makeStream()
        let engine = TestRecorderAudioEngine(events: events) {
            startedContinuation.yield(())
            startedContinuation.finish()
        }
        let operations = RecorderOperations(
            listInputDevices: { [] },
            makeEngine: { selected in
                selectedUID.set(selected?.uid)
                return engine
            },
            makeWriter: { _, _ in TestRecorderAudioWriter(events: events) },
            waitForManualStop: { _ in events.append("manualWait") }
        )
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLogUnavailableMic-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: output.deletingLastPathComponent()) }

        let task = Task {
            try await Recorder.record(
                to: output,
                duration: nil,
                deviceUID: "missing-mic",
                stopTrigger: stopTrigger,
                levelCallback: nil,
                isPaused: { false },
                operations: operations
            )
        }
        for await _ in started { break }
        stopContinuation.yield(())
        stopContinuation.finish()
        try await task.value

        try expect(selectedUID.get() == nil, "Unknown device UID should leave device selection to the system default")
    }

    await testAsync("Recorder: engine start failure stops engine and removes tap") {
        let events = LockedStringArray()
        let underlying = NSError(domain: "TestRecorder", code: 11)
        let engine = TestRecorderAudioEngine(events: events, startError: underlying)
        let operations = RecorderOperations(
            listInputDevices: { [] },
            makeEngine: { _ in engine },
            makeWriter: { _, _ in TestRecorderAudioWriter(events: events) },
            waitForManualStop: { _ in events.append("manualWait") }
        )
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLogEngineStartFailure-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: output.deletingLastPathComponent()) }

        do {
            try await Recorder.record(
                to: output,
                duration: nil,
                deviceUID: nil,
                stopTrigger: nil,
                levelCallback: nil,
                isPaused: { false },
                operations: operations
            )
            try expect(false, "Expected engine start to fail")
        } catch let error as Recorder.RecorderError {
            guard case .engineStartFailed(let cause) = error else {
                try expect(false, "Expected engineStartFailed, got \(error)")
                return
            }
            try expect((cause as NSError).code == underlying.code)
        }
        try expect(events.snapshot().suffix(2).elementsEqual(["stop", "removeTap"]))
    }

    await testAsync("Recorder: tap installation failure releases engine without starting it") {
        let events = LockedStringArray()
        let underlying = NSError(domain: "TestRecorder", code: 12)
        let engine = TestRecorderAudioEngine(events: events, installError: underlying)
        let operations = RecorderOperations(
            listInputDevices: { [] },
            makeEngine: { _ in engine },
            makeWriter: { _, _ in TestRecorderAudioWriter(events: events) },
            waitForManualStop: { _ in events.append("manualWait") }
        )
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLogTapInstallFailure-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: output.deletingLastPathComponent()) }

        do {
            try await Recorder.record(
                to: output,
                duration: nil,
                deviceUID: nil,
                stopTrigger: nil,
                levelCallback: nil,
                isPaused: { false },
                operations: operations
            )
            try expect(false, "Expected tap installation to fail")
        } catch {
            try expect((error as NSError).code == underlying.code)
        }
        try expect(events.snapshot().suffix(2).elementsEqual(["stop", "removeTap"]))
        try expect(!events.snapshot().contains("start"))
    }

    await testAsync("Recorder: file write failures surface after the audio tap and engine are released") {
        let events = LockedStringArray()
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let (stopTrigger, stopContinuation) = AsyncStream<Void>.makeStream()
        let underlying = NSError(domain: "TestRecorder", code: 13)
        let engine = TestRecorderAudioEngine(events: events) {
            startedContinuation.yield(())
            startedContinuation.finish()
        }
        let writer = TestRecorderAudioWriter(events: events, writeError: underlying)
        let operations = RecorderOperations(
            listInputDevices: { [] },
            makeEngine: { _ in engine },
            makeWriter: { _, _ in writer },
            waitForManualStop: { _ in events.append("manualWait") }
        )
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLogWriteFailure-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: output.deletingLastPathComponent()) }
        let task = Task {
            try await Recorder.record(
                to: output,
                duration: nil,
                deviceUID: nil,
                stopTrigger: stopTrigger,
                levelCallback: nil,
                isPaused: { false },
                operations: operations
            )
        }
        for await _ in started { break }
        engine.emit([0.25, -0.25])
        stopContinuation.yield(())
        stopContinuation.finish()

        do {
            try await task.value
            try expect(false, "Expected the tap writer error to surface")
        } catch {
            try expect((error as NSError).code == underlying.code)
        }
        try expect(events.snapshot().suffix(2).elementsEqual(["stop", "removeTap"]))
    }

    await testAsync("Recorder: manual stop path forwards the duration and releases the engine") {
        let events = LockedStringArray()
        let duration = LockedValue<TimeInterval?>(nil)
        let deviceDiscoveryCalls = LockedValue(0)
        let engine = TestRecorderAudioEngine(events: events)
        let operations = RecorderOperations(
            listInputDevices: { deviceDiscoveryCalls.set(deviceDiscoveryCalls.get() + 1); return [] },
            makeEngine: { selected in
                try expect(selected == nil, "No requested device should use the system default")
                return engine
            },
            makeWriter: { _, _ in TestRecorderAudioWriter(events: events) },
            waitForManualStop: { requestedDuration in
                duration.set(requestedDuration)
                events.append("manualWait")
            }
        )
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLogManualRecorderStop-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try await Recorder.record(
            to: root.appendingPathComponent("manual.m4a"),
            duration: 3,
            deviceUID: nil,
            stopTrigger: nil,
            levelCallback: nil,
            isPaused: { false },
            operations: operations
        )

        try expect(duration.get() == 3, "Manual stop adapter should receive the requested recording duration")
        try expect(deviceDiscoveryCalls.get() == 0, "Device discovery is unnecessary when no UID is selected")
        try expect(events.snapshot().contains("manualWait"))
        try expect(events.snapshot().suffix(2).elementsEqual(["stop", "removeTap"]))
    }

    await testAsync("Recorder: output setup failures stop before tap or engine startup") {
        let events = LockedStringArray()
        let engineFailure = NSError(domain: "TestRecorderSetup", code: 21)
        let outputRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLogRecorderSetup-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: outputRoot) }
        let device = AudioDevice(id: 7, name: "Test microphone", uid: "setup-mic")

        let engineFailureOperations = RecorderOperations(
            listInputDevices: { [device] },
            makeEngine: { selected in
                try expect(selected?.uid == "setup-mic")
                events.append("makeEngine")
                throw engineFailure
            },
            makeWriter: { _, _ in events.append("makeWriter"); return TestRecorderAudioWriter(events: events) },
            waitForManualStop: { _ in events.append("manualWait") }
        )
        do {
            try await Recorder.record(
                to: outputRoot.appendingPathComponent("engine-failure.m4a"),
                duration: nil,
                deviceUID: "setup-mic",
                stopTrigger: nil,
                levelCallback: nil,
                isPaused: { false },
                operations: engineFailureOperations
            )
            try expect(false, "Expected engine creation to fail")
        } catch {
            try expect((error as NSError).code == engineFailure.code)
        }
        try expect(events.snapshot() == ["makeEngine"], "Writer and wait operations must not run after engine creation fails")

        events.append("reset")
        let writerFailure = NSError(domain: "TestRecorderSetup", code: 22)
        let unusedEngine = TestRecorderAudioEngine(events: events)
        let writerFailureOperations = RecorderOperations(
            listInputDevices: { [] },
            makeEngine: { _ in events.append("makeEngine"); return unusedEngine },
            makeWriter: { _, _ in events.append("makeWriter"); throw writerFailure },
            waitForManualStop: { _ in events.append("manualWait") }
        )
        do {
            try await Recorder.record(
                to: outputRoot.appendingPathComponent("writer-failure.m4a"),
                duration: nil,
                deviceUID: nil,
                stopTrigger: nil,
                levelCallback: nil,
                isPaused: { false },
                operations: writerFailureOperations
            )
            try expect(false, "Expected writer creation to fail")
        } catch {
            try expect((error as NSError).code == writerFailure.code)
        }
        try expect(events.snapshot().suffix(2).elementsEqual(["makeEngine", "makeWriter"]))
        try expect(!events.snapshot().contains("start"), "Engine should not start without a writer")
    }

    await testAsync("Recorder: an already-finished stop trigger completes and releases the engine") {
        let events = LockedStringArray()
        let (stopTrigger, stopContinuation) = AsyncStream<Void>.makeStream()
        stopContinuation.finish()
        let engine = TestRecorderAudioEngine(events: events)
        let operations = RecorderOperations(
            listInputDevices: { [] },
            makeEngine: { _ in engine },
            makeWriter: { _, _ in TestRecorderAudioWriter(events: events) },
            waitForManualStop: { _ in events.append("manualWait") }
        )
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLogFinishedStopTrigger-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try await Recorder.record(
            to: root.appendingPathComponent("finished-trigger.m4a"),
            duration: nil,
            deviceUID: nil,
            stopTrigger: stopTrigger,
            levelCallback: nil,
            isPaused: { false },
            operations: operations
        )
        try expect(events.snapshot().contains("start"))
        try expect(events.snapshot().suffix(2).elementsEqual(["stop", "removeTap"]))
        try expect(!events.snapshot().contains("manualWait"))
    }

    await testAsync("Recorder: output directory failure occurs before device or engine operations") {
        let events = LockedStringArray()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLogRecorderDirectoryFailure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let blocker = root.appendingPathComponent("not-a-directory")
        try Data("fixture".utf8).write(to: blocker)
        let operations = RecorderOperations(
            listInputDevices: { events.append("listDevices"); return [] },
            makeEngine: { _ in events.append("makeEngine"); return TestRecorderAudioEngine(events: events) },
            makeWriter: { _, _ in events.append("makeWriter"); return TestRecorderAudioWriter(events: events) },
            waitForManualStop: { _ in events.append("manualWait") }
        )

        do {
            try await Recorder.record(
                to: blocker.appendingPathComponent("audio.m4a"),
                duration: nil,
                deviceUID: "requested-mic",
                stopTrigger: nil,
                levelCallback: nil,
                isPaused: { false },
                operations: operations
            )
            try expect(false, "Expected recording directory creation to fail")
        } catch {
            try expect((error as NSError).code != 0)
        }
        try expect(events.snapshot().isEmpty, "Hardware operations must not begin when the output directory is unavailable")
    }

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

    await testAsync("RecordingState: device refresh preserves a connected selection") {
        let preferred = AudioDevice(id: 42, name: "Preferred microphone", uid: "preferred-mic")
        let systemDefault = AudioDevice(id: 43, name: "Default microphone", uid: "default-mic")
        let recording = RecordingState(dependencies: .init(
            listInputDevices: { [preferred, systemDefault] },
            defaultInputDevice: { systemDefault },
            record: { _, _, _, _, _ in }
        ))
        recording.selectedDeviceUID = preferred.uid

        await recording.refreshDevicesInBackground()

        try expect(recording.inputDevices == [preferred, systemDefault])
        try expect(
            recording.selectedDeviceUID == preferred.uid,
            "Refreshing the device list should not replace the user's connected selection"
        )
    }

    await testAsync("RecordingState: device refresh falls back when the selected input disappears") {
        let available = AudioDevice(id: 43, name: "Default microphone", uid: "default-mic")
        let recording = RecordingState(dependencies: .init(
            listInputDevices: { [available] },
            defaultInputDevice: { available },
            record: { _, _, _, _, _ in }
        ))
        recording.selectedDeviceUID = "disconnected-microphone"

        await recording.refreshDevicesInBackground()

        try expect(recording.inputDevices == [available])
        try expect(
            recording.selectedDeviceUID == available.uid,
            "A disconnected selection should fall back to the current default input"
        )
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
        let recorderInputs = LockedStringArray()
        let recording = RecordingState(dependencies: .init(
            listInputDevices: { [] },
            defaultInputDevice: { nil },
            record: { url, deviceUID, stopTrigger, levelCallback, isPaused in
                recorderInputs.append(url.path)
                recorderInputs.append(deviceUID ?? "<none>")
                levelCallback?(0.75)
                for await _ in stopTrigger { break }
                try expect(isPaused() == false)
            }
        ))

        let dataDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLogSelectedRecordingDevice-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dataDir) }
        recording.selectedDeviceUID = "preferred-mic"
        recording.startRecording(
            dataDir: dataDir.path,
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
        let inputs = recorderInputs.snapshot()
        try expect(inputs.count == 2)
        let audioURL = URL(fileURLWithPath: inputs[0])
        try expect(audioURL.deletingLastPathComponent().path ==
            dataDir.appendingPathComponent(Pipeline.Directory.audio.path).path)
        try expect(inputs[1] == "preferred-mic", "Recording must use the user's selected input device")
        try expect(FileManager.default.fileExists(atPath: audioURL.deletingLastPathComponent().path))
    }

    await testAsync("RecordingState: immediate stop and duplicate start use one recording operation") {
        let (events, continuation) = AsyncStream<String>.makeStream()
        let operationCalls = LockedStringArray()
        let recording = RecordingState(dependencies: .init(
            listInputDevices: { [] },
            defaultInputDevice: { nil },
            record: { _, _, stopTrigger, _, _ in
                operationCalls.append("record")
                for await _ in stopTrigger { break }
            }
        ))
        let dataDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLogImmediateRecordingStop-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dataDir) }

        recording.startRecording(
            dataDir: dataDir.path,
            onComplete: { _ in continuation.yield("complete"); continuation.finish() },
            onError: { _ in continuation.yield("error"); continuation.finish() }
        )
        recording.startRecording(
            dataDir: dataDir.path,
            onComplete: { _ in continuation.yield("duplicate-complete"); continuation.finish() },
            onError: { _ in continuation.yield("duplicate-error"); continuation.finish() }
        )
        recording.stopRecording()

        var outcome: String?
        for await event in events { outcome = event }
        try expect(operationCalls.snapshot() == ["record"], "A second start must not create another engine operation")
        try expect(outcome == "complete", "Immediate stop should complete the one active recording cleanly")
        try expect(recording.isRecording == false)
        try expect(recording.recordingDuration == 0, "Immediate stop must stop the duration timer")
        try expect(recording.errorMessage == nil)
    }

    await testAsync("RecordingState: cancelling a fake recording suppresses completion and errors") {
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let callbacks = LockedStringArray()
        let recording = RecordingState(dependencies: .init(
            listInputDevices: { [] },
            defaultInputDevice: { nil },
            record: { _, _, stopTrigger, levelCallback, _ in
                levelCallback?(0.75)
                startedContinuation.yield(())
                for await _ in stopTrigger { break }
            }
        ))

        recording.startRecording(
            dataDir: FileManager.default.temporaryDirectory.path,
            onComplete: { _ in callbacks.append("complete") },
            onError: { _ in callbacks.append("error") }
        )
        for await _ in started { break }
        recording.cancelRecording()
        try await Task.sleep(for: .milliseconds(150))

        try expect(recording.isRecording == false)
        try expect(recording.audioLevel == 0)
        try expect(recording.recordingDuration == 0, "Cancellation must stop the duration timer")
        try expect(recording.errorMessage == nil)
        try expect(callbacks.snapshot().isEmpty, "Cancellation must not report success or failure")
    }

    await testAsync("RecordingState: cancellation errors are not surfaced as recording failures") {
        let (started, startedContinuation) = AsyncStream<Void>.makeStream()
        let callbacks = LockedStringArray()
        let recording = RecordingState(dependencies: .init(
            listInputDevices: { [] },
            defaultInputDevice: { nil },
            record: { _, _, stopTrigger, _, _ in
                startedContinuation.yield(())
                for await _ in stopTrigger { break }
                throw CancellationError()
            }
        ))

        recording.startRecording(
            dataDir: FileManager.default.temporaryDirectory.path,
            onComplete: { _ in callbacks.append("complete") },
            onError: { _ in callbacks.append("error") }
        )
        for await _ in started { break }
        recording.cancelRecording()
        try await Task.sleep(for: .milliseconds(150))

        try expect(recording.isRecording == false)
        try expect(recording.audioLevel == 0)
        try expect(recording.recordingDuration == 0, "Cancellation must stop the duration timer")
        try expect(recording.errorMessage == nil)
        try expect(callbacks.snapshot().isEmpty, "Cancellation must not call completion handlers")
    }

    await testAsync("RecordingState: fake recorder surfaces failures") {
        let (events, continuation) = AsyncStream<String>.makeStream()
        let recording = RecordingState(dependencies: .init(
            listInputDevices: { [] },
            defaultInputDevice: { nil },
            record: { _, _, _, levelCallback, _ in
                levelCallback?(0.75)
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
        try expect(recording.audioLevel == 0, "A failed recording must stop the audio meter")
        try await Task.sleep(for: .milliseconds(150))
        try expect(recording.recordingDuration == 0, "A failed recording must stop its duration timer")
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

    await testAsync("AppState: recording failure updates the visible processing error") {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CaptainsLogAppStateRecordFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let config = ConfigManager(loadContextFiles: false)
        config.dataDir = root.path
        let recording = RecordingState(dependencies: .init(
            listInputDevices: { [] },
            defaultInputDevice: { nil },
            record: { _, _, _, _, _ in
                throw NSError(domain: "AppStateRecordingTests", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Synthetic microphone failure",
                ])
            }
        ))
        let appState = AppState(config: config, recording: recording)

        appState.startRecording()
        for _ in 0..<100 where appState.processing.stage != .error {
            try await Task.sleep(for: .milliseconds(10))
        }

        try expect(appState.processing.stage == .error)
        try expect(appState.errorMessage == "Synthetic microphone failure")
        try expect(appState.statusMessage == "Error: Synthetic microphone failure")
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

    await testAsync("DirectoryWatcher: starts monitoring directories inside an isolated data folder") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogDirectoryWatcher-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let watcher = DirectoryWatcher(onReload: { })
        defer {
            watcher.stopWatching()
            try? fm.removeItem(at: root)
        }
        let monitoredPaths = [
            "audio",
            ".pipeline/01-transcribed",
            ".pipeline/02-logs",
            ".pipeline/03-category",
            ".pipeline/04-rename",
            "logs",
            "logs/personal",
            "logs/professional",
            "logs/side-project",
        ]

        watcher.startWatching(dataDir: root.path)
        let deadline = ContinuousClock.now + .seconds(2)
        while !monitoredPaths.allSatisfy({ fm.fileExists(atPath: root.appendingPathComponent($0).path) })
            && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try expect(
            monitoredPaths.allSatisfy({ fm.fileExists(atPath: root.appendingPathComponent($0).path) }),
            "Watcher setup should create each monitored directory under the configured data folder"
        )
    }

    await testAsync("DirectoryWatcher: stopping cancels a pending reload") {
        let reloads = LockedStringArray()
        let watcher = DirectoryWatcher(onReload: { reloads.append("reload") })
        watcher.scheduleReload()
        watcher.stopWatching()

        try await Task.sleep(for: .milliseconds(350))
        try expect(reloads.snapshot().isEmpty, "Stopping should suppress an already scheduled reload")
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

    test("ModelManager: model availability requires directories and Qwen requires a GGUF file") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogModelAvailability-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        let whisperFolder = root.appendingPathComponent("whisper", isDirectory: true)
        let qwenFolder = root.appendingPathComponent("qwen", isDirectory: true)
        let regularFile = root.appendingPathComponent("not-a-folder")
        let missingFolder = root.appendingPathComponent("missing", isDirectory: true)

        try expect(!ModelManager.whisperModelIsDownloaded(config: CaptainsLogConfig()))
        try expect(!ModelManager.qwenModelIsDownloaded(config: CaptainsLogConfig()))
        try expect(!ModelManager.whisperModelIsDownloaded(
            config: CaptainsLogConfig(whisperModelFolder: missingFolder.path)
        ))
        try expect(!ModelManager.qwenModelIsDownloaded(
            config: CaptainsLogConfig(qwenModelFolder: missingFolder.path)
        ))

        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try "not a directory".write(to: regularFile, atomically: true, encoding: .utf8)
        try expect(!ModelManager.whisperModelIsDownloaded(
            config: CaptainsLogConfig(whisperModelFolder: regularFile.path)
        ), "A regular file must not satisfy the Whisper model-folder check")
        try expect(!ModelManager.qwenModelIsDownloaded(
            config: CaptainsLogConfig(qwenModelFolder: regularFile.path)
        ), "A regular file must not satisfy the Qwen model-folder check")

        try fm.createDirectory(at: whisperFolder, withIntermediateDirectories: true)
        try fm.createDirectory(at: qwenFolder, withIntermediateDirectories: true)
        let unrelatedFile = qwenFolder.appendingPathComponent("README.txt")
        try "not a model".write(to: unrelatedFile, atomically: true, encoding: .utf8)
        try expect(ModelManager.whisperModelIsDownloaded(
            config: CaptainsLogConfig(whisperModelFolder: whisperFolder.path)
        ))
        try expect(!ModelManager.qwenModelIsDownloaded(
            config: CaptainsLogConfig(qwenModelFolder: qwenFolder.path)
        ), "Qwen should remain unavailable until a GGUF model file exists")

        try Data("synthetic GGUF marker".utf8).write(to: qwenFolder.appendingPathComponent("model.gguf"))
        try expect(ModelManager.qwenModelIsDownloaded(
            config: CaptainsLogConfig(qwenModelFolder: qwenFolder.path)
        ))
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

    await testAsync("ModelManager: skips downloads when both models are already available") {
        let calls = LockedStringArray()
        let manager = ModelManager(dependencies: .init(
            clearStaleConfig: { calls.append("clear-stale") },
            cleanCorruptedMetadata: { calls.append("clean-metadata") },
            whisperIsDownloaded: { calls.append("whisper-ready"); return true },
            qwenIsDownloaded: { calls.append("qwen-ready"); return true },
            downloadWhisper: { _ in calls.append("download-whisper") },
            downloadQwen: { _ in calls.append("download-qwen") }
        ))

        await manager.downloadModelsIfNeeded()

        try expect(manager.modelState == .ready)
        try expect(calls.snapshot() == ["clear-stale", "clean-metadata", "whisper-ready", "qwen-ready"])
    }

    await testAsync("ModelManager: downloads only Qwen when Whisper is already available") {
        let calls = LockedStringArray()
        let manager = ModelManager(dependencies: .init(
            clearStaleConfig: {},
            cleanCorruptedMetadata: {},
            whisperIsDownloaded: { true },
            qwenIsDownloaded: { false },
            downloadWhisper: { _ in calls.append("download-whisper") },
            downloadQwen: { _ in calls.append("download-qwen") }
        ))

        await manager.downloadModelsIfNeeded()

        try expect(manager.modelState == .ready)
        try expect(calls.snapshot() == ["download-qwen"], "The available Whisper model must not download again")
    }

    await testAsync("ModelManager: publishes each model download's progress") {
        let calls = LockedStringArray()
        let whisperGate = AsyncTestGate()
        let qwenGate = AsyncTestGate()
        let manager = ModelManager(dependencies: .init(
            clearStaleConfig: {},
            cleanCorruptedMetadata: {},
            whisperIsDownloaded: { false },
            qwenIsDownloaded: { false },
            downloadWhisper: { reportProgress in
                calls.append("download-whisper")
                let progress = Progress(totalUnitCount: 4)
                progress.completedUnitCount = 2
                reportProgress(progress)
                await whisperGate.wait()
            },
            downloadQwen: { reportProgress in
                calls.append("download-qwen")
                let progress = Progress(totalUnitCount: 4)
                progress.completedUnitCount = 3
                reportProgress(progress)
                await qwenGate.wait()
            }
        ))

        let download = Task { await manager.downloadModelsIfNeeded() }
        let whisperProgress = ModelState.downloading(
            model: "Whisper (speech-to-text)", progress: 0.5)
        for _ in 0..<100 where manager.modelState != whisperProgress {
            try await Task.sleep(for: .milliseconds(10))
        }
        try expect(manager.modelState == whisperProgress)
        try expect(calls.snapshot() == ["download-whisper"])

        await whisperGate.open()
        let qwenProgress = ModelState.downloading(
            model: "Qwen 3.5 (text processing)", progress: 0.75)
        for _ in 0..<100 where manager.modelState != qwenProgress {
            try await Task.sleep(for: .milliseconds(10))
        }
        try expect(manager.modelState == qwenProgress)
        try expect(calls.snapshot() == ["download-whisper", "download-qwen"])

        await qwenGate.open()
        await download.value
        try expect(manager.modelState == .ready)
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

    await testAsync("ModelManager: treats URL-session cancellation as ready") {
        let manager = ModelManager(dependencies: .init(
            clearStaleConfig: {},
            cleanCorruptedMetadata: {},
            whisperIsDownloaded: { false },
            qwenIsDownloaded: { true },
            downloadWhisper: { _ in throw URLError(.cancelled) },
            downloadQwen: { _ in }
        ))

        await manager.downloadModelsIfNeeded()
        try expect(manager.modelState == .ready)
    }

    await testAsync("ModelManager: ensureModelsDownloaded calls readiness after both downloads") {
        let ready = LockedStringArray()
        let manager = ModelManager(dependencies: .init(
            clearStaleConfig: {},
            cleanCorruptedMetadata: {},
            whisperIsDownloaded: { true },
            qwenIsDownloaded: { true },
            downloadWhisper: { _ in },
            downloadQwen: { _ in }
        ))

        manager.ensureModelsDownloaded { ready.append("ready") }
        for _ in 0..<100 where ready.snapshot().isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        try expect(ready.snapshot() == ["ready"])
        try expect(manager.modelState == .ready)
    }

    await testAsync("ModelManager: ensureModelsDownloaded does not call readiness after a download failure") {
        let ready = LockedStringArray()
        let manager = ModelManager(dependencies: .init(
            clearStaleConfig: {},
            cleanCorruptedMetadata: {},
            whisperIsDownloaded: { true },
            qwenIsDownloaded: { false },
            downloadWhisper: { _ in },
            downloadQwen: { _ in
                throw NSError(domain: "ModelTests", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Synthetic Qwen failure",
                ])
            }
        ))

        manager.ensureModelsDownloaded { ready.append("ready") }
        for _ in 0..<100 {
            if case .error = manager.modelState { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        try expect(manager.modelState == .error("Synthetic Qwen failure"))
        try expect(ready.snapshot().isEmpty, "Readiness must not be reported after a failed download")
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

    await testAsync("ModelManager: metadata download failure clears stale Whisper config") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogModelMetadataFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let priorConfigPath = getenv("CAPTAINS_LOG_CONFIG_PATH").map { String(cString: $0) }
        let isolatedConfigPath = root.appendingPathComponent("config.json").path
        setenv("CAPTAINS_LOG_CONFIG_PATH", isolatedConfigPath, 1)
        defer {
            if let priorConfigPath {
                setenv("CAPTAINS_LOG_CONFIG_PATH", priorConfigPath, 1)
            } else {
                unsetenv("CAPTAINS_LOG_CONFIG_PATH")
            }
        }

        try CaptainsLogConfig(
            dataDir: root.path,
            whisperModelFolder: "/stale/whisper-model",
            whisperModel: "synthetic-whisper",
            qwenModelId: "synthetic-qwen"
        ).save()

        let manager = ModelManager(dependencies: .init(
            clearStaleConfig: {},
            cleanCorruptedMetadata: {},
            whisperIsDownloaded: { false },
            qwenIsDownloaded: { true },
            downloadWhisper: { _ in
                throw NSError(domain: "ModelTests", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Corrupted Whisper metadata detected",
                ])
            },
            downloadQwen: { _ in }
        ))

        await manager.downloadModelsIfNeeded()

        let saved = CaptainsLogConfig.load()
        try expect(manager.modelState == .error("Corrupted Whisper metadata detected"))
        try expect(saved.whisperModel == nil, "A metadata failure should clear the stale Whisper model selection")
        try expect(saved.whisperModelFolder == nil, "A metadata failure should clear the stale Whisper model folder")
        try expect(saved.qwenModelId == "synthetic-qwen", "Whisper recovery must preserve unrelated model settings")
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

    test("AppState: exposes model settings, recording state, processing identity, and version") {
        let config = ConfigManager(loadContextFiles: false)
        let appState = AppState(config: config)

        appState.whisperModel = "synthetic-whisper"
        appState.whisperModelFolder = "/tmp/synthetic-whisper"
        appState.qwenModelId = "synthetic-qwen"
        appState.qwenModelFolder = "/tmp/synthetic-qwen.gguf"

        try expect(appState.whisperModel == "synthetic-whisper")
        try expect(appState.whisperModelFolder == "/tmp/synthetic-whisper")
        try expect(appState.qwenModelId == "synthetic-qwen")
        try expect(appState.qwenModelFolder == "/tmp/synthetic-qwen.gguf")
        try expect(config.whisperModel == appState.whisperModel)
        try expect(config.whisperModelFolder == appState.whisperModelFolder)
        try expect(config.qwenModelId == appState.qwenModelId)
        try expect(config.qwenModelFolder == appState.qwenModelFolder)
        try expect(appState.recordingDuration == appState.recording.recordingDuration)
        try expect(appState.isRecordingPaused == appState.recording.isRecordingPaused)
        try expect(appState.processingStem == appState.processing.processingStem)
        try expect(appState.versionString.hasPrefix("v0.1.0 · "))
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

    test("AppState: refreshing devices uses injected devices and replaces a disconnected selection") {
        let preferred = AudioDevice(id: 42, name: "Fixture microphone", uid: "fixture-mic")
        let systemDefault = AudioDevice(id: 43, name: "Fixture default", uid: "fixture-default")
        let recording = RecordingState(dependencies: .init(
            listInputDevices: { [preferred, systemDefault] },
            defaultInputDevice: { systemDefault },
            record: { _, _, _, _, _ in }
        ))
        recording.selectedDeviceUID = "disconnected-mic"
        let appState = AppState(recording: recording)

        appState.refreshDevices()

        try expect(appState.inputDevices == [preferred, systemDefault], "AppState should publish the injected device list")
        try expect(appState.selectedDeviceUID == systemDefault.uid, "A disconnected selection should fall back to the injected default")
    }

    await testAsync("AppState: directory watcher reload adds and removes entries from its configured data folder") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogWatcherReload-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let watcher = DirectoryWatcher()
        defer {
            watcher.stopWatching()
            try? fm.removeItem(at: root)
        }
        let config = ConfigManager()
        config.dataDir = root.path
        let appState = AppState(config: config, directoryWatcher: watcher)
        appState.configureDirectoryWatcher()

        let stem = "2025-01-14-0830"
        let transcript = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        let fixture = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("eval/transcribe/expected/durins-volk.md")
        try fm.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: fixture, to: transcript)
        watcher.scheduleReload()

        let deadline = ContinuousClock.now + .seconds(2)
        while !appState.allEntries.contains(where: { $0.stem == stem }) && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try expect(
            appState.allEntries.map(\.stem) == [stem],
            "A watcher reload should repopulate Logs from the configured data folder"
        )

        try fm.removeItem(at: transcript)
        watcher.scheduleReload()
        let removalDeadline = ContinuousClock.now + .seconds(2)
        while appState.allEntries.contains(where: { $0.stem == stem }) && ContinuousClock.now < removalDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try expect(appState.allEntries.isEmpty, "A watcher reload should remove deleted entries from Logs")
    }

    test("AppState: pause processing delegates to coordinator") {
        let appState = AppState()
        appState.pauseProcessing()
        try expect(appState.processing.stage == .idle)
    }

    await testAsync("AppState: batch resume keeps a failed entry visible and continues to the next one") {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("CaptainsLogAppStateBatchResume-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let stems = ["2025-01-14-0830", "2025-01-15-1015"]
        let fixture = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("eval/transcribe/expected/durins-volk.md")
        for stem in stems {
            let transcript = root.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
            try fm.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: fixture, to: transcript)
        }

        let config = ConfigManager()
        config.dataDir = root.path
        let resumed = LockedStringArray()
        let processing = ProcessingCoordinator { requestedStem, _, fromStage, _ in
            resumed.append("\(requestedStem):\(fromStage?.rawValue ?? "nil")")
            let firstEntryAttempts = resumed.snapshot().filter { $0.hasPrefix("\(stems[0]):") }.count
            if requestedStem == stems[0] && firstEntryAttempts == 1 {
                throw NSError(domain: "AppStateBatchResume", code: 1, userInfo: [NSLocalizedDescriptionKey: "First entry failed"])
            }
            return Pipeline.Result(
                audioPath: "\(requestedStem).m4a",
                transcriptPath: "\(requestedStem).transcript.md",
                cleanedPath: "\(requestedStem).cleaned.md",
                renamedPath: "\(requestedStem).renamed.md",
                enrichedPath: "\(requestedStem).enriched.md",
                slug: requestedStem,
                category: .personal
            )
        }
        let appState = AppState(config: config, processing: processing)
        appState.loadEntries()
        try expect(appState.pendingEntries.map(\.stem) == stems.sorted(by: >), "Fixture transcripts should be pending in Logs order before resume")

        appState.batchResumePending()
        let deadline = ContinuousClock.now + .seconds(2)
        while processing.stage != .done && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }

        try expect(
            resumed.snapshot() == stems.sorted(by: >).map { "\($0):cleaning" },
            "AppState should resume every pending entry from its detected cleaning stage"
        )
        try expect(processing.stage == .done, "AppState should expose completion after the batch finishes")
        try expect(processing.statusMessage == "Done", "AppState should expose the completed batch status")
        let entries = appState.allEntries
        try expect(entries.map(\.stem) == stems.sorted(by: >), "Both entries should remain visible in Logs order after the batch")
        let failedEntry = entries.first { $0.stem == stems[0] }
        let successfulEntry = entries.first { $0.stem == stems[1] }
        try expect(failedEntry?.processingError == "First entry failed", "The failed entry should expose its retryable error")
        try expect(successfulEntry?.processingError == nil, "The later successful entry should not inherit the earlier error")

        appState.resumeProcessing(stem: stems[0], fromStage: .cleaning)
        try expect(processing.errorMessage == nil, "Starting a retry should clear the previous visible failure")
        let retryDeadline = ContinuousClock.now + .seconds(2)
        while (resumed.snapshot().count < 3 || processing.stage != .done) && ContinuousClock.now < retryDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try expect(resumed.snapshot().last == "\(stems[0]):cleaning", "Retry should resume the failed entry from its recorded stage")
        try expect(processing.stage == .done, "Successful retry should complete the entry")
        try expect(
            appState.allEntries.first(where: { $0.stem == stems[0] })?.processingError == nil,
            "Successful retry should clear the error from the Logs row"
        )
    }

    test("Onboarding: completing first run dismisses setup and persists the launch choice") {
        let defaults = UserDefaults.standard
        let key = "CaptainsLogHasLaunched"
        let priorValue = defaults.object(forKey: key)
        defer {
            if let priorValue {
                defaults.set(priorValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.removeObject(forKey: key)

        let appState = AppState(config: ConfigManager())
        try expect(appState.needsFirstRun, "Fresh install should show onboarding")
        appState.completeFirstRun()
        try expect(!appState.needsFirstRun, "Completing setup should dismiss onboarding")
        try expect(defaults.bool(forKey: key), "Setup completion should persist across launches")
    }

    test("Onboarding policy: first run appears only for an unlaunched non-demo app") {
        let cases: [(Bool, Bool, Bool)] = [
            (false, false, true),
            (true, false, false),
            (false, true, false),
            (true, true, false),
        ]
        for (hasLaunched, demoMode, expected) in cases {
            try expect(
                FirstRunPresentationPolicy.shouldPresent(hasLaunched: hasLaunched, demoMode: demoMode) == expected,
                "Unexpected onboarding decision for launched=\(hasLaunched), demo=\(demoMode)"
            )
        }
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

    test("Pipeline: detectNextStage treats directories as incomplete artifacts") {
        let fm = FileManager.default
        let dataDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: dataDir) }
        let stem = "2025-01-01-directory-artifact"
        let slug = "2025-01-01-directory-artifact"

        let transcript = dataDir.appendingPathComponent(".pipeline/01-transcribed/\(stem).md")
        try fm.createDirectory(at: transcript, withIntermediateDirectories: true)
        try expect(Pipeline.detectNextStage(stem: stem, dataDir: dataDir.path) == .transcribing)

        try fm.removeItem(at: transcript)
        try fm.createDirectory(at: transcript.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "transcript".write(to: transcript, atomically: true, encoding: .utf8)
        let cleaned = dataDir.appendingPathComponent(".pipeline/02-logs/\(stem).md")
        try fm.createDirectory(at: cleaned, withIntermediateDirectories: true)
        try expect(Pipeline.detectNextStage(stem: stem, dataDir: dataDir.path) == .cleaning)

        try fm.removeItem(at: cleaned)
        try fm.createDirectory(at: cleaned.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "cleaned".write(to: cleaned, atomically: true, encoding: .utf8)
        try Categorize.writeManifest(.init(sourceStem: stem, category: .personal), dataDirURL: dataDir)

        let marker = dataDir.appendingPathComponent(".pipeline/04-rename/\(stem).slug.txt")
        try fm.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try slug.write(to: marker, atomically: true, encoding: .utf8)
        let renamed = dataDir.appendingPathComponent(".pipeline/04-rename/\(slug).md")
        try fm.createDirectory(at: renamed, withIntermediateDirectories: true)
        try expect(Pipeline.detectNextStage(stem: stem, dataDir: dataDir.path) == .naming)

        try fm.removeItem(at: renamed)
        try "renamed".write(to: renamed, atomically: true, encoding: .utf8)
        let enriched = dataDir.appendingPathComponent("logs/personal/\(slug).md")
        try fm.createDirectory(at: enriched, withIntermediateDirectories: true)
        try expect(Pipeline.detectNextStage(stem: stem, dataDir: dataDir.path) == .enriching)
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
    if !lightweightUnitOnly {
        await runAppWorkflowCoverageTests()
        await runSearchCoverageTests()
        await runCoordinatorCoverageTests()
        await runPipelineOrchestrationCoverageTests()
    }

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
        lightweightUnitOnly = CommandLine.arguments.contains("--unit")
        let testRoot = configureIsolatedTestEnvironment()
        defer {
            unsetenv("CAPTAINS_LOG_CONFIG_PATH")
            try? FileManager.default.removeItem(at: testRoot)
        }
        await runTests()
    }
}

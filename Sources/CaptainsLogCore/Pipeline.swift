import AVFoundation
import Foundation

public enum Pipeline {

    public enum Stage: String, Sendable {
        case recording
        case transcribing
        case cleaning
        case categorizing
        case naming
        case enriching
        case done
    }

    public enum Directory: String, CaseIterable, Sendable {
        case audio = "audio"
        case transcribed = ".pipeline/01-transcribed"
        case logs = ".pipeline/02-logs"
        case category = ".pipeline/03-category"
        case rename = ".pipeline/04-rename"
        case enriched = "logs"

        public var path: String { rawValue }
    }

    public enum ContextDirectory: String {
        case context = "context"

        public var path: String { rawValue }
    }

    public enum FileExt: String {
        case m4a = ".m4a"
        case md = ".md"
        case slug = ".slug.txt"

        public var path: String { rawValue }
    }

    public enum PipelineError: LocalizedError {
        case promptNotFound(stage: String, path: String)
        case missingSlugMarker(path: String)
        case invalidSlug(value: String)
        case missingSourceAudio(path: String)
        case injectedOperationsRequireAudioInput

        public var errorDescription: String? {
            switch self {
            case .promptNotFound(let stage, let path):
                return "[\(stage)] Prompt file not found: \(path)"
            case .missingSlugMarker(let path):
                return "Slug marker missing or empty — re-run from naming stage. Path: \(path)"
            case .invalidSlug(let value):
                return "Filename output must be a single path-free name: \(value)"
            case .missingSourceAudio(let path):
                return "Cannot redo processing because the source recording is missing: \(path)"
            case .injectedOperationsRequireAudioInput:
                return "An audio input is required when pipeline operations are injected."
            }
        }
    }

    public struct Progress: Sendable {
        public let stem: String
        public let stage: Stage
    }

    public struct Result: Sendable {
        public let audioPath: String
        public let transcriptPath: String
        public let cleanedPath: String
        public let renamedPath: String
        public let enrichedPath: String
        public let slug: String
        public let category: Categorize.Category
    }

    public typealias TranscribeOperation = @Sendable (_ audioPath: String, _ language: String?) async throws -> String
    public typealias CleanupOperation = @Sendable (_ transcript: String, _ config: CaptainsLogConfig) async throws -> String
    public typealias CategorizeOperation = @Sendable (
        _ cleaned: String,
        _ config: CaptainsLogConfig,
        _ diagnostic: @escaping @Sendable (String) async -> Void
    ) async throws -> Categorize.Category
    public typealias FilenameOperation = @Sendable (_ cleaned: String, _ date: String) async throws -> String
    public typealias EnrichOperation = @Sendable (
        _ cleaned: String,
        _ date: String,
        _ recordingTime: String,
        _ config: CaptainsLogConfig
    ) async throws -> String

    public struct Operations: Sendable {
        public let transcribe: TranscribeOperation
        public let cleanup: CleanupOperation
        public let categorize: CategorizeOperation
        public let filename: FilenameOperation
        public let enrich: EnrichOperation

        public init(
            transcribe: @escaping TranscribeOperation,
            cleanup: @escaping CleanupOperation,
            categorize: @escaping CategorizeOperation,
            filename: @escaping FilenameOperation,
            enrich: @escaping EnrichOperation
        ) {
            self.transcribe = transcribe
            self.cleanup = cleanup
            self.categorize = categorize
            self.filename = filename
            self.enrich = enrich
        }
    }

    public static func run(
        audioInput: String? = nil,
        dataDir: String,
        language: String? = nil,
        recordDuration: TimeInterval? = nil,
        modelId: String? = nil,
        progress: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> Result {
        let dataDirURL = URL(fileURLWithPath: dataDir)

        try ensurePipelineDirectories(dataDirURL: dataDirURL)

        // Step 1: Record or copy audio
        let stem = URL(fileURLWithPath: Recorder.defaultOutputPath()).deletingPathExtension().lastPathComponent
        let audioDestURL = dataDirURL.appendingPathComponent(Directory.audio.path).appendingPathComponent("\(stem).m4a")
        let audioPath: String

        if let audioInput {
            print("[1/6] Copying audio...")
            audioPath = try copyAudioInput(audioInput, dataDirURL: dataDirURL)
        } else {
            print("[1/6] Recording...")
            try await Recorder.record(to: audioDestURL, duration: recordDuration)
            audioPath = audioDestURL.path
        }

        let finalStem = URL(fileURLWithPath: audioPath).deletingPathExtension().lastPathComponent
        return try await processStages(
            stem: finalStem,
            dataDir: dataDir,
            fromStage: .transcribing,
            language: language,
            modelId: modelId,
            progress: progress
        )
    }

    /// Runs a fresh fixture-backed pipeline without loading local inference models.
    /// The recorder path stays on the public production overload because it requires audio hardware.
    public static func run(
        audioInput: String,
        dataDir: String,
        language: String? = nil,
        operations: Operations,
        progress: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> Result {
        let dataDirURL = URL(fileURLWithPath: dataDir)
        try ensurePipelineDirectories(dataDirURL: dataDirURL)
        print("[1/6] Copying audio...")
        let audioPath = try copyAudioInput(audioInput, dataDirURL: dataDirURL)
        let stem = URL(fileURLWithPath: audioPath).deletingPathExtension().lastPathComponent
        return try await processStages(
            stem: stem,
            dataDir: dataDir,
            fromStage: .transcribing,
            language: language,
            progress: progress,
            operations: operations
        )
    }

    /// Routes the CLI pipeline command through the production path or injected fixture operations.
    public static func runCommand(
        audioInput: String? = nil,
        dataDir: String,
        language: String? = nil,
        recordDuration: TimeInterval? = nil,
        modelId: String? = nil,
        operations: Operations? = nil,
        progress: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> Result {
        if let operations {
            guard let audioInput else { throw PipelineError.injectedOperationsRequireAudioInput }
            return try await run(
                audioInput: audioInput,
                dataDir: dataDir,
                language: language,
                operations: operations,
                progress: progress
            )
        }
        return try await run(
            audioInput: audioInput,
            dataDir: dataDir,
            language: language,
            recordDuration: recordDuration,
            modelId: modelId,
            progress: progress
        )
    }

    private static func copyAudioInput(_ audioInput: String, dataDirURL: URL) throws -> String {
        let inputURL = URL(fileURLWithPath: audioInput)
        let inputStem = inputURL.deletingPathExtension().lastPathComponent
        let destination = dataDirURL
            .appendingPathComponent(Directory.audio.path)
            .appendingPathComponent("\(inputStem).m4a")
        if inputURL.standardizedFileURL == destination.standardizedFileURL {
            return destination.path
        }
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: inputURL.path])
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: inputURL, to: destination)
        print("Audio copied to \(destination.path)")
        return destination.path
    }

    /// Resume processing for an existing stem in `dataDir`. If `fromStage` is nil,
    /// auto-detects the next stage to run from files present on disk.
    public static func resume(
        stem: String,
        dataDir: String,
        fromStage: Stage? = nil,
        language: String? = nil,
        modelId: String? = nil,
        progress: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> Result {
        let dataDirURL = URL(fileURLWithPath: dataDir)
        try ensurePipelineDirectories(dataDirURL: dataDirURL)
        let detected = detectNextStage(stem: stem, dataDir: dataDir)
        let start = effectiveStartStage(preferred: fromStage, detected: detected)
        return try await processStages(
            stem: stem,
            dataDir: dataDir,
            fromStage: start,
            language: language,
            modelId: modelId,
            progress: progress
        )
    }

    public static func resume(
        stem: String,
        dataDir: String,
        fromStage: Stage? = nil,
        language: String? = nil,
        operations: Operations,
        progress: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> Result {
        let dataDirURL = URL(fileURLWithPath: dataDir)
        try ensurePipelineDirectories(dataDirURL: dataDirURL)
        let detected = detectNextStage(stem: stem, dataDir: dataDir)
        let start = effectiveStartStage(preferred: fromStage, detected: detected)
        return try await processStages(
            stem: stem,
            dataDir: dataDir,
            fromStage: start,
            language: language,
            progress: progress,
            operations: operations
        )
    }

    /// Routes a single-entry resume command through production inference or injected fixture operations.
    public static func resumeCommand(
        stem: String,
        dataDir: String,
        fromStage: Stage? = nil,
        language: String? = nil,
        modelId: String? = nil,
        operations: Operations? = nil,
        progress: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> Result {
        if let operations {
            return try await resume(
                stem: stem,
                dataDir: dataDir,
                fromStage: fromStage,
                language: language,
                operations: operations,
                progress: progress
            )
        }
        return try await resume(
            stem: stem,
            dataDir: dataDir,
            fromStage: fromStage,
            language: language,
            modelId: modelId,
            progress: progress
        )
    }

    /// Resumes every pending CLI entry sequentially, with an injectable operation set for fixture tests.
    public static func resumePendingCommand(
        dataDir: String,
        language: String? = nil,
        modelId: String? = nil,
        operations: Operations? = nil,
        progress: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> [Result] {
        let entries = listEntries(dataDir: dataDir).filter { $0.nextStage != .done }
        guard !entries.isEmpty else {
            print("No pending entries to resume.")
            return []
        }

        print("Resuming \(entries.count) pending entr\(entries.count == 1 ? "y" : "ies")...\n")
        var results: [Result] = []
        for entry in entries {
            let detected = detectNextStage(stem: entry.stem, dataDir: dataDir)
            print("Processing \(entry.displayName) (starting at \(detected.rawValue))...")
            results.append(try await resumeCommand(
                stem: entry.stem,
                dataDir: dataDir,
                fromStage: detected,
                language: language,
                modelId: modelId,
                operations: operations,
                progress: progress
            ))
            print("✓ Completed \(entry.displayName)\n")
        }

        print("All entries processed!")
        return results
    }

    public struct EntryListing: Sendable {
        /// Display name. For pre-naming entries this is the stem; for post-naming, the slug stem.
        public let displayName: String
        /// Original timestamp-stem used to re-key audio through .pipeline/02-logs.
        public let stem: String
        /// Slug stem (filename without `.md`) if naming completed; nil otherwise.
        public let slug: String?
        /// Next stage to run. `.done` means fully processed.
        public let nextStage: Stage
        /// Absolute path to the most advanced artifact on disk (for reveal-in-finder).
        public let latestPath: String
    }

    /// Scan a data directory and return one entry per distinct recording, tagged
    /// with the next stage that needs to run. Used by the UI to show partial/paused
    /// entries and by `cl list`-style tools.
    public static func listEntries(dataDir: String) -> [EntryListing] {
        let fm = FileManager.default
        let dataDirURL = URL(fileURLWithPath: dataDir)
        var out: [EntryListing] = []
        var claimedStems = Set<String>()

        // Pass 1: named entries (have a slug marker in .pipeline/04-rename).
        // Stage detection is delegated to detectNextStage so missing prerequisite
        // files cause a fallback to the earliest incomplete step.
        let renameDirURL = dataDirURL.appendingPathComponent(Directory.rename.path)
        let enrichedDirURL = dataDirURL.appendingPathComponent(Directory.enriched.path)
        let markers = (try? fm.contentsOfDirectory(atPath: renameDirURL.path)) ?? []
        for marker in markers where marker.hasSuffix(FileExt.slug.path) {
            let stem = String(marker.dropLast(FileExt.slug.path.count))
            let markerURL = renameDirURL.appendingPathComponent(marker)
            guard let slug = readStoredSlug(markerPath: markerURL.path) else { continue }
            claimedStems.insert(stem)
            let nextStage = detectNextStage(stem: stem, dataDir: dataDir)
            let renamedPath = renameDirURL.appendingPathComponent("\(slug).md").path
            let cleanedPath = dataDirURL.appendingPathComponent(Directory.logs.path).appendingPathComponent("\(stem).md").path
            let transcriptPath = dataDirURL.appendingPathComponent(Directory.transcribed.path).appendingPathComponent("\(stem).md").path
            let category = (try? Categorize.loadManifest(stem: stem, dataDirURL: dataDirURL))?.category
            let enrichedPath = category.map {
                enrichedDirURL.appendingPathComponent($0.folderName).appendingPathComponent("\(slug).md").path
            } ?? enrichedDirURL.appendingPathComponent("\(slug).md").path
            let latestPath = fm.fileExists(atPath: enrichedPath)
                ? enrichedPath
                : fm.fileExists(atPath: renamedPath)
                    ? renamedPath
                    : fm.fileExists(atPath: cleanedPath)
                        ? cleanedPath
                        : fm.fileExists(atPath: transcriptPath)
                            ? transcriptPath
                            : dataDirURL.appendingPathComponent(Directory.audio.path).appendingPathComponent("\(stem).m4a").path
            out.append(EntryListing(
                displayName: slug, stem: stem, slug: slug,
                nextStage: nextStage, latestPath: latestPath))
        }

        // Pass 2: un-named stems — discover from stage dirs, delegate stage to detectNextStage.
        let discoverDirs: [(URL, String)] = [
            (dataDirURL.appendingPathComponent(Directory.logs.path),       FileExt.md.path),
            (dataDirURL.appendingPathComponent(Directory.transcribed.path), FileExt.md.path),
            (dataDirURL.appendingPathComponent(Directory.audio.path),      FileExt.m4a.path),
        ]
        for (dirURL, ext) in discoverDirs {
            let files = (try? fm.contentsOfDirectory(atPath: dirURL.path)) ?? []
            for f in files where f.hasSuffix(ext) {
                let stem = String(f.dropLast(ext.count))
                if claimedStems.contains(stem) { continue }
                claimedStems.insert(stem)
                let nextStage = detectNextStage(stem: stem, dataDir: dataDir)
                // latestPath: most advanced existing artifact for this stem.
                let latestPath: String
                let cleanedPath = dataDirURL.appendingPathComponent(Directory.logs.path).appendingPathComponent("\(stem).md").path
                let transcriptPath = dataDirURL.appendingPathComponent(Directory.transcribed.path).appendingPathComponent("\(stem).md").path
                if fm.fileExists(atPath: cleanedPath) {
                    latestPath = cleanedPath
                } else if fm.fileExists(atPath: transcriptPath) {
                    latestPath = transcriptPath
                } else {
                    latestPath = dataDirURL.appendingPathComponent(Directory.audio.path).appendingPathComponent("\(stem).m4a").path
                }
                out.append(EntryListing(
                    displayName: stem, stem: stem, slug: nil,
                    nextStage: nextStage, latestPath: latestPath))
            }
        }

        return out.sorted { $0.stem > $1.stem }
    }

    public static func deletionCandidatePaths(stem: String, slug: String?, dataDir: String) -> [String] {
        artifactCandidatePaths(stem: stem, slug: slug, dataDir: dataDir, includeAudio: true)
    }

    /// Files regenerated by a full reprocess. The source recording is deliberately
    /// excluded so the entire pipeline can safely restart at transcription.
    public static func reprocessingCandidatePaths(stem: String, slug: String?, dataDir: String) -> [String] {
        artifactCandidatePaths(stem: stem, slug: slug, dataDir: dataDir, includeAudio: false)
    }

    public static func resetForReprocessing(stem: String, slug: String?, dataDir: String) throws {
        let fm = FileManager.default
        let audioPath = URL(fileURLWithPath: dataDir)
            .appendingPathComponent(Directory.audio.path)
            .appendingPathComponent("\(stem).m4a")
            .path
        guard fm.fileExists(atPath: audioPath) else {
            throw PipelineError.missingSourceAudio(path: audioPath)
        }
        for path in reprocessingCandidatePaths(stem: stem, slug: slug, dataDir: dataDir) {
            if fm.fileExists(atPath: path) {
                try fm.removeItem(atPath: path)
            }
        }
    }

    private static func artifactCandidatePaths(
        stem: String,
        slug: String?,
        dataDir: String,
        includeAudio: Bool
    ) -> [String] {
        let dataDirURL = URL(fileURLWithPath: dataDir)
        let markerURL = canonicalMarkerURL(stem: stem, dataDirURL: dataDirURL)
        let storedSlug = slug.flatMap { isSafeSlug($0) ? $0 : nil }
            ?? readStoredSlug(markerPath: markerURL.path)
        var candidates: [String] = [
            dataDirURL.appendingPathComponent(Directory.transcribed.path).appendingPathComponent("\(stem).md").path,
            dataDirURL.appendingPathComponent(Directory.logs.path).appendingPathComponent("\(stem).md").path,
            Categorize.manifestURL(stem: stem, dataDirURL: dataDirURL).path,
            dataDirURL.appendingPathComponent(Directory.category.path).appendingPathComponent("\(stem).log").path,
            markerURL.path,
        ]

        if includeAudio {
            candidates.append(
                dataDirURL.appendingPathComponent(Directory.audio.path).appendingPathComponent("\(stem).m4a").path
            )
        }

        if let storedSlug {
            candidates.append(
                dataDirURL.appendingPathComponent(Directory.rename.path).appendingPathComponent("\(storedSlug).md").path
            )
            candidates.append(
                dataDirURL.appendingPathComponent(Directory.enriched.path).appendingPathComponent("\(storedSlug).md").path
            )
        }

        if let manifest = try? Categorize.loadManifest(stem: stem, dataDirURL: dataDirURL), let storedSlug {
            candidates.append(dataDirURL
                .appendingPathComponent(Directory.enriched.path)
                .appendingPathComponent(manifest.category.folderName)
                .appendingPathComponent("\(storedSlug).md").path)
        }

        return Array(Set(candidates)).sorted()
    }

    /// Given a stem, find the next stage to run based on outputs present on disk.
    /// Falls back to earlier stages if prerequisite files are missing, so processStages
    /// never tries to load a file that doesn't exist.
    public static func detectNextStage(stem: String, dataDir: String) -> Stage {
        let dataDirURL = URL(fileURLWithPath: dataDir)
        let transcriptPath = dataDirURL.appendingPathComponent(Directory.transcribed.path).appendingPathComponent("\(stem).md").path
        let cleanedPath = dataDirURL.appendingPathComponent(Directory.logs.path).appendingPathComponent("\(stem).md").path
        let markerPath = canonicalMarkerURL(stem: stem, dataDirURL: dataDirURL).path

        if !isRegularFile(atPath: transcriptPath) { return .transcribing }
        if !isRegularFile(atPath: cleanedPath) { return .cleaning }

        guard let categoryManifest = try? Categorize.loadManifest(stem: stem, dataDirURL: dataDirURL) else {
            return .categorizing
        }

        guard let slug = readStoredSlug(markerPath: markerPath) else {
            return .naming
        }

        let renamedPath = dataDirURL.appendingPathComponent(Directory.rename.path).appendingPathComponent("\(slug).md").path
        if !isRegularFile(atPath: renamedPath) {
            return .naming
        }

        let enrichedPath = dataDirURL.appendingPathComponent(Directory.enriched.path).appendingPathComponent(categoryManifest.category.folderName).appendingPathComponent("\(slug).md").path
        if !isRegularFile(atPath: enrichedPath) {
            return .enriching
        }

        return .done
    }

    private static func processStages(
        stem: String,
        dataDir: String,
        fromStage: Stage,
        language: String?,
        modelId: String? = nil,
        progress: (@Sendable (Progress) -> Void)?,
        operations: Operations? = nil
    ) async throws -> Result {
        let dataDirURL = URL(fileURLWithPath: dataDir)
        let categoryDiagnostics = DiagnosticLog(
            path: dataDirURL
                .appendingPathComponent(Directory.category.path)
                .appendingPathComponent("\(stem).log")
                .path
            , label: "category"
        )
        await categoryDiagnostics.log("Pipeline processing began from \(fromStage.rawValue). Trace: \(categoryDiagnostics.path)")
        let date = extractDate(from: stem)
        let recordingTime = extractRecordingTime(stem: stem, dataDirURL: dataDirURL)
        let promptConfig = CaptainsLogConfig.load().withDataDir(dataDir)

        let transcribeOperation: TranscribeOperation
        if let operations {
            transcribeOperation = operations.transcribe
        } else {
            transcribeOperation = { audioPath, language in
                try await Transcriber.transcribe(audioPath: audioPath, language: language)
            }
        }

        let transcript = try await runTranscribe(
            stem: stem, dataDirURL: dataDirURL, fromStage: fromStage,
            language: language, progress: progress,
            operation: transcribeOperation)

        let textOperations: Operations
        if let operations {
            textOperations = operations
        } else {
            let container = try await LLM.loadModel(modelId: modelId)
            textOperations = Operations(
                transcribe: { _, _ in "" },
                cleanup: { transcript, config in
                    try await Cleanup.cleanup(transcript: transcript, container: container, config: config)
                },
                categorize: { cleaned, config, diagnostic in
                    try await Categorize.categorize(
                        logText: cleaned,
                        container: container,
                        config: config,
                        diagnostic: diagnostic
                    )
                },
                filename: { cleaned, date in
                    try await Filename.generateFilename(logText: cleaned, date: date, container: container)
                },
                enrich: { cleaned, date, recordingTime, config in
                    try await Enrich.enrich(
                        logText: cleaned,
                        date: date,
                        recordingTime: recordingTime,
                        container: container,
                        config: config
                    )
                }
            )
        }
        let cleaned = try await runCleanup(
            stem: stem, transcript: transcript, dataDirURL: dataDirURL,
            fromStage: fromStage, config: promptConfig,
            operation: textOperations.cleanup,
            progress: progress)

        let category = try await runCategorize(
            stem: stem, cleaned: cleaned, dataDirURL: dataDirURL,
            fromStage: fromStage, config: promptConfig,
            operation: textOperations.categorize,
            progress: progress, diagnostics: categoryDiagnostics)

        let slugStem = try await runFilename(
            stem: stem, cleaned: cleaned, date: date, dataDirURL: dataDirURL,
            fromStage: fromStage, operation: textOperations.filename, progress: progress)

        try await runEnrich(
            stem: stem, slugStem: slugStem, cleaned: cleaned, date: date,
            recordingTime: recordingTime, dataDirURL: dataDirURL,
            fromStage: fromStage, config: promptConfig, category: category,
            operation: textOperations.enrich,
            progress: progress)

        let audioPath = dataDirURL.appendingPathComponent(Directory.audio.path).appendingPathComponent("\(stem).m4a").path
        let transcriptPath = dataDirURL.appendingPathComponent(Directory.transcribed.path).appendingPathComponent("\(stem).md").path
        let cleanedPath = dataDirURL.appendingPathComponent(Directory.logs.path).appendingPathComponent("\(stem).md").path
        let renamedPath = dataDirURL.appendingPathComponent(Directory.rename.path).appendingPathComponent("\(slugStem).md").path
        let enrichedPath = dataDirURL.appendingPathComponent(Directory.enriched.path).appendingPathComponent(category.folderName).appendingPathComponent("\(slugStem).md").path

        progress?(Progress(stem: stem, stage: .done))
        print("Pipeline complete!")
        return Result(
            audioPath: audioPath,
            transcriptPath: transcriptPath,
            cleanedPath: cleanedPath,
            renamedPath: renamedPath,
            enrichedPath: enrichedPath,
            slug: "\(slugStem).md",
            category: category
        )
    }

    private static func runTranscribe(
        stem: String,
        dataDirURL: URL,
        fromStage: Stage,
        language: String?,
        progress: (@Sendable (Progress) -> Void)?,
        operation: TranscribeOperation
    ) async throws -> String {
        let transcriptPath = dataDirURL.appendingPathComponent(Directory.transcribed.path).appendingPathComponent("\(stem).md").path
        guard stageOrder(fromStage) <= stageOrder(.transcribing) else {
            return try String(contentsOfFile: transcriptPath, encoding: .utf8)
        }
        progress?(Progress(stem: stem, stage: .transcribing))
        print("[2/6] Transcribing...")
        let audioPath = dataDirURL.appendingPathComponent(Directory.audio.path).appendingPathComponent("\(stem).m4a").path
        try FileSystemGuard.requireFreeSpaceForTranscription(paths: [
            transcriptPath,
            CaptainsLogConfig.configURL.path,
            NSTemporaryDirectory(),
        ])
        let transcript = try await operation(audioPath, language)
        try FileSystemGuard.writeText(transcript, to: transcriptPath)
        return transcript
    }

    private static func runCleanup(
        stem: String,
        transcript: String,
        dataDirURL: URL,
        fromStage: Stage,
        config: CaptainsLogConfig,
        operation: CleanupOperation,
        progress: (@Sendable (Progress) -> Void)?
    ) async throws -> String {
        let cleanedPath = dataDirURL.appendingPathComponent(Directory.logs.path).appendingPathComponent("\(stem).md").path
        guard stageOrder(fromStage) <= stageOrder(.cleaning) else {
            return try String(contentsOfFile: cleanedPath, encoding: .utf8)
        }
        progress?(Progress(stem: stem, stage: .cleaning))
        print("[3/6] Cleaning up...")
        let cleaned = try await operation(transcript, config)
        try FileSystemGuard.writeText(cleaned, to: cleanedPath)
        return cleaned
    }

    private static func runCategorize(
        stem: String,
        cleaned: String,
        dataDirURL: URL,
        fromStage: Stage,
        config: CaptainsLogConfig,
        operation: CategorizeOperation,
        progress: (@Sendable (Progress) -> Void)?,
        diagnostics: DiagnosticLog
    ) async throws -> Categorize.Category {
        if let existing = try? Categorize.loadManifest(stem: stem, dataDirURL: dataDirURL) {
            await diagnostics.log("Using existing category manifest: \(existing.category.rawValue).")
            return existing.category
        }

        guard stageOrder(fromStage) <= stageOrder(.categorizing) else {
            throw Categorize.CategorizeError.missingManifest(
                path: Categorize.manifestURL(stem: stem, dataDirURL: dataDirURL).path
            )
        }

        progress?(Progress(stem: stem, stage: .categorizing))
        print("[4/6] Categorizing...")
        await diagnostics.log("Category stage started for \(stem); cleaned source is \(cleaned.utf8.count) bytes.")
        let category: Categorize.Category
        do {
            category = try await operation(
                cleaned,
                config,
                { message in await diagnostics.log(message) }
            )
        } catch {
            await diagnostics.log("Category stage failed (error type: \(String(reflecting: type(of: error)))).")
            throw error
        }
        let manifest = Categorize.Manifest(sourceStem: stem, category: category)
        try Categorize.writeManifest(manifest, dataDirURL: dataDirURL)
        await diagnostics.log("Category manifest written to \(Categorize.manifestURL(stem: stem, dataDirURL: dataDirURL).path).")
        return category
    }

    private static func runFilename(
        stem: String,
        cleaned: String,
        date: String,
        dataDirURL: URL,
        fromStage: Stage,
        operation: FilenameOperation,
        progress: (@Sendable (Progress) -> Void)?
    ) async throws -> String {
        let markerPath = canonicalMarkerURL(stem: stem, dataDirURL: dataDirURL).path
        if let storedSlug = readStoredSlug(markerPath: markerPath) {
            let renamedPath = dataDirURL.appendingPathComponent(Directory.rename.path).appendingPathComponent("\(storedSlug).md").path
            if FileManager.default.fileExists(atPath: renamedPath) {
                return storedSlug
            }
        }

        guard stageOrder(fromStage) <= stageOrder(.naming) else {
            guard let storedSlug = readStoredSlug(markerPath: markerPath) else {
                throw PipelineError.missingSlugMarker(path: markerPath)
            }
            let renamedPath = dataDirURL.appendingPathComponent(Directory.rename.path).appendingPathComponent("\(storedSlug).md").path
            if !FileManager.default.fileExists(atPath: renamedPath) {
                try FileSystemGuard.writeText(cleaned, to: renamedPath)
            }
            return storedSlug
        }
        progress?(Progress(stem: stem, stage: .naming))
        print("[5/6] Generating filename...")
        let slug = try await operation(cleaned, date)
        guard isSafeSlug(slug) else {
            throw PipelineError.invalidSlug(value: slug)
        }
        let slugStem = URL(fileURLWithPath: slug).deletingPathExtension().lastPathComponent
        try FileManager.default.createDirectory(
            at: dataDirURL.appendingPathComponent(Directory.rename.path),
            withIntermediateDirectories: true
        )
        try FileSystemGuard.writeText(slugStem, to: markerPath)
        let renamedPath = dataDirURL.appendingPathComponent(Directory.rename.path).appendingPathComponent(slug).path
        try FileSystemGuard.writeText(cleaned, to: renamedPath)
        return slugStem
    }

    private static func runEnrich(
        stem: String,
        slugStem: String,
        cleaned: String,
        date: String,
        recordingTime: String,
        dataDirURL: URL,
        fromStage: Stage,
        config: CaptainsLogConfig,
        category: Categorize.Category,
        operation: EnrichOperation,
        progress: (@Sendable (Progress) -> Void)?
    ) async throws {
        let enrichedPath = dataDirURL.appendingPathComponent(Directory.enriched.path).appendingPathComponent(category.folderName).appendingPathComponent("\(slugStem).md").path
        if FileManager.default.fileExists(atPath: enrichedPath) { return }
        guard stageOrder(fromStage) <= stageOrder(.enriching) else { return }
        progress?(Progress(stem: stem, stage: .enriching))
        print("[6/6] Enriching...")
        let enriched = try await operation(cleaned, date, recordingTime, config)
        try FileSystemGuard.writeText(enriched, to: enrichedPath)
    }

    private static func stageOrder(_ s: Stage) -> Int {
        switch s {
        case .recording:    return 0
        case .transcribing: return 1
        case .cleaning:     return 2
        case .categorizing: return 3
        case .naming:       return 4
        case .enriching:    return 5
        case .done:         return 6
        }
    }

    private static func ensurePipelineDirectories(dataDirURL: URL) throws {
        for dir in Directory.allCases {
            try FileManager.default.createDirectory(
                at: dataDirURL.appendingPathComponent(dir.path),
                withIntermediateDirectories: true
            )
        }
        for category in Categorize.Category.allCases {
            try FileManager.default.createDirectory(
                at: dataDirURL
                    .appendingPathComponent(Directory.enriched.path)
                    .appendingPathComponent(category.folderName),
                withIntermediateDirectories: true
            )
        }
        try FileManager.default.createDirectory(
            at: dataDirURL.appendingPathComponent(ContextDirectory.context.path),
            withIntermediateDirectories: true
        )
    }

    private static func canonicalMarkerURL(stem: String, dataDirURL: URL) -> URL {
        dataDirURL
            .appendingPathComponent(Directory.rename.path)
            .appendingPathComponent("\(stem).slug.txt")
    }

    private static func readStoredSlug(markerPath: String) -> String? {
        guard let slug = try? String(contentsOfFile: markerPath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), isSafeSlug(slug) else {
            return nil
        }
        return slug
    }

    private static func isSafeSlug(_ slug: String) -> Bool {
        !slug.isEmpty && !slug.contains("/") && !slug.contains("\\") && slug != "." && slug != ".."
    }

    private static func isRegularFile(atPath path: String) -> Bool {
        let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.isRegularFileKey])
        return values?.isRegularFile == true
    }

    private static func effectiveStartStage(preferred: Stage?, detected: Stage) -> Stage {
        guard let preferred else { return detected }
        return stageOrder(preferred) > stageOrder(detected) ? detected : preferred
    }

    static func extractDate(from stem: String) -> String {
        if let datePattern = try? Regex(#"^\d{4}-\d{2}-\d{2}"#),
           let match = stem.firstMatch(of: datePattern) {
            return String(stem[match.range])
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// Reads the audio file's creation date for the canonical recording time.
    /// Falls back to parsing `HHmm` from the stem if the audio file is missing.
    static func extractRecordingTime(stem: String, dataDirURL: URL) -> String {
        let audioPath = dataDirURL.appendingPathComponent(Directory.audio.path).appendingPathComponent("\(stem).m4a").path
        if let attrs = try? FileManager.default.attributesOfItem(atPath: audioPath),
           let creationDate = attrs[.creationDate] as? Date {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: creationDate)
        }
        // Fallback: parse HHmm from stem (yyyy-MM-dd-HHmm)
        let parts = stem.split(separator: "-")
        guard parts.count >= 4 else { return "00:00" }
        let fourth = String(parts[3])
        guard fourth.count == 4, fourth.allSatisfy(\.isNumber),
              let h = Int(fourth.prefix(2)), let m = Int(fourth.suffix(2)),
              h < 24, m < 60 else { return "00:00" }
        return "\(String(format: "%02d", h)):\(String(format: "%02d", m))"
    }
}

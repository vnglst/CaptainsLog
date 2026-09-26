import AVFoundation
import CaptainsLogCore
import Foundation
import SwiftUI

public enum AppStage: String {
    case idle
    case recording
    case transcribing
    case cleaning = "cleaning up"
    case categorizing
    case naming
    case enriching
    case done
    case error
}

/// Central app state coordinating specialized managers. Provides unified interface for the UI.
@MainActor
@Observable
public final class AppState {
    // MARK: - Child Managers

    public let config: ConfigManager
    public let recording: RecordingState
    public let processing: ProcessingCoordinator
    public let models: ModelManager
    public let directoryWatcher: DirectoryWatcher
    public let search: SearchManager
    private let moveToTrash: (URL) -> Void

    // MARK: - Entries

    var entries: [LogEntry] = []

    var allEntries: [LogEntry] {
        return entries.map { entry in
            var copy = entry
            copy.processingError = processing.failureMessage(for: entry.stem)
            if entry.stem == processing.processingStem {
                copy.stage = processing.processingStage
                copy.isActive = true
            }
            return copy
        }
    }

    var pendingEntries: [LogEntry] {
        entries.filter { $0.stage != .done }
    }

    // MARK: - Computed Properties (passthroughs)

    public var stage: AppStage { processing.stage }
    public var audioLevel: Float { recording.audioLevel }
    public var recordingDuration: TimeInterval { recording.recordingDuration }
    public var statusMessage: String { processing.statusMessage }
    public var errorMessage: String? { processing.errorMessage ?? recording.errorMessage }
    public var modelState: ModelState { models.modelState }
    public var inputDevices: [AudioDevice] { recording.inputDevices }
    public var selectedDeviceUID: String? {
        get { recording.selectedDeviceUID }
        set { recording.selectedDeviceUID = newValue }
    }
    public var isProcessing: Bool { processing.isProcessing }
    public var isRecording: Bool { recording.isRecording }
    public var isRecordingPaused: Bool { recording.isRecordingPaused }
    public var dataDir: String { config.dataDir }
    public var needsFirstRun: Bool { needsFirstRunDisplay }
    public var modelsReady: Bool { models.modelsReady }

    public var versionString: String {
        "v\(Self.appVersion) · \(Self.gitCommitHash)"
    }

    private static let appVersion = "0.1.0"

    // Read from the app bundle's Info.plist (injected by build-app.sh at package time).
    // Falls back to "dev" in plain `swift build` or `swift run` invocations.
    private static let gitCommitHash: String =
        Bundle.main.infoDictionary?["GitCommitHash"] as? String ?? "dev"

    /// True when the app should show the first-run setup flow.
    private var needsFirstRunDisplay: Bool = false
    private var hasBootstrapped = false
    public var processingStem: String? { processing.processingStem }

    // Config passthroughs for SettingsView
    public var personalContext: String {
        get { config.personalContext }
        set { config.personalContext = newValue }
    }
    public var corrections: String {
        get { config.corrections }
        set { config.corrections = newValue }
    }
    public var whisperModel: String {
        get { config.whisperModel }
        set { config.whisperModel = newValue }
    }
    public var whisperModelFolder: String {
        get { config.whisperModelFolder }
        set { config.whisperModelFolder = newValue }
    }
    public var qwenModelId: String {
        get { config.qwenModelId }
        set { config.qwenModelId = newValue }
    }
    public var qwenModelFolder: String {
        get { config.qwenModelFolder }
        set { config.qwenModelFolder = newValue }
    }

    // MARK: - Initialization

    public init() {
        // Context Markdown is settings-only UI state and the pipeline reads it
        // directly. Avoid touching those files before the recording UI appears.
        config = ConfigManager(loadContextFiles: false)
        recording = RecordingState()
        processing = ProcessingCoordinator()
        models = ModelManager()
        search = SearchManager()
        moveToTrash = { url in try? FileManager.default.trashItem(at: url, resultingItemURL: nil) }
        // Initialize with placeholder closure - will be configured after init
        directoryWatcher = DirectoryWatcher(onReload: { })
        // Set initial first-run state from config
        needsFirstRunDisplay = config.needsFirstRun
    }

    init(
        config: ConfigManager = ConfigManager(),
        recording: RecordingState = RecordingState(),
        processing: ProcessingCoordinator = ProcessingCoordinator(),
        models: ModelManager = ModelManager(),
        search: SearchManager = SearchManager(),
        directoryWatcher: DirectoryWatcher = DirectoryWatcher(onReload: { }),
        moveToTrash: @escaping (URL) -> Void = {
            try? FileManager.default.trashItem(at: $0, resultingItemURL: nil)
        }
    ) {
        self.config = config
        self.recording = recording
        self.processing = processing
        self.models = models
        self.search = search
        self.directoryWatcher = directoryWatcher
        self.moveToTrash = moveToTrash
        needsFirstRunDisplay = config.needsFirstRun
    }

    /// Called by CaptainsLogApp after self is fully constructed
    public func configureDirectoryWatcher() {
        directoryWatcher.onReload = { [weak self] in
            self?.loadEntries()
            guard let self else { return }
            self.search.invalidateIndex(dataDir: self.config.dataDir)
        }
        directoryWatcher.startWatching(dataDir: config.dataDir)
    }

    // MARK: - Actions

    public func completeFirstRun() {
        config.completeFirstRun()
        needsFirstRunDisplay = false
    }

    #if DEBUG
    /// Used only by the deterministic visual-fixture harness. Keeping this inside
    /// `AppState` preserves the production first-run encapsulation.
    func suppressFirstRunForDesignFixture() {
        needsFirstRunDisplay = false
    }

    func presentFirstRunForDesignFixture() {
        needsFirstRunDisplay = true
    }
    #endif

    func pickWhisperModelFolder() {
        config.pickWhisperModelFolder()
    }

    func pickQwenModelFolder() {
        config.pickQwenModelFolder()
    }

    func pickDataDirectory() {
        config.pickDataDirectory()
        loadEntries()
        directoryWatcher.startWatching(dataDir: config.dataDir)
        config.reloadContextFiles()
        search.updateQuery("", dataDir: config.dataDir)
    }

    public func refreshDevices() {
        recording.refreshDevices()
    }

    func startRecording() {
        guard !recording.isRecording else { return }
        processing.stage = .recording
        recording.startRecording(
            dataDir: config.dataDir,
            onComplete: { [weak self] stem in
                self?.onRecordingComplete(stem: stem)
            },
            onError: { [weak self] error in
                self?.onRecordingError(error)
            }
        )
    }

    private func onRecordingComplete(stem: String) {
        processing.queueProcessing(stem: stem)
        loadEntries()
        startQueuedProcessingIfPossible()
    }

    private func startQueuedProcessingIfPossible() {
        guard modelsReady else {
            processing.stage = .idle
            processing.statusMessage = "Waiting for local models"
            return
        }
        processing.startProcessing(
            dataDir: config.dataDir,
            isRecording: recording.isRecording,
            onProgress: { [weak self] in self?.loadEntries() },
            onComplete: { [weak self] in
                self?.processing.stage = self?.recording.isRecording == true ? .recording : .done
                self?.loadEntries()
            },
            onError: { [weak self] _ in self?.loadEntries() }
        )
    }

    private func onRecordingError(_ error: Error) {
        if !processing.isProcessing {
            processing.stage = .error
            processing.errorMessage = error.localizedDescription
            processing.statusMessage = "Error: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        recording.stopRecording()
    }

    public func pauseRecording() {
        recording.pauseRecording()
    }

    public func resumeRecording() {
        recording.resumeRecording()
    }

    public func pauseProcessing() {
        processing.pauseProcessing()
        loadEntries()
    }

    func resumeProcessing(stem: String, fromStage: Pipeline.Stage? = nil) {
        processing.resumeEntry(
            stem: stem,
            fromStage: fromStage,
            dataDir: config.dataDir,
            onComplete: { [weak self] in self?.loadEntries() },
            onError: { [weak self] _ in self?.loadEntries() }
        )
    }

    func reprocessEntry(stem: String, slug: String?) {
        guard processing.processingStem == nil else { return }
        do {
            try Pipeline.resetForReprocessing(stem: stem, slug: slug, dataDir: config.dataDir)
            loadEntries()
            resumeProcessing(stem: stem, fromStage: .transcribing)
        } catch {
            processing.recordPreparationFailure(error, for: stem)
            loadEntries()
        }
    }

    public func batchResumePending() {
        processing.batchResumePending(
            pendingEntries: pendingEntries,
            dataDir: config.dataDir,
            onProgress: { [weak self] in self?.loadEntries() },
            onComplete: { [weak self] in
                self?.processing.stage = .done
                self?.loadEntries()
            },
            onError: { _ in }
        )
    }

    public func deleteEntry(stem: String, slug: String?) {
        guard processing.processingStem != stem else { return }
        let candidates = Pipeline.deletionCandidatePaths(
            stem: stem,
            slug: slug,
            dataDir: config.dataDir
        )
        for path in candidates {
            moveToTrash(URL(fileURLWithPath: path))
        }
        loadEntries()
    }

    public func ensureModelsDownloaded() {
        models.ensureModelsDownloaded { [weak self] in
            self?.startQueuedProcessingIfPossible()
        }
    }

    /// Starts nonessential launch work only after SwiftUI has had a chance to
    /// present the recording UI. Recording itself does not depend on any of it.
    public func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        await Task.yield()
        ensureModelsDownloaded()
        async let deviceRefresh: Void = recording.refreshDevicesInBackground()
        let dataDir = config.dataDir
        let entryLoadingTask = Task.detached(priority: .utility) {
            Pipeline.listEntries(dataDir: dataDir).map(LogEntry.from)
        }
        entries = await entryLoadingTask.value
        await deviceRefresh
        configureDirectoryWatcher()
    }

    public func loadEntries() {
        entries = Pipeline.listEntries(dataDir: config.dataDir).map(LogEntry.from)
    }

    #if DEBUG
    /// End-to-end startup probe used by scripts/benchmark-startup.sh. The marker
    /// is written only after the real recorder has produced audio bytes.
    func benchmarkRecordingStartup(markerPath: String) async {
        let audioDir = URL(fileURLWithPath: config.dataDir)
            .appendingPathComponent(Pipeline.Directory.audio.path)
        startRecording()

        for _ in 0..<200 {
            if let files = try? FileManager.default.contentsOfDirectory(
                at: audioDir,
                includingPropertiesForKeys: [.fileSizeKey]
            ), files.contains(where: {
                ((try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) > 1_024
            }) {
                try? "ready\n".write(
                    toFile: markerPath,
                    atomically: true,
                    encoding: .utf8
                )
                stopRecording()
                return
            }
            try? await Task.sleep(for: .milliseconds(25))
        }
        stopRecording()
    }
    #endif

}

struct LogEntry: Identifiable, Sendable {
    var id: String { stem }
    /// Original recording stem (timestamp-based, format `yyyy-MM-dd-HHmm`), stable across stages.
    let stem: String
    let slug: String?
    let displayName: String
    let path: String
    let summary: String?
    let tags: [String]
    let projects: [String]
    /// Recording time from frontmatter, if present. Canonical over stem-based parsing.
    let frontmatterTime: String?
    /// Next stage to run. `.done` means fully processed.
    var stage: Pipeline.Stage
    /// True when this entry is the one actively being processed (not paused).
    var isActive: Bool = false
    /// A recoverable processing error for this entry. Cleared when it is retried.
    var processingError: String?

    /// Time of recording: prefers frontmatter `recording_time`, falls back to stem `HHmm` parse.
    var recordingTime: String? {
        if let frontmatterTime { return frontmatterTime }
        let parts = stem.split(separator: "-")
        guard parts.count >= 4 else { return nil }
        let fourth = String(parts[3])
        guard fourth.count == 4, fourth.allSatisfy(\.isNumber),
              let h = Int(fourth.prefix(2)), let m = Int(fourth.suffix(2)),
              h < 24, m < 60 else { return nil }
        return "\(String(format: "%02d", h)):\(String(format: "%02d", m))"
    }

    /// Date component of the stem as a `Date` for grouping by day.
    /// All stem formats start with `yyyy-MM-dd`, so taking the first 10 characters
    /// works regardless of whether the rest is `-HHmm`, `-description`, or ` description`.
    var recordingDate: Date? {
        guard stem.count >= 10 else { return nil }
        return Self.stemDateFormatter.date(from: String(stem.prefix(10)))
    }

    private static let stemDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        f.isLenient = false
        return f
    }()

    static func from(_ listing: Pipeline.EntryListing) -> LogEntry {
        let (summary, tags, projects, frontmatterTime) = listing.nextStage == .done
            ? Self.parseFrontmatter(from: listing.latestPath)
            : (nil, [], [], nil)
        return LogEntry(
            stem: listing.stem,
            slug: listing.slug,
            displayName: listing.displayName,
            path: listing.latestPath,
            summary: summary,
            tags: tags,
            projects: projects,
            frontmatterTime: frontmatterTime,
            stage: listing.nextStage
        )
    }

    /// Reads the entry's Markdown without its YAML frontmatter, ready for presentation.
    func readableBody() throws -> String {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        guard content.hasPrefix("---") else {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let afterOpeningDelimiter = content.dropFirst(3)
        guard let closingDelimiter = afterOpeningDelimiter.range(of: "\n---") else {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return String(afterOpeningDelimiter[closingDelimiter.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parses `summary:`, `tags:`, `projects:`, and `recording_time:` from YAML frontmatter.
    /// Handles both inline (`summary: "text"`) and multiline list (`tags:\n  - item`) forms.
    private static func parseFrontmatter(from path: String) -> (summary: String?, tags: [String], projects: [String], recordingTime: String?) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8),
              content.hasPrefix("---") else { return (nil, [], [], nil) }
        let afterFirst = content.dropFirst(3)
        guard let endRange = afterFirst.range(of: "\n---") else { return (nil, [], [], nil) }
        let yaml = String(afterFirst[..<endRange.lowerBound])

        var summary: String? = nil
        var tags: [String] = []
        var projects: [String] = []
        var recordingTime: String? = nil
        var collectingKey: String? = nil

        for line in yaml.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // List item under current collecting key
            if trimmed.hasPrefix("- "), let key = collectingKey {
                let value = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if key == "tags" { tags.append(value) }
                if key == "projects" { projects.append(value) }
                continue
            }
            // New key: stop collecting
            collectingKey = nil
            if trimmed.hasPrefix("summary:") {
                var value = trimmed.dropFirst(8).trimmingCharacters(in: .whitespaces)
                if value.hasPrefix("\"") && value.hasSuffix("\"") {
                    value = String(value.dropFirst().dropLast())
                }
                summary = value.isEmpty ? nil : value
            } else if trimmed.hasPrefix("tags:") {
                let inline = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
                if inline.isEmpty { collectingKey = "tags" }
            } else if trimmed.hasPrefix("projects:") {
                let inline = trimmed.dropFirst(9).trimmingCharacters(in: .whitespaces)
                if inline.isEmpty { collectingKey = "projects" }
            } else if trimmed.hasPrefix("recording_time:") {
                var value = trimmed.dropFirst(15).trimmingCharacters(in: .whitespaces)
                if value.hasPrefix("\"") && value.hasSuffix("\"") {
                    value = String(value.dropFirst().dropLast())
                }
                recordingTime = value.isEmpty ? nil : value
            }
        }
        return (summary, tags, projects, recordingTime)
    }
}

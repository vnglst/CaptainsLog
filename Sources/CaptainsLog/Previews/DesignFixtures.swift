#if DEBUG
import CaptainsLogCore
import Foundation

/// Deterministic, non-persistent states for inspecting the real SwiftUI view hierarchy.
/// Launch a debug build with `CAPTAINSLOG_UI_FIXTURE=populated`, `empty`, `processing`,
/// `indexing`, `search`, or an `eval-*` state. Fixture mode bypasses the directory watcher,
/// microphone discovery, entry loading, and model download bootstrap. `eval-*` states read
/// entry content from the explicitly configured isolated data directory; the other states are
/// visual examples.
@MainActor
extension AppState {
    public func applyDesignFixture(named name: String) {
        let requestedName = name.lowercased()
        let menuFixtures = [
            "eval-menu": "eval",
            "eval-menu-recording": "eval-recording",
            "eval-menu-processing": "eval-processing",
            "eval-menu-failed": "eval-failed",
        ]
        let fixtureName = menuFixtures[requestedName] ?? requestedName
        if fixtureName != "onboarding" {
            suppressFirstRunForDesignFixture()
        }
        models.modelState = .ready
        processing.stage = .idle
        processing.statusMessage = "Ready to record"
        processing.errorMessage = nil

        switch fixtureName {
        case "onboarding":
            entries = []
        case "eval", "eval-settings":
            entries = Pipeline.listEntries(dataDir: dataDir).map(LogEntry.from)
        case "eval-empty":
            entries = []
        case "eval-processing":
            entries = Pipeline.listEntries(dataDir: dataDir).map(LogEntry.from)
            let pending = entries.filter { $0.stage != .done }
            if let active = pending.first {
                lifecycle.send(.workerStarted)
                lifecycle.send(.processingStarted(active.stem))
                lifecycle.send(.processingProgress(active.stem, .cleaning))
                for entry in pending.dropFirst() { processing.queueProcessing(stem: entry.stem) }
            }
        case "eval-paused", "eval-failed":
            entries = Pipeline.listEntries(dataDir: dataDir).map { listing in
                var entry = LogEntry.from(listing)
                if listing.nextStage != .done {
                    entry.stage = .cleaning
                }
                return entry
            }
            if fixtureName == "eval-failed",
               let failedEntry = entries.first(where: { $0.stage != .done }) {
                processing.recordPreparationFailure(
                    NSError(domain: "EvalUIFixture", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Eval fixture processing error",
                    ]),
                    for: failedEntry.stem
                )
            }
        case "eval-search-results", "eval-search-empty", "eval-search-error",
             "eval-search-preparing", "eval-searching", "eval-indexing":
            entries = Pipeline.listEntries(dataDir: dataDir).map(LogEntry.from)
            let first = entries.first(where: { $0.stage == .done }) ?? entries.first
            let result = first.map {
                SearchResult(
                    stem: $0.stem,
                    slug: $0.slug,
                    displayName: $0.displayName,
                    path: $0.path,
                    excerpt: $0.summary ?? "",
                    distance: 0.12,
                    matchKind: .semantic,
                    matchedTerms: ["side-project"]
                )
            }
            let searchState: SearchViewState
            if fixtureName == "eval-search-error" {
                searchState = .error("Eval fixture search error")
            } else if fixtureName == "eval-indexing" {
                searchState = .indexing(message: "Indexing eval fixtures", completed: 1, total: 2)
            } else if fixtureName == "eval-search-preparing" {
                searchState = .preparingModel
            } else if fixtureName == "eval-searching" {
                searchState = .searching
            } else {
                searchState = .ready
            }
            search.applyFixture(
                query: "side-project",
                results: fixtureName == "eval-search-results" ? result.map { [$0] } ?? [] : [],
                state: searchState
            )
        case "eval-model-downloading":
            entries = Pipeline.listEntries(dataDir: dataDir).map(LogEntry.from)
            models.modelState = .downloading(model: "Whisper eval state", progress: 0.5)
        case "eval-model-error":
            entries = Pipeline.listEntries(dataDir: dataDir).map(LogEntry.from)
            models.modelState = .error("Eval fixture model error")
        case "eval-recording", "eval-recording-paused":
            entries = Pipeline.listEntries(dataDir: dataDir).map(LogEntry.from)
            recording.applyDesignFixture(
                isPaused: fixtureName == "eval-recording-paused",
                duration: 84,
                audioLevel: 0.35
            )
            recording.inputDevices = [AudioDevice(id: 0, name: "Eval fixture microphone", uid: "eval-input")]
            recording.selectedDeviceUID = "eval-input"
        case "empty":
            entries = []
        case "processing":
            entries = Self.fixtureEntries.map { entry in
                var copy = entry
                if copy.stem == "2026-08-30-1028" {
                    copy.stage = .cleaning
                    copy.isActive = true
                }
                return copy
            }
            processing.stage = .cleaning
            processing.statusMessage = "Cleaning Darmok: transporter rescue attempts..."
            processing.processingStem = "2026-08-30-1028"
        case "search":
            entries = Self.fixtureEntries
            search.applyFixture(
                query: "understanding Tamarian stories",
                results: [
                    SearchResult(
                        stem: "2026-08-28-1107",
                        slug: "darmok-words-and-shared-stories",
                        displayName: "Darmok: words and shared stories",
                        path: "",
                        excerpt: "An Enterprise engineer reflects on why translated Tamarian words still needed shared stories.",
                        distance: 0,
                        matchKind: .keyword,
                        matchedTerms: ["Tamarian", "stories"]
                    ),
                    SearchResult(
                        stem: "2026-08-30-1028",
                        slug: "darmok-transporter-rescue-attempts",
                        displayName: "Darmok: transporter rescue attempts",
                        path: "",
                        excerpt: "An engineering log about the scattering field that blocked the rescue at El-Adrel.",
                        distance: 0.19,
                        matchKind: .semantic,
                        matchedTerms: ["Tamarian"]
                    ),
                ]
            )
        case "indexing":
            entries = Self.fixtureEntries
            search.applyFixture(
                query: "Tamarian language",
                results: [],
                state: .indexing(
                    message: "Indexing Darmok engineering logs",
                    completed: 39,
                    total: 68
                )
            )
        default:
            entries = Self.fixtureEntries
        }
    }

    private static var fixtureEntries: [LogEntry] {
        [
            fixture(
                stem: "2026-08-30-1028",
                name: "Darmok: transporter rescue attempts",
                summary: "An Enterprise engineer recalls blocked transporter attempts during the Darmok encounter.",
                tags: ["darmok", "transporters", "engineering"]
            ),
            fixture(
                stem: "2026-08-30-0915",
                name: "Darmok: after the engineering watch",
                summary: "Off duty in Ten Forward, reflecting on Dathon and the cost of understanding.",
                tags: ["language", "reflection"]
            ),
            fixture(
                stem: "2026-08-29-1642",
                name: "Darmok: incident report still in draft",
                summary: "Transporter records are saved; timestamp checks and Geordi’s review remain planned.",
                tags: ["engineering", "report"]
            ),
            fixture(
                stem: "2026-08-28-1107",
                name: "Darmok: words and shared stories",
                summary: "Translating words did not explain the stories behind the Tamarian language.",
                tags: ["language", "stories"]
            ),
        ]
    }

    private static func fixture(
        stem: String,
        name: String,
        summary: String,
        tags: [String]
    ) -> LogEntry {
        LogEntry(
            stem: stem,
            slug: name.lowercased().replacing(" ", with: "-"),
            displayName: name,
            path: "",
            summary: summary,
            tags: tags,
            projects: [],
            frontmatterTime: nil,
            stage: .done
        )
    }
}
#endif

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
        let fixtureName = name.lowercased()
        if fixtureName != "onboarding" {
            suppressFirstRunForDesignFixture()
        } else {
            presentFirstRunForDesignFixture()
        }
        models.modelState = .ready
        processing.stage = .idle
        processing.statusMessage = "Ready to record"
        processing.errorMessage = nil

        switch fixtureName {
        case "onboarding":
            entries = []
        case "eval":
            entries = Pipeline.listEntries(dataDir: dataDir).map(LogEntry.from)
        case "eval-empty":
            entries = []
        case "eval-processing":
            entries = Pipeline.listEntries(dataDir: dataDir).map { listing in
                var entry = LogEntry.from(listing)
                if listing.nextStage != .done {
                    entry.isActive = true
                    entry.stage = .cleaning
                }
                return entry
            }
            processing.stage = .cleaning
            processing.statusMessage = "Cleaning eval fixture"
            processing.processingStem = entries.first(where: { $0.stage != .done })?.stem
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
            processing.statusMessage = "Cleaning Rethinking the processing queue..."
            processing.processingStem = "2026-08-30-1028"
        case "search":
            entries = Self.fixtureEntries
            search.applyFixture(
                query: "making local AI easier to understand",
                results: [
                    SearchResult(
                        stem: "2026-08-28-1107",
                        slug: "research-notes-user-onboarding",
                        displayName: "Research notes: user onboarding",
                        path: "",
                        excerpt: "Observations about communicating local setup and model preparation clearly, without hiding what happens on this Mac.",
                        distance: 0,
                        matchKind: .keyword,
                        matchedTerms: ["local", "setup", "model"]
                    ),
                    SearchResult(
                        stem: "2026-08-30-1028",
                        slug: "rethinking-the-processing-queue",
                        displayName: "Rethinking the processing queue",
                        path: "",
                        excerpt: "A design note on reducing context switching and letting independent work flow through the local pipeline.",
                        distance: 0.19,
                        matchKind: .semantic,
                        matchedTerms: ["local"]
                    ),
                ]
            )
        case "indexing":
            entries = Self.fixtureEntries
            search.applyFixture(
                query: "react vulnerability",
                results: [],
                state: .indexing(
                    message: "Indexing React vulnerability Rabobank demo DLL leasing",
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
                name: "Rethinking the processing queue",
                summary: "A design note on reducing context switching and letting independent work flow through the pipeline.",
                tags: ["product", "process", "ai"]
            ),
            fixture(
                stem: "2026-08-30-0915",
                name: "Morning walk: Dutch and English",
                summary: "Notes on keeping language context explicit during cleanup and enrichment.",
                tags: ["language", "research"]
            ),
            fixture(
                stem: "2026-08-29-1642",
                name: "Weekly team sync takeaways",
                summary: "The decisions, questions, and follow-ups worth carrying into next week.",
                tags: ["team", "planning"]
            ),
            fixture(
                stem: "2026-08-28-1107",
                name: "Research notes: user onboarding",
                summary: "Observations about communicating local setup and model preparation clearly.",
                tags: ["research", "onboarding"]
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

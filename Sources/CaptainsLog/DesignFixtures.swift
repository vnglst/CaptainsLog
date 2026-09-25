#if DEBUG
import CaptainsLogCore
import Foundation

/// Deterministic, non-persistent states for inspecting the real SwiftUI view hierarchy.
///
/// Launch a debug build with `CAPTAINSLOG_UI_FIXTURE=populated`, `empty`, `processing`,
/// `indexing`, or `search`. Fixture mode bypasses the directory watcher, microphone discovery,
/// entry loading, and model download bootstrap. It never reads or writes user data.
@MainActor
extension AppState {
    public func applyDesignFixture(named name: String) {
        suppressFirstRunForDesignFixture()
        models.modelState = .ready
        processing.stage = .idle
        processing.statusMessage = "Ready to record"
        processing.errorMessage = nil

        switch name.lowercased() {
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

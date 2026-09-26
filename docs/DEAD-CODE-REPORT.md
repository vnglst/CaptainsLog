# Dead and Legacy Code Review

**Reviewed:** 2026-09-26  
**Scope:** Source references and product entry points; no code removed.

This report records candidates for follow-up, not an instruction to delete. Verify build products, previews, debug flags, and external consumers before removing public symbols.

| Candidate | Evidence | Status / next check |
|---|---|---|
| Legacy LCARS app UI in `Sources/CaptainsLog/ContentView.swift` and `Sources/CaptainsLog/FirstRunView.swift` | `Sources/CaptainsLogApp/AppMain.swift` constructs `FieldNotesContentView` as its only window root. Repository-wide Swift references show `ContentView` only at its declaration; `FirstRunView` is referenced only from that legacy view. Production UI uses `FieldNotesOnboardingView` in `FieldNotesContentView.swift`. | Strongly appears unreachable from current app entry point. Confirm no downstream package clients instantiate the public `ContentView` before deciding whether to remove or archive it. It may still serve as a visual design reference. |
| LCARS design components in `Sources/CaptainsLog/Theme.swift` and `LCARSKit.swift` | The LCARS controls are used by the old `ContentView` tree; no use was found from current `AppMain`/Field Notes UI. `FieldNotesTheme.swift` provides the active design system. | Likely coupled to the legacy view candidate. Remove only as one reviewed change after verifying public API and resource dependencies. |
| `Sources/CaptainsLog/DesignFixtures.swift` and `CAPTAINSLOG_UI_FIXTURE` | `AppMain` reads the environment value in debug builds and applies fixture state in a `.task`; fixture implementation exists under `#if DEBUG`. | Not dead. It is a useful UI verification seam. The debug fixture set includes eval-backed display states for empty, processing, paused, failed, search result/empty/error/preparing/searching/indexing, model downloading/error, and recording/paused dock displays. These inject presentation state and are not backend inference tests. |
| `Sources/CaptainsLogApp/DemoMode.swift` | Called from debug app initialization when `CAPTAINS_LOG_CONFIG_PATH` is absent; copies repository `demo/` data to `tmp/demo-runtime`. | Active safe-demo behavior, but must be bypassed by tests with explicit isolated config. Not dead. |
| `Sources/CaptainsLog/ContentView.swift` public `EntryRow`, `MicSelectorView`, `DeleteConfirmationView`, `ModelStatusView` | These are referenced by the legacy view tree; no use from the active Field Notes screen was found. | Same public API/downstream-client caveat as legacy UI. Candidate for removal only after package API decision. |
| `Sources/CSQLiteVec/include/sqlite-vec.h` `// TODO rm` | Header itself remains part of the C target public headers and is included by vendored `sqlite-vec.c`/module configuration. | Do not remove based on comment alone. Determine whether it's upstream vendored cleanup or required include, then update in a separate dependency maintenance task. |

No other project-owned symbols were declared dead from this read-only source scan. Unreferenced appearance is not sufficient proof where SwiftPM products expose public APIs or code is activated by environment flags. No personal data or recordings were read.

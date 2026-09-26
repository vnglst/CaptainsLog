# Native UI Coverage Report

**Run date:** 2026-09-26  
**Build:** SwiftPM debug build, `swift build --product CaptainsLogApp` passed  
**Host:** macOS 26; no Xcode IDE  
**Fixtures:** isolated temporary config/data populated only from `eval/`; no `demo/` or user data used.

## Reproduction

Run `bash scripts/test-ui.sh [fixture-state]`. It packages the debug executable into a uniquely identified temporary `.app`, writes a temp config/data tree seeded from repository `eval/` fixtures, and launches with explicit `CAPTAINS_LOG_CONFIG_PATH` and `CAPTAINSLOG_UI_FIXTURE`. Set `CAPTAINSLOG_UI_SKIP_BUILD=1` to reuse the current `.build/debug` product for successive display states. The fixture startup skips watcher, microphone discovery, model download and pipeline bootstrap. Controls are still real. Do not activate Process pending, retry/resume/reprocess, or start/pause/stop recording in UI checks; those actions invoke real inference or audio hardware.

The script prints the isolated app, config, data directory and unique bundle identifier. Close the app before removing only its printed temporary root. Never point this harness at a real data directory. Fixture mode selects presentation states; it does not claim backend model or audio behavior.

## Native accessibility checks

| Surface/state | Result | Observed behavior / limit |
|---|---|---|
| Populated Logs list | Pass | Three eval-backed entries appear grouped by date with summaries, tags, processed/paused status and waiting count. |
| Empty Logs | Pass | Empty-state copy and idle record dock appear with zero entries. |
| Detail and back navigation | Pass | Selecting completed row opens the eval-backed Markdown body, date/time, project and tags; All entries returns to list. |
| Search results / result selection | Pass | Eval result row renders and selecting it opens its linked completed note. Checks render/navigation, not semantic relevance. |
| Search no-results | Pass | “No matching logs” state with query and clear-search control appears. |
| Search preparation, searching, indexing | Pass | Each state renders its progress copy and busy indicator (`Preparing smart search`, `Following the signal`, `Indexing logs · 1 of 2`). No embedding model was loaded. |
| Search error and retry | Pass for injected state | Error text and Try again render. Safe retry remained in fixture state because the debug fixture branch returns before embedding work. |
| Queue processing / paused | Pass for render | Active row and Pause control render; paused row shows paused label and waiting count. No queue action was activated. |
| Queue failed | Pass after rebuild | Failed row displays `ERROR`, `Needs attention`, and the injected “Eval fixture processing error”. Retry was not activated. |
| Settings / editors | Pass | Storage path, personal context and corrections editors, audio input refresh, model status, version and notices render. Context/correction edits were saved only under temp data. |
| Storage folder picker | Pass for initial path/cancel | Native panel opened with configured temp `data/` as current folder, showing only its temp `context` and `logs` children. Cancel returned to Settings. Folder selection/persistence is not verified. |
| Third-party notices | Pass | Notice content and source links render; Done returns to Settings. External destinations were not opened. |
| Delete confirmation | Pass | Confirmation text explains that all files for the selected eval stem move to Trash; Cancel was verified in the earlier run. |
| Delete confirmation and disappearance | Pass | Confirmed deletion of the disposable eval-only pending entry. Logs count changed from 3 to 2 and the row disappeared. |
| Model status | Pass for display | Ready, downloading (“Preparing local models”), and error (“Local models need attention”) status displays were inspected. No model download/load was run by the UI harness. |
| Recording dock | Pass for display | Idle (Ready to record/no device), active recording (01:24, eval device), and paused recording (01:24) rendered. Recording fixtures inject display state only; no audio device was opened and no recording action was performed. |
| Onboarding | Pass for display and dismissal | Isolated onboarding sheet displayed temp storage path and setup steps. Set up dismissed it to empty Logs. `CAPTAINSLOG_DEMO_MODE=1` prevented modifying global first-run preference; persistence is separately asserted by deterministic test. |

The native app was inspected through macOS accessibility, not screenshot/image comparison. Fixed window layout and scrolling are exposed in scroll areas but were not measured at alternate sizes; exact visual geometry remains a manual check. Finder reveal, changing to another folder, external links, hardware capture, actual model download, and live semantic search remain outside this native run.

## Visible control ledger

| Control | Coverage evidence | Remaining check |
|---|---|---|
| Logs / Settings navigation | Native Settings and Logs navigation exercised; empty/populated/detail views inspected. | No alternate window-size visual comparison. |
| Search field, clear, retry, result selection | Deterministic search manager debounce/invalidation/retry/clear tests; native injected results, no-results, error and progress states; result selection opened detail. | Live query-to-embedding relevance reviewed only via separate eval report, with full query ranking still an opt-in check. |
| Start / pause / resume / stop recording | Fake recorder tests cover pause/resume/stop; idle/recording/paused controls rendered through fixture injection. | Actual permission, device selection and audio capture require manual hardware check. |
| Pending row Resume / Retry; active queue Pause | Injected coordinator and AppState workflow tests cover resume, queue and pause; active/paused/failed rows rendered. | The native inference-triggering actions were intentionally not activated. |
| Completed row Reprocess | Pipeline reprocessing tests cover derived-file behavior and source audio preservation. | Native action was not activated because it starts inference. |
| Row/detail Reveal in Finder | Control is present in UI. | Not activated; Finder integration is OS-bound. |
| Move to Trash | Native cancel and confirm tested on eval-only disposable entry; deterministic deletion test checks all artifact paths and row removal. | Trash-provider failure/missing-file UI cases remain. |
| Choose folder / Reveal in Finder | Fake picker test changes folders, verifies config persistence, confirms demo mode suppresses the picker, and passes nil for a missing configured folder; native picker opens in configured temp directory and cancel returns. | Finder reveal remains untested. |
| Context / correction editors | Native temp-only edits saved; config round-trip and prompt-loader tests run. | Relaunch and full UI-to-prompt integration remains untested. |
| Refresh devices / device menu | Refresh control and disabled no-device state observed; fixture device menu renders eval device in recording display state. | Real device enumeration/selection remains hardware-bound. |
| Onboarding Choose folder / Set up | Sheet and temp path observed; Set up dismisses to Logs; deterministic test asserts saved launch choice. | Selecting a different folder through onboarding remains OS-bound. |
| Third-party notices / Done | Notice sheet opened, content inspected, Done returned to Settings. | External source links were not opened. |

## Deterministic and evaluation gates

The native accessibility checks above were performed with the then-current 115-test runner. The current deterministic suite reports **184/184 passed** (`swift run run-tests`), with **132/132 lightweight unit tests**. The latest `bash scripts/test-coverage.sh` run passed its CLI checks and reported **31.58% all-source line coverage** (37.86% functions, 41.82% regions) and **82.16% deterministic-production line coverage** against the 80% floor; JSON is at `.build/coverage/coverage.json`. Native UI fixtures have not been rerun after the latest testable action-state extraction; the macOS interaction matrix above remains the most recent native run.

The opt-in inference-backed pipeline and semantic eval results are separate. Review the eval runner’s report for fixture, command, model, prompt/config, generated artifacts and concrete semantic changes before calling model quality covered. UI fixture rendering is not a substitute for that review.

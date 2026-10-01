# ADR-007: Use Framework-Free Test Runner and LLVM Coverage

**Status**: Accepted  
**Date**: 2026-07-10

## Context

CaptainsLog must build and test with Apple Command Line Tools; a full Xcode installation is not required. The available toolchain does not provide XCTest or the Swift Testing module, so `swift test` cannot host the project’s tests.

## Decision

Keep `run-tests` as the framework-free test executable. It exits non-zero on failures and contains deterministic tests that use temporary directories instead of audio hardware or model inference.

Use `scripts/test-coverage.sh` to compile the runner and CLI with LLVM coverage instrumentation, execute deterministic CLI smoke/validation cases, and write the full-production JSON report to `.build/coverage/coverage.json`. The script reports total production coverage and enforces an 80% line-coverage floor over deterministic production logic.

The 80% floor is a project-chosen regression threshold, not a Swift, GitHub, or industry-mandated number. It sets a substantial minimum for the deterministic code that the lightweight, model-free suite can exercise, while keeping declarative UI and direct hardware/native-inference adapters visible in the aggregate report without making their platform prerequisites part of this gate. The percentage is a guardrail rather than a quality score; behavior assertions and the separate semantic evaluation review remain necessary. Raise the floor only after repeated stable coverage runs, not by excluding ordinary logic.

UI decisions, CLI workflows, recorder lifecycle operations, and core recovery paths have framework-free behavioral tests. Declarative SwiftUI rendering and design fixtures, real audio hardware, and direct native model-inference adapters remain separate integration concerns rather than requirements of the deterministic gate. Their files remain visible in the all-source report, while excluded from the 80% deterministic-production metric. App state, model orchestration, CLI and filesystem workflows, search, pure audio-level calculations, and pipeline logic remain inside the enforced scope.

## Consequences

- Tests and coverage run without Xcode, XCTest, or a testing-package dependency.
- The report excludes third-party dependencies and test-runner code.
- Audio, model-download, and pipeline-inference boundaries are injected in tests, so the deterministic gate does not require hardware, network access, or model loading.
- The runner remains responsible for test discovery, reporting, and failure handling.
- Model-quality evaluations in `eval/` remain a separate release gate.
- Raise the enforced floor only after stable behavioral coverage improvements; ordinary business logic must not be excluded merely to improve the percentage.

## Verification

```sh
swift run run-tests
bash scripts/test-coverage.sh
```

## Test gates and isolation

GitHub Actions runs `swift run run-tests --unit`. The full local runner also includes workflow, search-index, coordinator, and pipeline-orchestration groups. Tests cover config migration/recovery, prompt construction, parsing, onboarding persistence, Logs/detail/deletion, recording and queue policies, settings reload, search cancellation/retry, and CLI success/failure paths. Injected recorder operations cover device fallback, tap installation, RMS levels, pause gating, start/write failures, and resource release. Pipeline tests inspect source preservation, fresh audio imports, unsafe slugs, every resume stage, missing artifacts, cancellation, and retry recovery.

Set `CAPTAINS_LOG_CONFIG_PATH` to a temporary config with a temporary `dataDir`, seeded only from repository `eval/` fixtures. Tests must bypass the default demo runtime; hard-coded design examples and `demo/` are presentation material, not evaluation inputs. Never access personal recordings or notes.

| Gate | Command / evidence | Limits |
|---|---|---|
| Deterministic behavior | `swift run run-tests`; CI uses `--unit` | Fakes assert state and files, not native inference or capture. |
| Coverage and CLI validation | `bash scripts/test-coverage.sh` | Help/arguments, config persistence, six list stages and prompt rendering; JSON at `.build/coverage/coverage.json`. |
| Fixture pipeline | `bash scripts/run-evals.sh --pipeline` | Stage artifacts, category/filename assertions, completed-resume immutability, search indexing/readback; semantic review remains separate. |
| Stage evaluations | `bash scripts/run-evals.sh --suites`; `--categorize` for the four category cases | Use the stage skills; run inference sequentially and review omissions, additions, hallucinations and ranking. |
| Saved-output validation | `bash scripts/run-evals.sh --validate-run <run-stamp>` | Checks structure without inference; cannot establish semantic quality. |
| Native UI | `bash scripts/test-ui.sh eval` or a fixture-state selector | Temporary app/config/data, presentation state injection; does not validate models or recording. |
| Installed models | `bash scripts/test-model-smoke.sh` | Prepared machine with the four `CAPTAINSLOG_*_MODEL_*` variables; opt-in, outside CI. |
| Microphone hardware | `bash scripts/test-recorder-hardware.sh` | Separately confirmed interactive capture; outside automated suites and CI. |

The UI harness prints its isolated paths and bundle identifier. Close the app before removing its temporary root. `CAPTAINSLOG_UI_SKIP_BUILD=1` reuses the debug build. Fixture startup skips watcher, microphone discovery, downloads and pipeline bootstrap, but controls remain real: do not activate processing/retry/reprocess or recording controls during presentation checks. Safe fixture search retry returns before embedding work.

## Dated verification evidence

These are historical observations, not claims about the current checkout. Model quality requires human review. Auto-update verification and its later environment failures are recorded in [the update ADR](ADR-011-homebrew-auto-updates.md#verification-record-2026-10-01).

### Deterministic baseline: 2026-09-26

The full runner passed 184/184 and the lightweight runner passed 132/132. Coverage was 31.58% all-source lines (37.86% functions, 41.82% regions) and 82.16% deterministic-production lines against the 80% floor. Build and CLI coverage checks passed with SwiftPM and Command Line Tools.

### Model evaluations: 2026-09-26

Runs used isolated config/data and repository fixtures, with local Whisper Large-v2 and Qwen 3.5 9B Q4_K_M. Stage run `2026-09-26_08-14-47_73402` produced 19 reviewed outputs after one enrichment retry; category run `2026-09-26_12-43-30_17566` added four manifests. The runner now validates 23 outputs when all suites are included. Generated artifacts and per-case reports live in ignored `eval/*/generated/` and `eval/*/reports/`.

**Transcription quality failed.** All four fixtures were compared against expected text:

| Fixture | Semantic changes |
|---|---|
| `2025-01-14 side project` | `foldertje` became `vollendje`; “Liefst een lokaal model” became “Een liefdelokaal model”; “side project” became “science project” and “site project.” The topic error propagated into cleanup and summaries. |
| `alle-mensen-zijn-sterfelijk` | “Florences hand in de hare” became “hand in de haren”; “Pff” was dropped; “niets van haar aantrekken” became “niet van haar moeten aantrekken.” |
| `durins-volk` | “Durin de Onsterfelijke” became “durende onsterfelijke,” losing the character identity; “liederen” became “Lideren.” |
| `world-war-z` | “Harley-Davidsons killed more young Chinese” became “Harley-Davidson skilled more young Chinese”; “New” disappeared from “older New Dachang”; “the name to name” and `[BLANK_AUDIO]` were added. |

The word comparison helper was heuristic; its alignment of hyphenated `side-project` was unreliable and was manually checked.

- Cleanup: `book-reference` matched expected while preserving the book, author and conference. `captains-log-nlm-llm` removed repetition but dropped uncertainty (“I'm not really sure how”), retained input-grounded `NLM` rather than expected `LLM`, and retained an extra curiosity sentence. The side-project case repaired malformed “liefdelokaal,” added paragraph breaks, dropped explicit side-project framing, shortened the Star Date example, retained awkward Dutch word order, and preserved the upstream “science project” error.
- Categorization: all four manifests matched their source stem and expected label: mixed-work-dominant/professional-release-planning → `professional`, personal-weekend → `personal`, side-project-voice-app → `side_project`. These clear cases do not establish broad ambiguous-topic robustness.
- Filename: all eight outputs passed date, kebab-case, extension and 3–8-word checks without unrelated topics. Cases 01, 02, 04, 05 and the side-project case matched expected. Case 03 lost the management-versus-staff-engineer contrast; case 06 omitted consumer/refactoring context; case 07 lost the overall planning/improvement framing.
- Enrichment: work-week metadata matched and the summary added grounded GenAI/transcription details; personal-only missed `beach`/`food` and added broader grounded `dining`; mixed-topics matched. The side-project rerun matched metadata lists but omitted iCloud synchronization from its summary.
- Runner failure: the initial side-project enrichment artifact was empty despite a save message. The shell runner was edited during execution and later failed with `25-01-15: command not found`; the empty artifact's cause was not isolated. A sequential rerun with the same input/date/time wrote 3,491 bytes of valid YAML/body and replaced the canonical generated artifact. Saved-output validation then passed 19/19. Do not edit a running evaluation script.

Repeated full-pipeline runs produced `side_project` and `2025-01-14-side-project-star-trek-voice-log`, wrote all stage artifacts, left eight files unchanged on completed resume, and found the enriched entry through search (two indexed chunks). The latest recorded run, `2026-09-26_17-06-38_91326`, passed those assertions but retained “science project” after cleanup. Summaries varied in whether they retained iCloud synchronization and original-audio details; tags varied between expected `side-projects`/`audio` and `side-project`/`audio-processing`, with occasional omitted `artificial-intelligence` and added grounded `apple` or `cloud-storage`. Structural success did not override transcription quality failure. Pipeline recording time was `18:58` versus the direct enrichment fixture's fixed `12:00`; pipeline time derives from copied-file creation metadata and is environment-dependent.

### Native UI: 2026-09-26

A SwiftPM debug app on macOS 26 was inspected through accessibility with isolated eval-backed fixtures. The native run used the then-current 115-test runner and was not repeated after later action-state extraction. It was not screenshot comparison or a measurement of layout geometry.

| Surface | Observed result / boundary |
|---|---|
| Logs and detail | Empty/populated/grouped rows, processed/paused states, detail open/back and linked search-result navigation passed. |
| Search | Results, no-results/clear, error/safe retry, preparing/searching/indexing displays passed without loading embeddings. |
| Queue | Processing/pause, paused and failed/error states rendered; queue actions were not activated. |
| Settings | Storage, context/corrections editors, audio refresh, model status, version and notices rendered; edits saved only to temp data. |
| Folder picker | Opened at configured temp data path; cancel returned to Settings. Selecting/persisting another folder was not tested natively. |
| Notices | Open/render/Done passed; external links were not opened. |
| Deletion | Cancel and confirm passed on disposable eval copies; count changed from three to two and the row disappeared. |
| Models and recording | Ready/downloading/error and idle/recording/paused/no-device displays passed; no download, model load or audio capture occurred. |
| Onboarding | Temp path/setup rendered; Set up dismissed to empty Logs. Demo mode suppressed global first-run preference mutation; deterministic tests separately cover persistence. |

### Legacy code review: 2026-09-26

The source-reference review removed no code. `AppMain` constructs `FieldNotesContentView`; legacy `ContentView`/`FirstRunView`, LCARS controls in `Theme.swift`/`LCARSKit.swift`, and public legacy `EntryRow`, `MicSelectorView`, `DeleteConfirmationView`, and `ModelStatusView` appeared unused by that entry point. Verify downstream SwiftPM clients, previews and resource dependencies before removal; public symbols are candidates, not confirmed dead code.

`DesignFixtures.swift`/`CAPTAINSLOG_UI_FIXTURE` and `DemoMode.swift` are active debug seams. Tests must bypass default demo seeding with an explicit isolated config. The vendored `sqlite-vec.h` remains a required public/include surface; its `TODO rm` comment alone is not evidence for deletion.

## Remaining acceptance work

- Repair meaning-changing transcription errors and rerun transcription and full-pipeline semantic review.
- Run real microphone and installed-model smoke checks on a prepared machine.
- Review all queries in `eval/search/queries.json` for expected hits, ranking, false positives and useful excerpts; see [search fixtures](../eval/search/README.md).
- Check alternate window sizes, layout stability, keyboard/VoiceOver and reduced-motion behavior.
- Verify Finder reveal, external notice links, native folder selection/persistence and onboarding folder validation.
- Check context/correction persistence after native relaunch and the full UI-to-prompt path.
- Exercise native Trash failure/missing-file behavior and remaining command filesystem failures. Deterministic deletion keeps a failed entry visible; no dedicated native Trash-error alert was verified.
- Validate live inference-triggering UI actions outside the presentation harness and complete clean-machine packaged-app QA.

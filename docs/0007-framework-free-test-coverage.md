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

GitHub Actions runs `swift run run-tests` only for release tags; branch pushes and pull requests do not run CI. The full runner also includes workflow, search-index, coordinator, and pipeline-orchestration groups. Tests cover config migration/recovery, prompt construction, parsing, onboarding persistence, Logs/detail/deletion, recording and queue policies, settings reload, search cancellation/retry, and CLI success/failure paths. Injected recorder operations cover device fallback, tap installation, RMS levels, pause gating, start/write failures, and resource release. Pipeline tests inspect source preservation, fresh audio imports, unsafe slugs, every resume stage, missing artifacts, cancellation, and retry recovery.

Set `CAPTAINS_LOG_CONFIG_PATH` to a temporary config with a temporary `dataDir`, seeded only from repository `eval/` fixtures. Tests must bypass the default demo runtime; hard-coded design examples and `demo/` are presentation material, not evaluation inputs. Never access personal recordings or notes.

| Gate | Command / evidence | Limits |
|---|---|---|
| Deterministic behavior | `swift run run-tests`; CI runs only for releases | Fakes assert state and files, not native inference or capture. |
| Coverage and CLI validation | `bash scripts/test-coverage.sh` | Help/arguments, config persistence, six list stages and prompt rendering; JSON at `.build/coverage/coverage.json`. |
| Fixture pipeline | `bash scripts/run-evals.sh --pipeline` | Stage artifacts, category/filename assertions, completed-resume immutability, search indexing/readback; semantic review remains separate. |
| Stage evaluations | `bash scripts/run-evals.sh --suites`; `--categorize` for the four category cases | Use the stage skills; run inference sequentially and review omissions, additions, hallucinations and ranking. |
| Saved-output validation | `bash scripts/run-evals.sh --validate-run <run-stamp>` | Checks structure without inference; cannot establish semantic quality. |
| Native UI | `bash scripts/test-ui.sh eval` or a fixture-state selector | Temporary app/config/data, presentation state injection; does not validate models or recording. |
| Installed models | `bash scripts/test-model-smoke.sh` | Prepared machine with the four `CAPTAINSLOG_*_MODEL_*` variables; opt-in, outside CI. |
| Microphone hardware | `bash scripts/test-recorder-hardware.sh` | Separately confirmed interactive capture; outside automated suites and CI. |

The UI harness prints its isolated paths and bundle identifier. Close the app before removing its temporary root. `CAPTAINSLOG_UI_SKIP_BUILD=1` reuses the debug build. Fixture startup skips watcher, microphone discovery, downloads and pipeline bootstrap, but controls remain real: do not activate processing/retry/reprocess or recording controls during presentation checks. Safe fixture search retry returns before embedding work.

## Dated verification evidence

These are historical observations, not claims about the current checkout. Model quality requires human review. Auto-update verification and its later environment failures are recorded in [the update ADR](0012-homebrew-auto-updates.md#verification-record-2026-10-01).

### Synthetic fixture privacy correction: 2026-10-08

The owner rejected the first attempted regression fixture because it retained names and subject matter relatable to the private presentation. Independently rewriting the prose did not make that fixture sufficiently synthetic. It and its expected output were removed, together with related generated candidates, outputs, reports and retained native traces. Its observed pre-fix failure and fixed success do not establish regression coverage for a replacement. The existing seeded CLI controls, structural validator and deterministic generation-boundary tests remain useful independently of the rejected fixture.

The replacement at `eval/enrich/input/04_moonmoth_festival.md` is a newly written diary about an imaginary lantern festival, with invented characters, places and creatures. It uses no presentation outline, names, subject matter, token-position calibration or source-length matching. Its date and time are arbitrary evaluation inputs. Native baseline and fixed-output results must be recorded separately; no reproduction claim transfers from the rejected input. TASK-44 has returned to Next pending that evidence.

Historical code completed the unrelated 871-word replacement with EOG under seeds 42 and 0, emitting 211 and 227 tokens respectively. Both were fresh uncapped runs with llama.cpp 0.5.0/GGML 0.25.3, a 2,885-token prompt and 5,888-token context. Therefore it is an additional evaluation case, not a demonstrated native context-exhaustion reproducer. Logs are isolated under `tmp/enrich-fictional-replacement-2026-10-08/`. The earlier failure claim has been withdrawn for the replacement; TASK-44 remains open for independent native reproduction.

The fixed CLI completed the replacement in 208 tokens (2,938 prompt; 7,168 context; 4,096 output budget). All five enrichment cases passed structural generation and saved-run checks, prefix `2026-10-08_10-53-26_63479_Qwen3.5-9B-Q4_K_M`. Build, 25 validator checks and six seed boundaries passed; no production code changed, so the deterministic runner and audio pipeline were not repeated for this fixture-only correction. Field-by-field reports record semantic limits: festival output hallucinates Whisper, overincludes common creature/object types, omits moonmoths/puppetry/wayfinding tags and some summary details. Work still omits documentation; personal omits beach/food and adds grounded dining; mixed matches; Dutch retains all lists but omits structured storage, original audio and cross-computer synchronization from its summary. Expected references were not adjusted to match these errors.

The earlier complete audio-fixture pipeline passed transcription, cleanup, classification, filename generation, enrichment, completed-resume immutability and search readback. Those checks used the existing repository audio fixture and remain valid. The original workspace transcript and all private reproduction material remain deleted. The rejected fixture still exists in the prior Git commit; deleting the working-tree fixture does not rewrite repository history.

### Enrichment entity-list loop reproduction and fix: 2026-10-07

The owner supplied a Markdown copy in the workspace for this reproduction and explicitly prohibited access to original personal data folders or speaker context. That copy was used only with an isolated config/data directory at `tmp/enrich-exhaustion-2026-10-07`. The supplied text, generated metadata and diagnostic traces remain untracked/ignored; none is an evaluation fixture committed to the repository. Only installed model files were reused. All native inference ran sequentially, without concurrent compilation.

The installed, unchanged CLI failed on the supplied copy: **9,254 prompt tokens + 9,434 output tokens exhausted the allocated 18,688-token context**. It exited nonzero and wrote no output file. This reproduces the screenshot's failure class; the cause of the 122-token prompt difference from the screenshot is unverified. An additional instrumented baseline run, seed 42, intentionally stopped after 1,024 generated tokens. Its prefix contained **139 identical entity-list items** and never reached the summary. This diagnostic stop was not a second context-exhaustion result. Temporary tracing, seed and stop controls were removed before production builds.

The fix enables llama.cpp DRY sequence repetition protection only for enrichment: multiplier 0.8, base 1.75, allowed sequence length 4, last 512 tokens, no sequence breakers. Keeping newlines in the history detects list-item repetitions across lines while allowing short YAML syntax to recur. `llama_sampler_sample` already accepts its sampled token; the redundant explicit acceptance was removed so stateful samplers see each token once. Other stages retain their sampling settings. The initial trial used a 2,048-token output budget; owner review increased the final budget to **4,096** for metadata headroom. This bounds only generated metadata; the unchanged transcript is appended afterwards. Explicit output caps throw on unfinished generation rather than returning partial text; an EOG token immediately after the cap/context boundary is accepted without decoding past capacity. No automatic retry was added. The prompt clarifies professional work classification and unique names across metadata fields.

Two native runs with the fixed sampler and initial budget completed the supplied input instead of exhausting context. The final prompt run emitted valid YAML, string-only lists, the supplied date/time and the exact original body. Its work category and three-sentence summary are grounded in the source. Extraction remains imperfect: the entities list contains two repetitions of a project already listed under projects, and two organizations used as illustrative examples are omitted. These finite metadata-quality limits remain for owner judgment; the fix does not guarantee unique or exhaustive extraction.

All four repository enrichment fixtures completed with the final prompt and sampler. YAML parsing, string-only metadata lists and exact body preservation passed. Generated outputs and field-by-field reports have prefix `2026-10-07_16-52-00_Qwen3.5-9B-Q4_K_M` under `eval/enrich/generated/` and `eval/enrich/reports/`. Manual review against the inputs and expected files found:

- Work week: expected categories, people, projects, companies, entities and summary themes are retained; documentation is omitted from tags.
- Personal: expected named people and beach/running/reading/dinner narrative are retained; beach is omitted from tags and grounded dining replaces food.
- Mixed topics: all expected lists and summary themes match.
- Dutch side project: the named fictional person is correctly classified as a person, and expected entities including iCloud are retained. Audio-processing replaces audio, organization is added from the folder design, and side-projects is omitted from tags. The summary collapses raw transcript and polished narrative into a coherent transcript and omits explicit cross-computer synchronization. The date still follows the spoken date, 2025-01-14, instead of the command's supplied 2025-01-15; recording time is preserved. This pre-existing date issue remains.

`swift build` passed, the unit runner passed **154/154**, and the full deterministic runner passed **209/209**. Regression coverage includes the original and newly reproduced exhaustion counts, strict explicit-budget rejection, successful normal termination, and EOG immediately after the output/context boundary. Native checks required outside-sandbox Metal access; a sandboxed attempt failed to create the llama context before inference. The installed app has not been replaced by these source/CLI checks.

The full audio fixture command, `bash scripts/run-evals.sh --pipeline`, rebuilt the CLI but aborted with exit 134 during transcription: `MPSGraphTensorData.mm` asserted `shape.count = 0 != strides.count = 4`. It never reached enrichment. This is recorded separately in [DRAFT-1](../backlog/drafts/draft-1%20-%20Investigate-Whisper-Metal-assertion-during-fixture-transcription.md); transcription was not changed in TASK-41. The full audio gate therefore did **not** pass.

To verify integration beyond that failure, the expected transcript from `eval/transcribe/expected/2025-01-14 side project.md` was copied into the isolated run's transcribed stage, then `cl resume` continued from cleanup. Cleanup, categorization, filename generation and enrichment completed with one reused Qwen container. Category was `side_project`; the filename was `2025-01-14-side-project-star-trek-voice-log.md`. Enriched YAML parsed, retained the cleaned body exactly and matched expected category, tags, person, empty project/company lists and entities. The summary retained local Whisper/LLM processing and iCloud transcript/processed-text storage, but did not explicitly mention keeping the original audio. Recording time was file-derived `18:58`. Completed resume left all artifact hashes unchanged; search indexing/readback returned the enriched entry. This transcript-seeded continuation does not establish working audio transcription.

After owner review raised the final metadata budget to **4,096**, the CLI was rebuilt and the unit runner again passed **154/154**. A third supplied-input run completed with valid YAML, string-only lists, supplied date/time and exact body preservation. Its work category and summary are grounded; extraction still duplicates the project identifier and omits the illustrative companies, and this run adds an inferred organization label rather than an explicitly named organization. These limits are not corrected by enlarging the budget.

All four enrichment fixtures were rerun sequentially at 4,096 tokens. YAML, string-only lists, completion and exact bodies passed; reports and outputs use prefix `2026-10-07_17-02-38_Qwen3.5-9B-Q4_K_M`. Work again omits documentation; personal now omits both beach and food without adding another tag; mixed matches all expected lists and summary. Dutch now matches all expected lists including tags and the person classification. Its summary retains original-audio/output storage but omits explicit iCloud synchronization and the separate raw/polished-text distinction; its spoken-date override remains. The shared-model continuation and full deterministic suite above used the initial 2,048-token budget; they were not repeated for this constant-only increase. No transcription code or installed app was changed.

### Enrichment exhaustion investigation: 2026-10-05

[Task-41](../backlog/tasks/task-41%20-%20Reproduce-and-fix-enrichment-generation-exhaustion.md) remains in Next. The owner confirmed that enrichment failed with a 9,376-token prompt and 9,568 generated tokens filling an 18,944-token allocation. The following native CLI attempts **did not reproduce exhaustion**; no production fix was selected or applied.

All inference ran sequentially with an isolated config/data root at `tmp/enrich-exhaustion-2026-10-05`, the configured Qwen3.5-9B Q4_K_M model file, the unchanged enrichment prompt and temperature 0.3. Inputs were derived only from repository fixtures. Temporary fixture-only token tracing and fixed sampling seeds were removed after the investigation. These seeds were local instrumentation, not retained CLI options.

| Synthetic input | Construction | Seed | Prompt / allocated tokens | Outcome |
|---|---|---|---|---|
| Mixed topics, 22,228 bytes | `03_mixed_topics.md` repeated 30 times | Default random | Not captured | Completed |
| Dutch side project, 21,118 bytes | Dutch enrichment input repeated 8 times | 42 | 6,955 / 14,080 | Completed |
| Dutch side project, 31,678 bytes | Dutch enrichment input repeated 12 times | 1 and 7, separate runs | 9,503 / 19,200 in each | Both completed |
| Mixed languages and technical topics, 43,382 bytes | Dutch, work-week, mixed-topics, filename technical-deep-dive and cleanup NLM/LLM fixtures concatenated in that order, repeated 8 times | 42 | 11,667 / 23,552 | Completed |
| Work week, 34,198 bytes | `01_work_week.md` repeated 50 times | 42 | 8,659 / 17,408 | Completed |

Repetitions joined the original fixture text with two newlines; mixed-language source pieces were trimmed before joining. Each standalone command was `cl enrich --input <synthetic-input> --output <temporary-output> --date 2025-01-15 --recording-time 12:00`, with `CAPTAINS_LOG_CONFIG_PATH` pointing to the isolated config. All six long-input runs emitted parseable YAML with string-only metadata lists and preserved the source body exactly. Their frontmatter was 564–859 bytes. The near-size cases establish that a roughly 9,400-token prompt can finish with this allocation, not that the reported failure is resolved.

All four standard enrichment fixtures also completed under seed 7. Their YAML parsed, list values were strings, and bodies were preserved exactly. Reports and generated artifacts have prefix `2026-10-05_20-09-17_Qwen3.5-9B-Q4_K_M` in `eval/enrich/reports/` and `eval/enrich/generated/`. The work-week metadata matched expected lists and themes. Personal metadata omitted beach and used grounded dining in place of food; its named people and summary matched. Mixed topics matched expected lists and themes. The standard Dutch case put Captain Jean-Luc Picard in entities rather than persons, retained the original audio/transcript/corrected-text output structure, and omitted explicit cross-computer synchronization. Dutch runs often returned the date spoken in the text (2025-01-14) instead of the supplied date (2025-01-15). These are quality findings, not fixes included in this task.

The combined long mixed-language case omitted the work and personal categories, named people, organizations and most technical entities from those portions, focusing on the Dutch side-project narrative. The long work-week case omitted the documentation tag and GenAI entity. Neither omitted-content behavior reproduced runaway output; enlarging context alone is not supported as a solution by these attempts.

The installed app's bundled enrichment prompt SHA-256 matched the repository prompt. Installed and Homebrew libllama, libggml and libggml-base Mach-O UUIDs matched (Homebrew llama.cpp 0.5.0). An eleventh enrichment attempt used `/Applications/CaptainsLog.app/Contents/MacOS/cl resume 2025-01-15-1200 --data-dir <isolated-reuse-pipeline>` with transcript and cleaned artifacts seeded from the 12-repeat Dutch input. Categorization, filename generation and enrichment shared one loaded Qwen container and completed. Enriched YAML parsed and its body matched the seeded cleaned input exactly; the output again preferred the date spoken in the text. This check started at categorization; it did not exercise transcription or cleanup inference. No personal recording, transcript or speaker context was read.

After removing temporary instrumentation, `swift build` passed and `swift run run-tests --unit` passed 152/152. Final repository changes are investigation evidence, the changelog and the open Backlog task; production source and prompts are unchanged.

### Generation exhaustion and enrichment: 2026-10-02

A user-provided screenshot reported an 8,115-token prompt and 8,269 output tokens as exhausting the model's 262,144-token context. Those counts instead fill the app's 16,384-token allocation. Inference now uses `llama_n_ctx` for available generation capacity and reports the allocated size. The generation loop accepts injected sampling/decoding operations; a deterministic runaway sampler reproduces those counts, verifies partial-output rejection and the actual allocation, and a companion test verifies successful end-of-generation. Run them with `swift run run-tests --unit` (also included in the full runner). After the extraction, `swift build`, the lightweight suite (150/150) and the full suite (204/204) passed.

The enrichment prompt now requests exactly one YAML mapping with each schema key once and instructs the model to stop after the summary. The original model's runaway behavior has not been reproduced: a 20,005-byte temporary input made by repeating `eval/enrich/input/03_mixed_topics.md` completed under both previous and trial settings. An initial long-input check failed with a Metal out-of-memory error during concurrent compilation; retrying with compilation idle succeeded. No personal recording or note was used.

Trials of Qwen's recommended presence penalty, first with its recommended temperature/top-k/top-p and then with existing sampling settings, introduced metadata regressions: the work fixture omitted the side-project category; the Dutch fixture changed the supplied recording time or emitted an unquoted colon as a YAML object in the entities list. Those sampler changes were rejected and are not included in the final implementation.

The isolated full audio pipeline `tmp/evals-2026-10-02_15-01-33_68042-68042` passed stage-artifact, category, completed-resume immutability and search-readback checks. This run predates the generation-loop extraction; the release bundle’s `cl enrich` was subsequently checked using its bundled prompt and `03_mixed_topics.md`, matching all expected metadata and preserving the source body exactly. Ad-hoc signature verification also passed.

The final prompt-only enrichment run `2026-10-02_14-59-01_Qwen3.5-9B-Q4_K_M` generated valid YAML with string-only metadata lists, preserved each supplied recording time, and retained each source body. Per-case reports are under `eval/enrich/reports/`. Work categories, persons, projects, companies and entities matched expected, but the documentation tag was omitted. The personal case omitted beach and food tags; its persons and summary matched. Mixed topics matched all expected lists and summary. The Dutch case kept named entities, iCloud and the proper side-project category; audio became the grounded audio-processing tag. Its summary omitted explicit original-audio retention and cross-computer synchronization, and described rewritten summaries rather than the full narrative. These limits remain subject to human quality judgment.

### Processing status lifecycle: 2026-10-02

The coordinator now consumes ordered pipeline progress before returning success and ignores updates from a cancelled attempt when the same recording is retried. The new retry regression failed against the previous coordinator: the cancelled attempt could clear the active retry or restore an earlier status. With the fix, `swift build` and the full deterministic runner passed (202/202), including an eval-backed pipeline completion/list-status check.

The isolated local-model CLI fixture run `tmp/evals-2026-10-02_13-14-14_52759-52759` completed all stages, detected no pending entries, preserved files on completed resume, and returned the enriched log in search. These structural checks do not establish model-output quality. A temporary eval-backed native UI check on the previous coordinator displayed Transcribing → Enriching → Processed when its state was advanced in order; it did not reproduce the reported recording symptom. Actual microphone capture and the user's recording were not used. The regression establishes the cancelled-retry race; the exact trigger of the original report remains unconfirmed.

### Model storage settings: 2026-10-02

After integrating this feature with the committed pipeline fixes on `main`, `swift build` passed and the combined runner passed 205/207 tests. The two existing updater transport/installation tests failed because the installed CaptainsLog app was running: `AppUpdater.install` checks real `NSRunningApplication` state even when its Homebrew transport is a fixture. All model-storage and pipeline tests passed. The running installed app was left untouched; this run does not establish a clean full-suite pass with that app closed.

`swift build` and the full deterministic runner passed (203/203). New tests cover allocated model bytes, deletion of nested Whisper bundles and the selected GGUF, preservation of unrelated files and model identifiers, protection of an unrelated `config.json` in a wrongly selected folder, deferred downloads before resumed processing, and allowing idle app updates after intentional model deletion. An isolated `cl models` / `--delete whisper` / `--delete qwen` check used copies of `eval/cleanup/input/book-reference.md` as storage fixtures and preserved neighboring files.

The native `eval-settings` harness showed fixed-height model rows, disk usage, disabled deletion for missing models, and a confirmation explaining the next download and internet requirement. Canceling the confirmation preserved the installed search model. Actual installed models were not deleted; network redownload and failure recovery remain covered through injected download operations rather than a destructive native/network check.

After the other worktree's inference finished, `bash scripts/run-evals.sh --pipeline` ran sequentially with isolated config/data in `tmp/evals-2026-10-02_15-09-44_71814-71814`. Stage artifacts, `side_project`, completed-resume immutability, two indexed chunks, and search readback passed. The filename exactly matched `2025-01-14-side-project-star-trek-voice-log.md` (six grounded slug words). YAML frontmatter parsed; category, tags, person, empty projects/companies, and entity sets matched the expected fixture. The summary retained Star Trek, local Whisper/LLM processing and iCloud automation, but did not explicitly distinguish the raw transcript from the polished output. Recording time was file-derived `14:58`, rather than the direct fixture's fixed `12:00`.

Semantic review of raw transcription reproduced the existing errors: `foldertje` → `vollendje`, `Liefst een lokaal model` → `Een liefdelokaal model`, and side-project references becoming `science project` / `site project`. Cleanup repaired the folder and local-model phrases and added five coherent paragraphs, but retained `science project`, flattened the folder diminutive, and kept several spoken sentence-opening connectors. It preserved the iCloud, notification/email, original-audio, raw-transcript and polished-output details without adding new facts. Structural pipeline success does not resolve the existing transcription quality limit; inference prompts were unchanged by this feature.

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

### Script review: 2026-10-01

The 2026-10-01 script review removed `scripts/benchmark-startup.sh` and its
internal debug-only recording hooks. It used an obsolete binary path, read the
personal app config, and started microphone capture automatically. The remaining
scripts support current build, asset-generation, evaluation, or integration
workflows; see the [script index](../scripts/README.md). Real recording checks
remain in the explicitly confirmed `test-recorder-hardware.sh` workflow. A future
startup benchmark needs isolated fixture data and an explicit hardware boundary.

## Remaining acceptance work

Open acceptance items are tracked only in the [backlog](../backlog/tasks/). The dated findings above preserve the evidence and limits that inform those items.

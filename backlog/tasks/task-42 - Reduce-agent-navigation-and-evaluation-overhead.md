---
id: TASK-42
title: Reduce agent navigation and evaluation overhead
status: Complete
assignee:
  - '@codex'
created_date: '2026-10-07 14:38'
updated_date: '2026-10-08 17:11'
labels: []
dependencies: []
type: enhancement
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Agents spend too much time finding source files, discovering evaluation commands and assembling results for review. Stage instructions contain duplicated or stale commands, and focused changes can require running unrelated model evaluations.

Provide one documented entry point for evaluating a stage or a single fixture. Keep the existing full pipeline and release checks. Assemble each case’s input, expected result, generated result and validation into a review bundle, with enough model and configuration information to compare runs. Reuse the loaded text model sequentially while keeping each case’s context separate.

Add a source map, repair misleading navigation and troubleshooting advice, and explain isolated local installation and rollback. Coordinate these targeted documentation corrections with TASK-22, which retains the broader public-documentation review. Use repository fixtures and isolated data throughout. Measure representative elapsed time and effort; do not present estimated savings as proven improvements.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 One documented execution entry point owns isolated fixture runs and output naming; stage skills reference it and retain only review guidance without conflicting recipes.
- [x] #2 One stage or case can be evaluated independently; required full pipeline and suite release gates remain available.
- [x] #3 A compact linked source map identifies active UI/Settings, launcher, coordinator, inference, config, CLI and tests, embedded types and legacy UI boundaries.
- [x] #4 Review evidence groups input, expected/generated output, validation and optional baseline differences for each case.
- [x] #5 Mechanical validation covers malformed output, enrichment list item types/required values and source-body preservation; validator failures fail the run.
- [x] #6 Multi-case text evals reuse a loaded model sequentially without case-context leakage or unintended generation changes.
- [x] #7 Concise shared reporting captures concrete omissions, hallucinations, regressions and improvements; semantic review and owner judgment remain required.
- [x] #8 Run metadata records actual model identity, prompt/fixture hashes, code revision and dirty state, and generation settings for reproducible comparisons.
- [x] #9 Active-suite navigation, stale troubleshooting/source-path advice and local development installation/rollback/build identification are addressed in coordination with TASK-22.
- [x] #10 Representative before/after effort and elapsed-time evidence distinguishes measured savings from estimates; applicable checks use repository fixtures.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Provide a shared runner for isolated fixture execution, stage/case selection and saved-result validation.
2. Assemble review evidence and run metadata, and reuse model weights sequentially with a fresh context per case.
3. Improve source navigation and local development instructions.
4. Verify CLI behavior, model output and measured timing; record limitations for owner review.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
The consolidated runner supports stage/case selection, isolated configuration, sequential text-model reuse, strict output validation, reproducibility metadata and per-case review bundles. Source navigation and local installation/rollback guidance are included. Integration into main preserves the newer per-case enrichment dates, seeds, diagnostics and fixture checks.

Build and 209 deterministic tests passed. Evaluator tooling passed 66 checks on both installed Ruby versions; 25 enrichment validation checks and six CLI seed boundaries passed. The full native fixture pipeline completed and its corrected saved-output checks pass 5/5. Eight native filename cases were manually reviewed; one Dutch case still ignores the supplied date and is correctly rejected. The merged fictional enrichment case completes with valid bounded metadata and exact body preservation, but shortens its artificial name.

Measured filename time was 95.98 seconds for separate calls versus 106.54 seconds for the complete new runner, including hashing, build and review assembly. This does not establish an end-to-end speedup or agent-token savings. Full native suites were not repeated for the integration.

## Evaluation procedure retained during documentation consolidation

# Fixture evaluations

`scripts/run-evals.sh` owns execution, isolated configuration, selection and artifact naming. Run from the repository root with Swift, Ruby (standard library), and installed local models. Do not read personal app configuration, speaker context, notes or recordings. Inputs come only from `eval/`; inference runs sequentially. Finish compiling before inference and do not edit a running evaluator.

```sh
# Discover the active suite or exact case stems without models/builds.
bash scripts/run-evals.sh --list
bash scripts/run-evals.sh --stage filename --list

# Focused iteration; quote stems with spaces and omit their extension.
bash scripts/run-evals.sh --stage filename --case 04_short_entry
bash scripts/run-evals.sh --stage cleanup --case '2025-01-14 side project'
bash scripts/run-evals.sh --stage enrich

# Required full gates remain separate and sequential.
bash scripts/run-evals.sh --pipeline
bash scripts/run-evals.sh --suites
# --all (the default) runs pipeline then suites.

# Revalidate saved artifacts without builds, downloads or inference.
bash scripts/run-evals.sh --validate-run tmp/evals-<stamp>
# Compare selected cases to another new-format saved run.
bash scripts/run-evals.sh --stage filename --baseline tmp/evals-<baseline-stamp>

# Deterministic selection/validator/evidence regression checks.
ruby scripts/test-evals.rb
```

`--categorize` and `--enrich` remain compatibility aliases for their respective `--stage` selections. Legacy complete timestamped suites can still be checked with `--validate-run <stamp>` or stage-only `--validate-categorize <stamp>` / `--validate-enrich <stamp>`. Their model labels must match the environment overrides used to generate them. New runs use an explicit manifest, so later validation does not guess labels, cases or output paths. Legacy runs lack captured configuration and fixture snapshots; they cannot establish full reproducibility.

## Isolation and models

Each invocation creates a new `tmp/evals-<stamp>` with config/data and no demo seeding or personal speaker context. `CAPTAINS_LOG_EVAL_RUN_DIR` may select a new directory; an existing directory is rejected to preserve runs. Only the models needed for the selected work are required. Model files are read from their installed locations; Qwen's exact file is pinned through a symlink in the isolated run. Models are never removed or modified.

Overrides are `CAPTAINS_LOG_EVAL_QWEN_FOLDER`, `CAPTAINS_LOG_EVAL_QWEN_FILE`, `CAPTAINS_LOG_EVAL_QWEN_LABEL` (display/output label only), `CAPTAINS_LOG_EVAL_WHISPER_FOLDER` and `CAPTAINS_LOG_EVAL_WHISPER_MODEL`. Defaults match the source build's Qwen 3.5 9B Q4_K_M and Whisper Large-v2 caches. The runner fails for missing files rather than falling back to personal config. Never launch another inference task concurrently.

Text suite cases share one loaded Qwen model, including across stages. The batch calls the same stage functions as standalone commands and preserves their generation settings. `LLM.runInference` creates and frees a fresh context and sampler for each call, so previous case text and repetition history are not reused. The pipeline separately loads Qwen once for its stages; Whisper and text processing remain sequential.

## Evidence and mechanical checks

The printed run directory contains:

- `manifest.json`: selected stages/cases and exact fixture/output paths, including pipeline artifacts.
- `metadata.json`: actual model paths, sizes and SHA-256 (Whisper file hashes), prompt/fixture/source hashes, Git revision and dirty status, compiled CLI hash, Swift version, linked runtime identities/hashes, generation defaults and elapsed time/status. Dates/times live in per-case manifests; pipeline times derive from the isolated audio’s creation time. Pipeline search readback also records the embedding model identity. Enrichment suites use and snapshot the date/time/seed settings in `eval/enrich/cases.json`; other stages and the pipeline retain their random sampling defaults. Runs support semantic comparisons, not guaranteed byte-for-byte model reproduction.
- `fixtures/`: suite input/expected snapshots; pipeline intermediates remain in its isolated `data/`.
- `review.md`: per-case index linking input, expected and generated content, validation and optional baseline diff. Audio fixtures are linked and copied, rather than rendered as text.
- Per-case `report.md`: semantic review template, preserved on revalidation. Revalidation refreshes evidence and diagnostics, not authored reports.
- Build, batch, transcription, per-case enrichment diagnostics and pipeline logs; `validation.json` reports case/failure counts and validator hash. It reflects the latest revalidation; `metadata.json` retains the original execution status.

Canonical suite outputs retain the timestamp/model/case naming under ignored `eval/<stage>/generated/`. The bundle copies them for inspection. Baseline diffs help locate changes; they are not cleanup scores. Missing matching baseline cases are stated explicitly. Invalid/missing output fails the command and remains available for diagnosis. The validator checks plain-text leakage/control bytes, full filename structure, category manifests against their expected labels, strict enrichment YAML keys/list item types/nonempty values, supplied date/time, category values, bounded metadata, unique names, 3–8 tags, expected language, fixture fingerprints and exact source-body preservation. It does not prove factual grounding or completeness.

## Semantic report

Use the stage-specific guidance in transcription, cleanup, filename, and enrichment. For categorization, compare the selected destination to the full input and expected label, explaining competing topics and any routing error.

Fill each generated `report.md` concisely:

- Omissions / changed meaning: exact missing detail or changed phrase and its consequence; “none observed” only after reading.
- Added or hallucinated content: exact addition and whether grounded in the input.
- Improvements / regressions: concrete changes versus the named baseline, or state no baseline.
- Stage-specific observations: paragraph structure, content word changes, slug relevance, metadata fields or destination as appropriate.
- Judgment and limits: acceptable or failed for the reviewed purpose, mechanical failures, remaining uncertainty and owner review.

Reference the run's metadata rather than copying long model/config details into every report. Record durable dated evidence and timing measurements in the relevant task. Do not claim token/time savings from fewer commands alone: measure elapsed time, report run scope and cache state, and distinguish observed timings from estimates. Human review remains the quality gate.

## Local development procedure

# Local development bundles

`swift run CaptainsLogApp` launches the presentation demo described in README. Use test-ui.sh for isolated eval-backed UI checks. The app launcher is separate from the active UI.

For a packaged source build, use `bash scripts/build-app.sh`. It builds both release executables, copies prompts/resources and native libraries, ad-hoc signs the bundle, and writes `dist/CaptainsLog.app` plus the versioned ZIP. It does not install or replace the Homebrew app. Requirements and release publication remain in README.

## Install and launch a development copy

Quit other CaptainsLog instances before launching a development bundle; copies share the bundle identifier. Copy to a separate user application path, retaining a previous copy outside that path for rollback:

```sh
mkdir -p "$HOME/Applications" tmp/dev-builds
# If an earlier development copy exists, archive it to a new, dated directory:
# ditto "$HOME/Applications/CaptainsLogDev.app" tmp/dev-builds/<previous-build>.app

ditto dist/CaptainsLog.app "$HOME/Applications/CaptainsLogDev.app"
```

For CLI/app checks, create an isolated config and invoke the executable directly so it inherits that environment. This bypasses default demo seeding and avoids personal data. The following starts an empty development copy, with update checks disabled; models can be set up separately or use the evaluation runner for fixture processing.

```sh
DEV_RUN_DIR="$(mktemp -d /tmp/captainslog-dev.XXXXXX)"
export CAPTAINS_LOG_CONFIG_PATH="$DEV_RUN_DIR/config.json"
export CAPTAINS_LOG_DATA_DIR="$DEV_RUN_DIR/data"
"$HOME/Applications/CaptainsLogDev.app/Contents/MacOS/cl" config set dataDir "$CAPTAINS_LOG_DATA_DIR"
"$HOME/Applications/CaptainsLogDev.app/Contents/MacOS/cl" config set automaticUpdateChecks false
"$HOME/Applications/CaptainsLogDev.app/Contents/MacOS/cl" config set automaticUpdates false
"$HOME/Applications/CaptainsLogDev.app/Contents/MacOS/CaptainsLog"
```

Do not use `open` or Finder for an isolated check: the launched process may not inherit this shell's config environment. Do not import personal recordings; copy only repository fixtures. A separately installed development copy does not change the Homebrew cask's CLI symlink; invoke its bundled `cl` by full path.

## Identify and roll back

`CFBundleShortVersionString` and `GitCommitHash` in `Contents/Info.plist` identify the declared version and checkout revision. An uncommitted source build can share both values with a different binary. Record dirty state at build time and executable checksums when comparing builds:

```sh
git rev-parse HEAD
git status --short
/usr/libexec/PlistBuddy -c 'Print :GitCommitHash' dist/CaptainsLog.app/Contents/Info.plist
shasum -a 256 dist/CaptainsLog.app/Contents/MacOS/CaptainsLog dist/CaptainsLog.app/Contents/MacOS/cl
codesign --verify --deep --strict dist/CaptainsLog.app
```

Save that output alongside the archived development bundle. Quit the development app, move the current development copy aside, then `ditto` the archived bundle back to `$HOME/Applications/CaptainsLogDev.app`. Verify its recorded checksum/signature and relaunch with isolated config. This restores the binaries/resources only; it does not revert data migrations. Keep each test's isolated data root with the corresponding build.

For ordinary use, quit the development copy and open the existing `/Applications/CaptainsLog.app`. Homebrew installation/upgrade and release publishing follow the public README; do not overwrite its managed app as part of this development workflow.

## Source navigation

# Source map

Start here before guessing filenames. All paths are relative to the repository root; use `rg -n 'TypeName' Sources` for embedded types. Build and verification commands live in README, scripts and evaluations.

| Concern | Active source / boundary |
|---|---|
| App launcher, menus, debug fixtures | AppMain.swift; DemoMode.swift seeds presentation-only demo data. |
| Shipped Logs UI and Settings | FieldNotesContentView.swift: embedded private `FieldNotesEntriesView`, `FieldNotesEntryRow`, `FieldNotesEntryDetailView`, `FieldNotesRecordDock`, `FieldNotesSettingsView`, `ThirdPartyNoticesView`, onboarding and delete dialog. These do not have individual source files. |
| Appearance | FieldNotesTheme.swift, FieldNotesToggleStyle.swift; conceptual references in design. |
| App state / entries | AppState.swift includes entry/metadata types; DirectoryWatcher.swift, EntryRowBehavior.swift, RecordingState.swift. |
| Processing queue / model lifecycle | ProcessingCoordinator.swift, ModelManager.swift. |
| Pipeline / persisted stages | Pipeline.swift includes stage, entry, result and operation types. Read ADR-016 before changing artifacts. |
| Text inference / stage prompts | LLM.swift contains `ModelContainer` and the serial inference gate; Cleanup.swift, Categorize.swift (category/manifest types), Filename.swift, Enrich.swift. Prompts in prompts; rendering in `PromptLoader`, `PromptResolver`, `PromptXML`, `PromptDebug`. |
| Audio / transcription | Recorder.swift, RecorderOperations.swift, Transcriber.swift. |
| Configuration / model storage | Config.swift contains `CaptainsLogConfig`; ConfigManager.swift handles UI persistence/reload; ModelStorage.swift. See ADR-017. |
| Search / indexing | Search.swift, Embeddings.swift, SearchManager.swift. |
| Updates | AppUpdater.swift, UpdateManager.swift. |
| CLI | CL.swift contains command types; EvalBatch.swift is the internal sequential text-suite transport. |
| Tests / evals | Framework-free tests in run-tests/main.swift, not `Tests/`; evaluator tooling checks in test-evals.rb. Active fixtures under `eval/{transcribe,cleanup,categorize,filename,enrich}`; eval/tng-reference is a reference corpus, not the active suite. |
| Native UI fixture seams | DesignFixtures.swift, `CAPTAINSLOG_UI_FIXTURE`, test-ui.sh. Use isolated config to bypass demo seeding. |
| Legacy UI boundary | ContentView.swift, FirstRunView.swift, Theme.swift, LCARSKit.swift are the older interface, not the launcher’s current root. Public legacy views are not proven removable: check downstream SwiftPM users, previews and resources under ADR-007. |

Before architecture changes, search the ADRs. Keep current work and acceptance status in Backlog, and record dated findings in the relevant tasks.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Integrated on main with focused evaluation, assembled review evidence, strict validation and clearer project navigation. Verification and known limits are summarized above. TASK-22 retains broader documentation review; the owner has marked this task Complete.
<!-- SECTION:FINAL_SUMMARY:END -->

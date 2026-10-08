# Changelog

Every repository change is recorded here, including code, prompts, dependencies,
fixtures, tests, documentation, and release tooling. Entries describe actual
changes; planned features stay in the plans. New work goes under **Unreleased**.
Released sections use `## [MAJOR.MINOR.PATCH] - YYYY-MM-DD`, newest first.

The history below was reconstructed from Git commits and release tags. The
initial commit is the baseline; earlier development history is unavailable.
Automated cask version/checksum commits are covered by their release's packaging
entry. Git links provide the complete commit history for each release.

## [Unreleased]

### Removed

- Remove the rejected enrichment fixture and its presentation-related references; replace it with an unrelated, wholly fictional lantern-festival diary and reassess native behavior without transferring the old reproduction claim.

- Remove the keyboard, VoiceOver, reduced-motion and layout-stability acceptance item from the Logs plan and its backlog summary; retain clean-machine packaged-app checks.
- Remove the obsolete startup benchmark and its debug recording hooks; document the retained build and verification scripts in `scripts/README.md`.

### Changed

- Require owner-requested work for agent-created backlog tasks and drafts; report newly discovered work without automatically adding board items, and allow small mechanical edits without a task.
- Move TASK-28 to Next and define acceptance checks for pinned native dependencies, clean builds independent of Homebrew runtimes, recorded toolchain/options, repeatability and packaged-runtime verification.

- Record the unsuccessful fixture-only reproduction of recurring enrichment exhaustion: six long-input trials, four standard enrichment cases and the installed CLI’s shared-model pipeline completed; document semantic errors and keep TASK-41 open without claiming a fix.
- Explain the `adrs` workflow for contributors and agents, including how to find and create records, keep templates factual, and supersede historical decisions.
- Configure `adrs` for Markdown decisions in `docs/`, migrate the five architecture rules from agent instructions into individual minimal ADRs, give existing ADRs unique tool-compatible filenames, and document supersession and the distinction from Backlog.md.
- Use To Do, Next, Verify, and Complete backlog columns, with owner-selected agent work and a separate owner review step; update the CLI guidance and migrate the completed setup task.
- Move the open plan items into Backlog.md task files, make the CLI the single task workflow for Codex, and point existing guidance at the new backlog while retaining detailed procedures and decisions.
- Record combined-main model-storage verification and the updater fixture tests’ dependency on whether the installed app is running in ADR-007.
- Run GitHub Actions only for release tag pushes; remove branch-push and pull-request CI, move release-tooling checks into the release workflow, and document local testing and changelog coverage checks.

- Clarify the existing transcript-copy backlog item as quick buttons for copying the complete cleaned transcription to the clipboard, and remove the general hardware, installed-model, native UI and search-quality acceptance backlog items and Developer ID/Mac App Store exploration.
- Consolidate open product, Kev evaluation, publication, runtime maintenance and release acceptance work in `docs/PLAN.md`; keep implementation procedures and historical evidence in linked detail files and ADRs, remove duplicate status lists, and update contributor/documentation links. Track landing-page deployment verification after its implementation.

### Added

- Add focused stage/case fixture evaluations, sequential shared-model text batches, run metadata and per-case review bundles with optional baseline diffs. Preserve full pipeline/suite entry points and legacy saved-run validation; ignore generated JSON/log artifacts alongside Markdown.
- Add a linked source map and isolated local development installation, build-identification and rollback instructions.

- Add a compact, wholly fictional bedtime-story fixture that triggers native pre-fix context exhaustion while copying an invented name; record independent provenance, source fingerprint, runtime settings and verification limits.

- Add repeatable enrichment evaluation controls (`cl enrich --seed` and `--diagnostics`), per-case settings, an enrichment-only sequential suite, and saved-output checks for schema, duplicate names, metadata bounds, supplied date/time and exact transcript preservation. Include model-free validator and seed-boundary checks.
- Preserve historical native reproduction setup and strict enrichment output gates. The first attempted fixture was rejected for presentation-related content and removed; replacement coverage and limitations are recorded in ADR-007.
- Add a backlog item for Make-based repository script entry points, including an ADR explaining the choice and checks for sequential inference, argument forwarding and fixture isolation.
- Record a separate investigation draft for the Whisper Metal assertion encountered during the enrichment fix's fixture pipeline check.
- Add TASK-42 to prioritize reducing agent navigation and evaluation overhead, with acceptance criteria and explicitly unmeasured time/token savings estimates.
- Add a Settings backlog item for structured misspelling/correct-spelling fields, entry management and migration of existing corrections.
- Add a Settings redesign backlog item focused on visual polish, organization, clear controls and user feedback.
- Document a staged Kev decision-model evaluation and integration plan, including Dutch fixtures, 16 GB M4 memory checks, CLI/config support, and acceptance gates; link it from planned features.
- Show Whisper, Qwen, and smart-search model disk usage in Settings, with confirmed deletion while idle and automatic downloads on next use. Add `cl models` and `cl models --delete <whisper|qwen|embeddings>`; preserve unrelated files in custom model folders and configured model identifiers. Cover deletion/download behavior with deterministic and isolated CLI fixtures, and record native Settings and full pipeline verification in ADR-007.
- Add a static CaptainsLog website with an app-matched dark design, a documentation-based voice-journal description, local processing and Markdown/search details, install instructions, and a placeholder ready for owner-recorded app footage. Include ImageGen design references and synthetic fixture-backed illustrative logs.
- Add this Git-backed changelog, contributor instructions, and a release checklist; update publication guidance and record the release process in ADR-010. CI requires changelog updates for repository changes; releases validate and publish the matching dated entry as GitHub release notes, including on reruns.
- Add a release command that infers the highest version bump from Conventional Commits since the latest release (fix/perf → patch, feat → minor, breaking → major or minor on 0.x), skips maintenance-only releases, supports manual overrides, rolls over notes and Git links, runs sequential checks, creates a commit/tag, and optionally publishes through an atomic Git push. Require Conventional Commits for new work and use `chore(release)` for generated release/cask commits. Implement release tooling in one standalone Swift script with Bash/Git fixture tests and document its commands; no additional runtime or package dependencies.

### Fixed

- Preserve per-case enrichment seeds, dates, diagnostic logs, fixture fingerprints and strict output gates when integrating the consolidated evaluator with newer enrichment regression work.

- Consolidate stage skills around one evaluation runner and shared semantic reports; reject malformed output, invalid enrichment fields and source-body changes with failing command status. Resolve pipeline slug stems to Markdown paths and make artifact assertions fail explicitly on macOS Bash 3.2. Correct stale UI paths, inactive-corpus links and ANE/llama-cli/GPU-layer troubleshooting advice.

- Resolve llama.cpp and GGML headers through their versioned pkg-config include paths instead of the mutable global Homebrew header alias, preventing release builds from reusing a module compiled against an older header after an upgrade. Declare the existing GGML dependency explicitly because Homebrew's llama package metadata omits its include path.

- Prevent the reproduced enrichment entity-list loop with enrichment-only sequence repetition protection and a 4,096-token metadata budget. Reject unfinished output at explicit token limits, accept end-of-generation immediately after the budget, and remove duplicate sampler acceptance. Clarify work categories and unique metadata names; add budget-boundary regressions and record native reproduction, fixture semantics and verification in ADR-007 (TASK-41).

- Correct generation-exhaustion errors to report the actual allocated context rather than the model’s larger maximum. Tighten enrichment instructions to return one YAML mapping and stop after the summary; retain existing sampling settings after evaluation trials introduced metadata errors. Add deterministic generation-loop tests for the reported 8,115-input/8,269-output exhaustion and normal end-of-generation.

- Deliver app pipeline progress in order and finish consuming it before reporting completion, preventing delayed status updates from outliving a finished or cancelled recording. Preserve a new retry when an earlier cancelled attempt exits; add fixture-backed completion and cancelled-retry regressions and record verification limits in ADR-007.

- Route Homebrew updater Git calls for the public CaptainsLog tap through HTTPS with a temporary wrapper, avoiding SSH authentication failures without changing saved remotes or global Git configuration. Extend the updater fixture and document the transport correction and verification limits (`fed98bd`).

## [0.1.2] - 2026-10-01

### Added

- Add automatic Homebrew update checks and installation, Settings controls, and `cl update` commands. Wait for recording, processing, and model setup before installing; restart after automatic installation and offer manual restart after manual installation.
- Add deterministic coverage for pipeline recovery, recorder operations, model setup, settings, search, and entry interactions; add isolated CLI, model, UI, and hardware verification scripts and sequential fixture evaluation tooling.
- Add lightweight model-free unit tests in GitHub Actions and updater fixtures and controller tests.

### Changed

- Refine Settings controls and their design references; store update preferences in configuration and disable automatic checks in source builds and demos.
- Consolidate verification reports and legacy-code findings in ADR-007, remove completed plans, and refresh documentation links and remaining product work, including category settings/filtering plans. Remove the obsolete history-reset ADR.
- Update `VERSION` to 0.1.2; release packaging publishes a versioned archive and updates Homebrew cask metadata.

### Fixed

- Harden pipeline stage recovery, failure reporting, configuration handling, and recorder cleanup through injectable operations and deterministic tests.

## [0.1.1] - 2026-09-25

### Added

- Publish through the separate `vnglst/homebrew-captainslog` tap, allowing direct qualified Homebrew installs.
- Add opt-in managed-model cleanup through `brew uninstall --cask --zap captainslog`, keeping logs, configuration, and custom model folders; record install and uninstall verification.
- Document distribution, tag-driven releases, model cleanup, and isolated demo decisions in ADRs; record transcript-copy and menu-bar feature plans.

### Changed

- Update public install instructions and publication status, and update the release workflow checkout action.
- Update `VERSION` to 0.1.1 and publish the archive with matching Homebrew cask version and checksum.

## [0.1.0] - 2026-09-25

### Added

- Initial public app and CLI: local recording, Whisper Large-v2 transcription, Qwen cleanup/categorization/filenames/metadata, resumable pipeline stages, and keyword/semantic log search.
- Add the Logs workspace, entry details, recording controls, processing/recovery actions, first-run model setup, and file-backed configuration.
- Package the GUI and CLI with llama.cpp runtime libraries in an ad-hoc-signed macOS archive, with a Homebrew cask and automated tag-driven releases.
- Include isolated synthetic TNG demos, repository evaluation fixtures, framework-free tests, design references, architecture decisions, and publishing documentation.
- Add third-party notices and bundled license copies; strip creator metadata from design reference images.

### Changed

- Consolidate agent guidance and move stage evaluation workflows to agent-neutral skill paths.

### Fixed

- Make release tests work on clean runners without preinstalled inference models.

[Unreleased]: https://github.com/vnglst/CaptainsLog/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/vnglst/CaptainsLog/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/vnglst/CaptainsLog/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/vnglst/CaptainsLog/commits/v0.1.0

# Changelog

Concise changes to the app, CLI and development tools are recorded here. Related
work is combined; backlog updates and planned work stay out of the changelog and
release notes. New work goes under **Unreleased**.
Released sections use `## [MAJOR.MINOR.PATCH] - YYYY-MM-DD`, newest first.

The history below was reconstructed from Git commits and release tags. The
initial commit is the baseline; earlier development history is unavailable.
Automated cask version/checksum commits are covered by their release's packaging
entry. Git links provide the complete commit history for each release.

## [Unreleased]

### Added

- Transcribe app and pipeline recording chunks while capacity is available to reduce processing after stop, with full-file fallback when another inference job is active or background transcription is unsafe or fails, and a bounded chunk queue that accommodates slow initial model loading.

- Remember the selected microphone across app restarts and fall back to an available input when disconnected.

- Restore Reprocess in processed log actions and the log detail view; rerun every stage for that recording through the shared pipeline while preserving its audio and other entries.
- Refresh the log's retry state if clearing its old outputs fails during reprocessing.

### Fixed

- Finalize active recordings before quitting; bound shutdown when native model initialization cannot stop promptly, without racing Metal teardown.

- Acknowledge pending restarts while cancelled native work finishes, and queue additional Reprocess requests without overlapping processing.

- Keep Logs, recording controls, Context and Settings at readable widths in large and full-screen windows.

- Restore microphone selection in Settings with a device picker shared with the recording dock's selected input.
- Make the All entries chevron, label and surrounding padding clickable; give log detail actions and icon-only search, correction and category controls explicit click targets.

- Cancel and drain all current and superseded search work, release the cached embedding model, and ignore late search callbacks before app termination so native Metal allocations are freed before backend static teardown; keep CLI and GUI inference on the same Core model lifecycle.

- Reject isolated test-bundle launches without a valid explicit configuration and data directory before app state can fall back to normal user settings, including release fixture bundles relaunched by automation.
- Bundle pipeline prompts in the isolated native UI harness so fixture processing can resolve cleanup, categorization, naming and enrichment instructions outside the repository working directory.
- Resolve SwiftPM product-directory symlinks when bundling the native runtime so app bundles do not retain absolute framework search paths into build output.
- Recover genuine Whisper initialization failures once by repairing download sidecars and the reported temporary compiled-model cache. Validate prepared model weights without scanning unrelated files; preserve settings on cancellation, discard canceled output and drain CoreML work before shutdown.

- Avoid the CoreML Metal prediction path that can abort Whisper transcription with an MPSGraph tensor shape/stride assertion: run the spectrogram on CPU and the unchanged Whisper Large-v2 encoder and decoder on CPU/Neural Engine; record all three compute selections in evaluation metadata.

### Changed

- Add an experimental CLI option to generate filing categories, filenames and searchable metadata together.
- Keep backlog-only updates out of changelog coverage and release notes; remove backlog noise and duplicate context from the existing history.
- Let the category list scroll with the whole Context or setup page instead of inside a fixed-height panel.
- Introduce CaptainsLog through its uses and privacy in the README, sidebar, Logs, setup and search screens.



- Remove the duplicate Reprocess button from the individual log header while retaining Reprocess in the log row menu.

- Add isolated native startup and quit-during-decoding checks with optional Whisper loading diagnostics, recorded model/binary/fixture identities, validated configuration, watchdogs and shutdown markers.

- Update WhisperKit to 1.1.1, Transformers to 1.3.5, Hugging Face to 1.0.0, all resolved Swift transitive dependencies to their newest stable releases, Swift Jinja to 2.5.2 (with parser overflow checks and clearer errors), the checksum-pinned llama.cpp framework to b11723, and sqlite-vec to the newest published 0.1.10-alpha.4 amalgamation with the matching split sources omitted from its upstream archive. Retain complete upstream Transformers/Hugging Face sources with dependency-constraint patches for Swift Crypto 5.0.1 and yyjson 0.13.0; include their licenses when packaging and resolve their shared Hugging Face dependency through one local package identity. Pin the release workflow checkout action to the newest 7.0.1 release.
- Add isolated native cached-search/quit checks with eval-backed pipeline entries, verified search indexes and explicit source/process identity; bypass onboarding without changing saved defaults.

- Reuse the chronological date formatter when restoring entries to improve CLI and Logs startup, preserving strict date validation and time-zone semantics.

- Use the same 128-token Qwen prompt chunks in CLI and app processing so cancellation can interrupt between shorter Metal calls, with models, context and sampling unchanged.

- Allow dragging and dropping category rows in Context and initial setup to reorder them; save the chosen order for future processing.

- Reduce Qwen inference graph memory by reserving logits for only the final token of each batch; keep the same models, prompts, generation limits, GPU offload and batch sizes.
- Move personal context, name and term corrections, and categories into a separate Context destination using their existing editors; reorder Settings to audio input, storage, models, updates, processing outputs, and About without a submenu.
- Remove separate CLI and per-entry UI reprocessing, backup creation and saved batch resume; add confirmed `cl delete-outputs` and use existing pending processing after deletion. Remove the public `Reprocessing`, `Pipeline.resetForReprocessing` and `Pipeline.reprocessingCandidatePaths` interfaces; clients can delete outputs and use the existing pipeline resume APIs.

## [0.5.0] - 2026-10-11

### Fixed

- Prevent idle system sleep during single-entry, queued, pending and bulk processing, including with the screen locked; allow display sleep and release the activity after workers finish, fail or stop.
- Cancel active work on quit and close the recording without starting processing; wait for the current native call to release its resources before app teardown instead of finishing the pipeline. Keep paused processing reserved until its worker exits and discard cancelled model output before saving pipeline artifacts.

### Changed

- Replace Settings bulk reprocessing with confirmed deletion of intermediate results, finished logs and reprocessing backups while keeping source audio and settings; use the existing Logs processing controls to regenerate recordings.

### Release

- Publish the 0.5.0 app/CLI archive and matching Homebrew cask version and checksum.

## [0.4.0] - 2026-10-10

### Added

- Add a sticky saved-recording player in entry details with play, pause, elapsed time and seeking; stop playback when leaving the entry and show unavailable audio clearly. Cover native transport and unreadable recordings with eval fixtures, and seed matching audio in the isolated UI harness.
- Configure processing categories in Settings, initial setup, and the CLI; category removal preserves existing folders and logs.
- Add menu bar recording controls with recording time, processing status, brief errors, and actions to reopen or quit CaptainsLog. The Window menu can hide the app to the menu bar, and closing the main window keeps it available. Add isolated, labeled synthetic menu panel previews to the native UI harness for idle, recording, processing and error states.
- Filter Logs and search results by multiple categories with a checkbox menu beside search, including categories retained by existing logs; preserve selections when opening entries and apply category restrictions before search result limits.
- Add deliberate bulk audio reprocessing in Settings and `cl reprocess --confirm`, with sequential processing, previous-note backups, persistent resume checkpoints, per-recording failures and idle-sleep prevention for overnight runs.

### Changed

- Explain reprocessing backups in plain language and use singular wording for one saved recording.

- Match the menu panel to the Field Notes colors, typography, waveform identity and recording controls, without an idle label while recording; Open CaptainsLog focuses the main window when other windows are open.

- `Categorize.Category` is now a string-backed value supporting configured categories; downstream Swift clients with exhaustive switches over the three built-in enum cases must add a fallback branch. Legacy category manifest values remain compatible.

- Refresh evaluation, updater, demo and website documentation, isolate the manual updater example, document `.qta` Voice Memos imports, and distinguish historical verification from current commands and runtime evidence.

- Use fictional character names in correction tests.

### Removed

- Remove the explanatory category-removal text from Settings and onboarding.

- Remove legacy `.sh` and `.rb` automation aliases; use Make commands or the `.swift` helpers directly.

### Fixed

- Sort logs newest first by metadata date, falling back to recording date and source file creation date; use the same date for Logs day groups and entry details.

### Release

- Publish the 0.4.0 app/CLI archive and matching Homebrew cask version and checksum.

## [0.3.1] - 2026-10-09

### Added

- Add a short synthetic `.qta` memo and its spoken text to the demo audio, and include QuickTime audio when seeding the debug demo.

### Fixed

- Recognize Voice Memos `.qta` exports, including uppercase extensions, in audio discovery, import, reprocessing, deletion and QuickTime conversion.

### Changed

- Make release preparation use only Git, version and changelog checks. Streamline the GitHub release workflow to validate, build the release app and CLI, verify packaging and publish; keep tooling, runtime reproducibility and deterministic test suites as explicit development commands.

- Add source and tooling implementation maps, correct the Settings preview command and evaluation release guidance, and document updater test prerequisites and current runtime setup.

### Release

- Publish the 0.3.1 app/CLI archive and matching Homebrew cask version and checksum.

## [0.3.0] - 2026-10-09

### Added

- Pick up QuickTime audio exports (`.mov` and `.qt`) alongside M4A recordings in the app, preserving source extensions through CLI import, processing, reprocessing and deletion. Convert QuickTime audio to a temporary M4A for transcription while keeping the original recording.

### Removed

- Remove the legacy correction notes section from Settings and discard free-text notes from saved corrections when the app loads them. Keep structured spelling pairs and their CLI-readable format.

### Changed

### Release

- Publish the 0.3.0 app/CLI archive and matching Homebrew cask version and checksum.

## [0.2.1] - 2026-10-09

### Fixed

- Clear inherited Make arguments for release builds so `make release ARGS=--publish` does not pass `--publish` to Swift.

- Put the framework binary before `lipo -verify_arch` in runtime tests and packaging checks so Xcode's lipo does not parse its path as an architecture.

### Changed

- Restore local release builds and deterministic tests: build all debug products once, then run the built tests directly with isolated config/data, avoiding repeated SwiftPM and tooling-package compilation. Print check timings and disable model-backed search integration; keep evaluations separate.

### Release

- Publish the 0.2.1 app/CLI archive and matching Homebrew cask version and checksum.

## [0.2.0] - 2026-10-09

### Added

- Add `make dev` to launch the cached debug app directly with its isolated demo data, skipping SwiftPM when source and package inputs are unchanged; rebuild the app when missing or inputs change. Keep `make` and `make run` as aliases, without packaging, tests or evaluations.

### Removed

- Remove the unused legacy LCARS interface, onboarding and common controls, along with their Antonio font and resource bundle; retain active Field Notes UI, shared state/color helpers and debug fixtures. Update packaging, native UI harness and coverage inputs for the removed resources.

- Remove the rejected enrichment fixture and its presentation-related references; replace it with an unrelated, wholly fictional lantern-festival diary and reassess native behavior without transferring the old reproduction claim.

- Remove the obsolete startup benchmark and its debug recording hooks; document the retained build and verification scripts in `scripts/README.md`.

### Changed

- Keep local release preparation fast by running only Git, version and changelog checks; leave builds, deterministic test suites and runtime verification to the tag workflow before archive publication. Bypass external Git diff tools and pagers during the whitespace check. Keep model evaluations separate through `make evals`, so releases do not require local models.

- Implement repository automation helpers in Swift, preserving Make workflows, fixture validation, packaging and release checks with executable compatibility aliases; update the documented helper commands. Verify the full audio fixture pipeline, completed-artifact resume and search readback through the Swift helpers.

- Pin development and release inference to one checksum-verified llama.cpp/GGML XCFramework, remove Homebrew/OpenMP runtime resolution, verify packaged linkage and repeatable native artifact extraction, preserve the isolated UI launcher, and record framework identity in evaluation evidence.

- Settings now edits name and term corrections as spelling pairs with add and remove controls. Preserve existing corrections and legacy notes in the same CLI-readable Markdown file.

- Make now drives building, development launch, tests, fixture evaluations, packaging and releases, with standard variable options and supporting iteration targets. Plain `make` launches the development app; release checks and CI use the same commands, and test commands isolate configuration and data. Remove the unused legacy evaluation-validation wrapper.

- Move unused TNG reference scripts and fixtures to eval/tng-reference, separate from active evaluations and demo assets.
- Run GitHub Actions only for release tag pushes; remove branch-push and pull-request CI, move release-tooling checks into the release workflow, and document local testing and changelog coverage checks.

### Added

- Add a copy button in entry detail for the complete cleaned transcription, preserving paragraphs and Markdown while excluding summary and metadata; show copied confirmation.

- License CaptainsLog’s original source code under MIT, reference separate third-party terms in the license and README, include the project license in release app bundles, and preserve the resolved WhisperKit package’s plural NOTICES file.

- Add a compact, wholly fictional bedtime-story fixture that triggers native pre-fix context exhaustion while copying an invented name; record independent provenance, source fingerprint, runtime settings and verification limits.

- Add repeatable enrichment evaluation controls (`cl enrich --seed` and `--diagnostics`), per-case settings, an enrichment-only sequential suite, and saved-output checks for schema, duplicate names, metadata bounds, supplied date/time and exact transcript preservation. Include model-free validator and seed-boundary checks.
- Show Whisper, Qwen, and smart-search model disk usage in Settings, with confirmed deletion while idle and automatic downloads on next use. Add `cl models` and `cl models --delete <whisper|qwen|embeddings>`; preserve unrelated files in custom model folders and configured model identifiers.
- Add a static CaptainsLog website with an app-matched dark design, a documentation-based voice-journal description, local processing and Markdown/search details, install instructions, and a placeholder ready for owner-recorded app footage. Include ImageGen design references and synthetic fixture-backed illustrative logs.
- Add the Git-backed changelog and release checklist; validate and publish matching dated entries as GitHub release notes, including on reruns.
- Add a release command that infers the highest version bump from Conventional Commits since the latest release (fix/perf → patch, feat → minor, breaking → major or minor on 0.x), skips maintenance-only releases, supports manual overrides, rolls over notes and Git links, runs sequential checks, creates a commit/tag, and optionally publishes through an atomic Git push. Require Conventional Commits for new work and use `chore(release)` for generated release/cask commits. Implement release tooling in one standalone Swift script with Bash/Git fixture tests and document its commands; no additional runtime or package dependencies.

### Fixed

- Resolve llama.cpp and GGML headers through their versioned pkg-config include paths instead of the mutable global Homebrew header alias, preventing release builds from reusing a module compiled against an older header after an upgrade. Declare the existing GGML dependency explicitly because Homebrew's llama package metadata omits its include path.

- Prevent the reproduced enrichment entity-list loop with enrichment-only sequence repetition protection and a 4,096-token metadata budget. Reject unfinished output at explicit token limits, accept end-of-generation immediately after the budget, and remove duplicate sampler acceptance. Clarify work categories and unique metadata names; add budget-boundary regressions.

- Correct generation-exhaustion errors to report the actual allocated context rather than the model’s larger maximum. Tighten enrichment instructions to return one YAML mapping and stop after the summary; retain existing sampling settings after evaluation trials introduced metadata errors. Add deterministic generation-loop tests for the reported 8,115-input/8,269-output exhaustion and normal end-of-generation.

- Deliver app pipeline progress in order and finish consuming it before reporting completion, preventing delayed updates after completion or cancellation. Preserve a new retry when an earlier cancelled attempt exits.

- Route Homebrew updater Git calls for the public CaptainsLog tap through HTTPS with a temporary wrapper, avoiding SSH authentication failures without changing saved remotes or global Git configuration.

### Release

- Publish the 0.2.0 app/CLI archive and matching Homebrew cask version and checksum.

## [0.1.2] - 2026-10-01

### Added

- Add automatic Homebrew update checks and installation, Settings controls, and `cl update` commands. Wait for recording, processing, and model setup before installing; restart after automatic installation and offer manual restart after manual installation.
- Add deterministic coverage for pipeline recovery, recorder operations, model setup, settings, search, and entry interactions; add isolated CLI, model, UI, and hardware verification scripts and sequential fixture evaluation tooling.
- Add lightweight model-free unit tests in GitHub Actions and updater fixtures and controller tests.

### Changed

- Refine Settings controls and their design references; store update preferences in configuration and disable automatic checks in source builds and demos.
- Update `VERSION` to 0.1.2; release packaging publishes a versioned archive and updates Homebrew cask metadata.

### Fixed

- Harden pipeline stage recovery, failure reporting, configuration handling, and recorder cleanup through injectable operations and deterministic tests.

## [0.1.1] - 2026-09-25

### Added

- Publish through the separate `vnglst/homebrew-captainslog` tap, allowing direct qualified Homebrew installs.
- Add opt-in managed-model cleanup through `brew uninstall --cask --zap captainslog`, keeping logs, configuration, and custom model folders; record install and uninstall verification.
- Document Homebrew distribution, tag-driven releases, managed-model cleanup and isolated demos.

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

[Unreleased]: https://github.com/vnglst/CaptainsLog/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/vnglst/CaptainsLog/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/vnglst/CaptainsLog/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/vnglst/CaptainsLog/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/vnglst/CaptainsLog/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/vnglst/CaptainsLog/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/vnglst/CaptainsLog/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/vnglst/CaptainsLog/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/vnglst/CaptainsLog/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/vnglst/CaptainsLog/commits/v0.1.0

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

- Remove the obsolete startup benchmark and its debug recording hooks; document the retained build and verification scripts in `scripts/README.md`.

### Added

- Add a static CaptainsLog website with an app-matched dark design, a documentation-based voice-journal description, local processing and Markdown/search details, install instructions, and a placeholder ready for owner-recorded app footage. Include ImageGen design references and synthetic fixture-backed illustrative logs.
- Add this Git-backed changelog, contributor instructions, and a release checklist; update publication guidance and record the release process in ADR-010. CI requires changelog updates for repository changes; releases validate and publish the matching dated entry as GitHub release notes, including on reruns.
- Add a release command that infers the highest version bump from Conventional Commits since the latest release (fix/perf → patch, feat → minor, breaking → major or minor on 0.x), skips maintenance-only releases, supports manual overrides, rolls over notes and Git links, runs sequential checks, creates a commit/tag, and optionally publishes through an atomic Git push. Require Conventional Commits for new work and use `chore(release)` for generated release/cask commits. Implement release tooling in one standalone Swift script with Bash/Git fixture tests and document its commands; no additional runtime or package dependencies.

### Fixed

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

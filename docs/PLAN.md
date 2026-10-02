# CaptainsLog backlog

This is the single backlog for product, evaluation, maintenance and release work. Track completion here. Linked detail files describe implementation steps and acceptance criteria; ADRs preserve decisions and dated evidence.

## Logs interface

Workspace and design context: [Logs interface details](PLAN-004-logs-implementation.md).

- [ ] Audio playback and seek controls for saved recordings.
- [ ] Collections/projects navigation after their data model and empty states are defined.
- [ ] Settings controls for categories and category setup in onboarding.
- [ ] Category filters in Logs.
- [ ] Add quick copy buttons to copy the complete cleaned transcription to the clipboard from entry detail.
- [ ] Menu bar presence with start/stop recording controls.

## Settings

- [ ] Redesign the Settings screen for visual polish and better usability: clear grouping and navigation, readable labels and help text, consistent spacing and controls, and understandable save, progress and error feedback.
- [ ] Replace the free-text misspelling corrections editor in Settings with structured entries: separate fields for the misspelling and correct spelling, with add, edit and remove controls. Preserve existing corrections during migration and keep them usable through the CLI.

## Evaluation fixtures and quality

Fixture procedures: [TNG corpus details](PLAN-002-tng-eval-set.md). Test commands, isolation rules and dated findings: [ADR-007](ADR-007-framework-free-test-coverage.md).

- [ ] Record the 13 prepared TNG scripts and populate the stage inputs and expected outputs, then complete the corpus migration and semantic review.
- [ ] Resolve meaning-changing transcription errors and rerun transcription and full-pipeline semantic evaluations.

## Kev decision model

Implementation and acceptance criteria: [Kev details](PLAN-005-kev-decision-model.md). Adoption depends on the evaluation results.

- [ ] Establish a Qwen categorization baseline, add ambiguous Dutch/English and choice-order fixtures, separate development/held-out cases, and define decision-model evaluation workflows and acceptance limits.
- [ ] Pin a compatible Kev checkpoint/conversion and llama.cpp runtime, and build an in-process CLI decision experiment that validates the trained head and probability readout against reference results.
- [ ] Evaluate Kev 4B Q8 and a compatible Kev 0.8B comparison sequentially on the 16 GB M4 Mac; measure short/long-input quality, calibration, load/decision time, memory pressure, swap and end-to-end model-switching costs.
- [ ] Record the adoption decision and semantic findings in an ADR; retain Qwen as the default unless the quality, memory and latency gates pass.
- [ ] If the gates pass, add opt-in CLI/config model selection, verified downloads, shared core decisions, runtime/error handling and tests, preserving manifests, resumability and sequential model lifetimes.
- [ ] Separately evaluate summary grounding on Dutch/English source-summary pairs, including false alarms and missed unsupported claims; expose an evaluation report before deciding on an optional pipeline stage or app controls.
- [ ] After implementation, complete build/tests, filename smoke evaluation, all sequential stage suites, full fixture pipeline and offline packaged-app checks for Kev and the Qwen-only configuration.

## Publication review

Review procedures, asset inventory and historical publication evidence: [Publication details](PUBLISHING-PLAN.md).

- [ ] Review all tracked files, hidden files and any Git LFS objects for private content, credentials, account/machine identifiers and local paths; keep the owner's permitted name/email exception.
- [ ] Review every reachable branch, tag and release for private material; assess exposure and remediation if anything is found.
- [ ] Review demo/evaluation fixtures and generated reports for accidental personal content and clear synthetic labeling.
- [ ] Review `.gitignore`, build/test scripts and CI safeguards for configs, model caches, recordings, outputs, signing material and build artifacts.
- [ ] Review README, docs, detail files, design references, examples and comments for obsolete behavior, internal notes and contradictory installation claims.
- [ ] Add a project license or explicitly state that the source is all rights reserved; verify dependency/model notices and their copies in the release bundle.
- [ ] Review privacy claims against implementation, including model downloads, update checks and any other network behavior.
- [ ] Review ad-hoc signing and quarantine removal, document their trust implications and verify the cask targets only the intended app path.
- [ ] Align app/bundle/CLI names, version, support route, macOS/architecture requirements, storage estimates and known limitations across the app, cask and documentation.

## Distribution and maintenance

The website, app/CLI bundle, public Homebrew tap and tag-driven release workflow are implemented. Release procedures: [README](../README.md#changelog-and-releases) and [publication details](PUBLISHING-PLAN.md).

- [ ] Verify deployment of the implemented landing page at `captainslog.koenvangilst.nl`, including requirements and install steps.
- [ ] Replace Homebrew build-time runtime paths with a pinned project-built or vendored llama.cpp/ggml/libomp runtime targeting macOS 26.0; verify deployment targets and reject leaked Homebrew runtime paths in packaged builds. See [ADR-005](ADR-005-use-libllama-c-api-for-text-inference.md#follow-up) and [ADR-006](ADR-006-bundle-llama-runtime-in-app.md#follow-up).
- [ ] Review apparent legacy UI symbols against downstream SwiftPM clients, previews, debug seams and resource dependencies before deciding on removal; see [ADR-007](ADR-007-framework-free-test-coverage.md#legacy-code-review-2026-09-26).
- [ ] Complete clean-machine GUI/CLI checks through both the published ZIP and Homebrew: public install commands, first launch, model download, recording, processing and search, without development tools or an existing model cache.
- [ ] Test release recovery for interrupted downloads, unavailable network, insufficient disk space, permission errors and an existing user data folder.
- [ ] Verify a real published Homebrew upgrade and automatic relaunch; retain the previous archive/cask revision as a rollback path. See [the update ADR](ADR-011-homebrew-auto-updates.md).

## Next release checks

These checks recur for each release. Record the reviewed commit/tag, commands, machine and unresolved limits in the relevant ADR or publication review record.

- [ ] From a clean candidate, run the documented build, deterministic tests, coverage gate and sequential model evaluations; review semantic findings before publication.
- [ ] Build and inspect the app/ZIP for executable architecture, bundled libraries/resources, notices and absence of developer-only files; verify its checksum against the cask.
- [ ] Review screenshots, README commands, cask metadata, changelog/release notes and archive from a new user's perspective.
- [ ] Preview and prepare the release with `swift scripts/release.swift`, review the findings, and publish the commit/tag using the documented flow.
- [ ] Review the release workflow, published notes, archive URL and tap update; verify install/upgrade behavior before announcing the release.

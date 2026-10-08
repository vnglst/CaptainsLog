---
id: TASK-36
title: Verify and publish the next release
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:16'
labels:
  - release
  - distribution
dependencies: []
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Deliver a reviewed release that users can install, upgrade and recover safely. Keep preparation, quality gates, package inspection, publication and real installation checks together in this task. Use fresh evidence for the candidate release; historical findings below explain remaining gaps and do not satisfy the new checks. Complete prepublication gates before publishing, then verify the public install and upgrade before announcing the release.

### Run candidate quality gates

From a clean release candidate, run the build, full deterministic tests, coverage gate, sequential stage evaluations and full synthetic audio pipeline. Review every selected model output for missing content, changed meaning, invented facts and downstream effects before publication.

The deterministic coverage floor is 80% for ordinary production logic. Declarative UI and direct native/hardware adapters remain visible in the aggregate report but require separate integration checks. Do not improve coverage by excluding ordinary logic. Use isolated configuration/data and repository fixtures, bypass demo seeding, and never run inference jobs concurrently or compile during inference.

Record the candidate commit, runtime/model identities, commands, semantic findings and unresolved limits. Historical passes do not establish a fresh release gate, and a transcript-seeded continuation does not count as a full audio-pipeline pass.

### Exercise failure and recovery paths

Test release failure and recovery paths: interrupted model downloads, unavailable network, insufficient disk space, permission errors and an existing data directory. Verify that failures are visible, resumable where supported and do not destroy recordings or completed entries.

Include model/index corruption and recovery, data-folder switching, and search convergence after edit, rename or Trash operations where they affect the release. Use disposable synthetic data and injected failures before native integration checks. Record the exact tested build and remaining hardware/network limits.

### Inspect the package and checksum

Build and inspect the release app and ZIP before publication. Verify executable architecture, bundled native libraries and resources, prompts, required notices and absence of developer-only files or private configuration.

Check app/CLI signatures and that their library paths resolve to bundled resources rather than a developer’s Homebrew installation. Calculate the final archive checksum and match it exactly to the source cask and public tap. If the archived bits or cask change, repeat the affected checks. Record the inspected version, commit, archive identity and findings.

### Review what new users will see

Review the release as a new user would encounter it: screenshots, installation commands, requirements, trust notices, cask metadata, changelog-backed release notes and downloaded archive.

Check that conceptual design images are labeled accurately, the current product is called Logs, commands work from public endpoints and known limitations are visible. Verify archive URLs and the public tap rather than assuming a successful build proves publication. Record the reviewed release and remaining user-facing problems.

### Prepare and publish the reviewed candidate

Prepare and publish the next release from clean main after the release gates and semantic findings are reviewed. Preview the standalone Swift release command with --dry-run, then run it to infer or explicitly select the version bump, execute sequential checks, update VERSION/changelog and create a release commit and annotated tag.

Review the result before publishing. Push commit and tag atomically through --publish or the printed command; if publication fails, retry that push rather than creating another version. Verify the tag workflow, matching release notes, archive URL/checksum and updates to both the source cask and public tap. The tap publication token requires Contents read/write access only to the intended tap repository.

A successful initial public release is historical evidence, not verification of this release. Test the published upgrade and public install path before announcing, and retain the previous archive/cask revision for rollback.

### Test public installation on a clean machine

Verify both the published ZIP and Homebrew installation on a clean macOS account or another Apple Silicon Mac, without development tools or existing model caches. Test public install commands, first launch, downloads, recording, processing, search and the bundled CLI.

Previous installation checks on the development machine confirmed the app/CLI paths, quarantine handling, model downloads and uninstall behavior. They do not replace a clean-machine check. Confirm user logs and configuration survive uninstall, optional cleanup only targets managed models, and source requirements are not accidentally required by the shipped app. Record the tested release, machine and unresolved issues.

### Verify a real published upgrade and relaunch

Verify a real published old-to-new Homebrew app upgrade, automatic replacement and OS relaunch. Synthetic updater fixtures check command flow and scheduling but cannot establish that the installed app is successfully replaced and restarted.

Confirm launch/daily checks, persisted preferences, manual controls, visible failure/retry behavior and idle gating for recording, queued/reserved processing and model setup. Check checksum enforcement, duplicate restart prevention and successful operation after relaunch. Keep the previous archive and cask revision available for rollback.

Historical fixture runs passed simulated check/install/check, preference persistence and SSH-to-HTTPS tap fetching while preserving stored remotes. Some full-suite runs were blocked by an unrelated disk-capacity guard or by the installed app running. No real upgrade/relaunch was performed in those checks; record fresh release-specific evidence.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The release candidate passes build, deterministic tests, the production coverage gate, sequential stage suites and the full synthetic audio pipeline, with semantic output review and documented native/UI limits.
- [ ] #2 Disposable synthetic-data checks verify failure and recovery behavior for downloads, network, disk, permissions, model/index corruption and data/search changes without losing canonical entries.
- [ ] #3 The archive has the expected architecture, bundled libraries/resources, signatures and notices, contains no private configuration, and matches both published cask checksums.
- [ ] #4 Public commands, requirements, screenshots, trust notices, release notes, archive URLs and known limitations are reviewed for the candidate release.
- [ ] #5 Release preparation is previewed and reviewed, the version/changelog commit and annotated tag are published atomically, and the release workflow, archive and both casks are verified.
- [ ] #6 Published ZIP and Homebrew installation, first launch, downloads, processing, search, bundled CLI and data-preserving uninstall are verified on a clean account or second supported Mac; microphone capture requires explicit confirmation.
- [ ] #7 A real published old-to-new Homebrew upgrade verifies scheduling, preferences, checksum enforcement, failure/retry behavior and OS relaunch, with the previous archive/cask retained for rollback.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
### Run candidate quality gates

Historical baselines: September 26 passed 184/184 full tests and 132/132 unit tests, with 82.16% deterministic-production coverage and 31.58% all-source coverage. Later October checks reached 209/209 full tests. These totals describe their respective revisions, not the current tree.

October 2 pipeline and resume/search checks passed with synthetic audio, but known transcription and summary omissions remained. October 7 enrichment integration encountered a separate Whisper Metal shape/strides assertion before enrichment; transcript-seeded downstream success did not pass the full audio gate. October 8 task-42 evidence includes a completed native pipeline, corrected saved validation 5/5, and a focused seeded enrichment check. Model suites were not all repeated for that transport integration.

Native UI review on September 26 used isolated fixtures and accessibility, not screenshot geometry or microphone/model operation. Safe logs/detail/search/queue/Settings states and deletion flows were exercised; real recording, downloads, folder persistence and processing retries still require their own checks. Earlier source-only legacy UI review removed no symbols. Keep these limits visible when deciding what fresh release evidence is still needed.

Historical search implementation checks used fake embeddings and a multilingual synthetic query corpus. Real-model relevance, offline packaged-app behavior, corrupt model/index recovery, interrupted setup and edit/rename/Trash convergence still require explicit integration evidence. The search index is derived and disposable; canonical Markdown must not be changed by recovery.

### Prepare and publish the reviewed candidate

Historical release-tooling verification, October 1, 2026: synthetic Git/changelog fixtures covered bump precedence, breaking footers, maintenance-only history, tag/version mismatch, note rollover, dirty-tree and failed-check rejection, cask limits and atomic publication against a local bare remote. Native build/model commands were substituted in those tooling tests. A dry run selected 0.2.0 without editing files or publishing.

The full suite at that revision passed 193/200 and the audio pipeline stopped at the unrelated disk-capacity guard. The tool correctly blocked release commit/tag creation. Initial v0.1.0 publication had previously produced the archive and public tap; it does not establish that later release automation or current token permissions still work.

### Test public installation on a clean machine

Historical public-cask test: app installation, bundled CLI, quarantine removal, first-run model setup and strict cask audit passed on the development machine. Optional uninstall cleanup removed managed model folders through Trash while retaining the config checksum and default logs. That run downloaded approximately 5.7 GB in Application Support and 2.9 GB in Caches; these are observed cache sizes, not guaranteed requirements. Clean-account/second-machine acceptance remained open.

### Verify a real published upgrade and relaunch

October 1, 2026 historical checks: build and updater-specific tests passed, including a simulated checksum-required upgrade, idle scheduling, default/disabled preferences, network failures, malformed casks, retry and duplicate-restart guards. The original full suite passed 183/190, later 193/200, because seven unrelated transcription/pipeline checks stopped at a zero-capacity disk guard. Native fixture launch also failed before UI inspection. A real metadata check encountered SSH transport errors; a temporary HTTPS Git wrapper fixed that check without changing other taps. No installed-version replacement or OS relaunch was verified.

October 2 integration had two updater test failures while the real installed app was running, because the install guard checks running-app state even with fake transport. Close or isolate that prerequisite for a valid fixture check rather than labeling the updater flow broken. These historical outcomes do not close the real published-upgrade task.
<!-- SECTION:NOTES:END -->

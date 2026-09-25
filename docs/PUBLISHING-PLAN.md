# Publication plan

## Goal and release boundary

Prepare CaptainsLog for its first public GitHub release and Homebrew installation while keeping the source repository private until the review and cleanup gates below are complete. The app is ad-hoc signed, is not notarized, and the Homebrew cask removes the quarantine attribute from the installed app bundle. State that plainly wherever installation is described.

The initial release includes the macOS app, the `cl` CLI, bundled llama.cpp runtime, source code, build instructions, and synthetic TNG demo fixtures. Do not publish real personal recordings or transcripts as test data.

## Phase 1 — Remove private material from the publication candidate

- [x] Remove `.claude/settings.local.json` from the working tree. It contained a machine-specific absolute path and a local cleanup permission. `.gitignore` now excludes this path so a local copy is not accidentally added again. The file remains in Git history and must be handled by the history review below.
- [x] Review `eval/transcribe/audio/2025-01-14 side project.m4a` and matching copies in transcription, cleanup, filename, and enrichment inputs/expected outputs. The repository owner reviewed them and approved retaining them in the public candidate. Keep this approval scoped to these reviewed files; review any new recordings or generated copies before publication.
- [ ] Search all tracked files, including hidden files and Git LFS objects if present, for names and email addresses other than the user's, absolute home paths, machine and account identifiers, credentials, tokens, private URLs, local config, and personal content. The user's name and email may remain.
- [ ] Inspect images and binary files for visible paths, account names, device labels, recordings, screenshots, embedded metadata, and other identifying details. Design references already contain illustrative paths, counts, microphone labels, and a version; label them as concepts or replace them before using them as product screenshots.
- [ ] Inspect demo and evaluation fixtures. Keep synthetic TNG examples clearly labeled as fictional, and verify no real personal content has entered a generated file or report.
- [ ] Check `.gitignore`, build scripts, test scripts, and CI workflows so config files, model caches, recordings, generated outputs, signing material, and build artifacts cannot be accidentally added.

### Git history gate

Removing a file from the latest tree does not remove it from existing commits. Before the repository becomes public, inspect every reachable branch, tag, and release for the same material. If private content appears in history, prepare a clean public history or a fresh sanitized public repository; preserve the current private repository as the archival source. Do not make the existing repository public until its complete reachable history and release assets have passed review.

## Phase 2 — Review content, rights, and project metadata

- [ ] Review README, docs, plans, design references, examples, and comments for obsolete behavior, machine-specific instructions, unfinished internal notes, and contradictory install claims. Current product terminology is “Logs.”
- [ ] Review TNG demo and evaluation content, names, references, visual branding, and assets for the intended public use. Decide whether the first public release will include this fan-themed material, replace it with original fictional examples, or keep it out of the public repository. Do not imply Star Trek affiliation.
- [ ] Add a project license or state clearly that the source is currently all rights reserved. Review licenses and attribution for dependencies, bundled llama.cpp libraries, models, model conversions, fonts, and included assets. A model's license may differ from the code license.
- [ ] Review the app's data handling and privacy claims against implementation: audio and entries remain local, models are downloaded from their documented sources, and no inference service receives user content. Document any update checks, telemetry, or network behavior if present.
- [ ] Review the ad-hoc signing and quarantine-removal behavior. Explain the trust tradeoff and install only from the project's intended release source. Verify the cask removes quarantine from the intended app path only.
- [ ] Confirm the app name, bundle identifier, CLI name, version, support/contact route, minimum macOS version, Apple Silicon requirement, storage estimate, and known limitations agree across app, cask, README, and release notes.

## Phase 3 — Verify the release candidate

- [ ] Start from a clean checkout of the publication candidate and run the documented build, unit tests, coverage gate, and relevant evaluation suites.
- [ ] Build the `.app` and versioned ZIP using `scripts/build-app.sh`. Inspect the app bundle contents, executable architecture, bundled frameworks/libraries, resources, and absence of developer-only files.
- [ ] Install the cask from a temporary local tap and verify the app lands in Applications, `cl` resolves from PATH, the intended quarantine attribute is removed, and both GUI and CLI launch.
- [ ] Test the downloaded release archive and Homebrew flow on a clean macOS user account or another Apple Silicon Mac with no development tools or existing model cache. Confirm first launch, model download, recording, processing, search, and CLI operation.
- [ ] Test failure and recovery paths that affect release readiness: interrupted model download, unavailable network, insufficient disk space, permission errors, and an existing user data folder.
- [ ] Confirm generated ZIP checksum exactly matches the cask. Verify install/uninstall behavior and that uninstall leaves user data intact.
- [ ] Review screenshots, README commands, release notes, cask metadata, and archive one final time from the perspective of a new user.

## Phase 4 — Publish

- [ ] Choose the public source layout: make a fully reviewed sanitized repository public, or publish a separate sanitized repository and keep the current repository private.
- [ ] Tag the release and upload the versioned ZIP. Publish concise release notes with supported macOS/architecture, install options, model storage/download requirements, known limitations, and the ad-hoc signing/quarantine behavior.
- [ ] Update the Homebrew cask version, checksum, and release URL. Test the cask against the public release URL before announcing it.
- [ ] Publish the repository and release only after the Git-history gate and release-candidate checks are complete.
- [ ] Verify the documented tap/install commands from a clean machine using the public endpoints. Keep a rollback path by retaining the previous release archive and cask revision.

## Publication review record

For each gate, record the date, reviewed commit or tag, commands and machines used, and unresolved issues. Any new personal data discovery resets the affected privacy and history reviews; repeat the release build, checksum, and install checks if the archived bits or cask change.

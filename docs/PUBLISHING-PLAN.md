# Publication plan

## Goal and release boundary

CaptainsLog's GitHub repository is public, and release `v0.1.0` is available through GitHub Releases and the Homebrew tap at `vnglst/homebrew-captainslog`. The supported direct install is `brew install --cask vnglst/captainslog/captainslog`. Continue the review and cleanup gates below as post-publication maintenance. The app is ad-hoc signed, is not notarized, and the Homebrew cask removes the quarantine attribute from the installed app bundle. State that plainly wherever installation is described.

The initial release includes the macOS app, the `cl` CLI, bundled llama.cpp runtime, source code, build instructions, and synthetic TNG demo fixtures. The repository owner reviewed and approved the specific `2025-01-14 side project` evaluation recording and transcript copies; this approval does not cover other personal recordings.

## Phase 1 — Remove private material from the publication candidate

- [x] Remove `.claude/settings.local.json` from the working tree. It contained a machine-specific absolute path and a local cleanup permission. `.gitignore` now excludes this path so a local copy is not accidentally added again. The file remains in Git history and must be handled by the history review below.
- [x] Review `eval/transcribe/audio/2025-01-14 side project.m4a` and matching copies in transcription, cleanup, filename, and enrichment inputs/expected outputs. The repository owner reviewed them and approved retaining them in the public candidate. Keep this approval scoped to these reviewed files; review any new recordings or generated copies before publication.
- [ ] Search all tracked files, including hidden files and Git LFS objects if present, for names and email addresses other than the user's, absolute home paths, machine and account identifiers, credentials, tokens, private URLs, local config, and personal content. The user's name and email may remain.
- [x] Inspect images and binary files for visible paths, account names, device labels, recordings, screenshots, embedded metadata, and other identifying details. The seven design references remain conceptual (per owner approval); creator metadata, including the Trufo email, was stripped without changing image pixels. The images still contain illustrative paths, counts, microphone labels, version text, and “Field notes” UI labels; they are documented as concepts, not current product screenshots.
- [ ] Inspect demo and evaluation fixtures. Keep synthetic TNG examples clearly labeled as fictional, and verify no real personal content has entered a generated file or report.
- [ ] Check `.gitignore`, build scripts, test scripts, and CI workflows so config files, model caches, recordings, generated outputs, signing material, and build artifacts cannot be accidentally added.

### Git history gate

Removing a file from the latest tree does not remove it from existing commits. Before the repository becomes public, inspect every reachable branch, tag, and release for the same material. If private content appears in history, prepare a clean public history or a fresh sanitized public repository; preserve the current private repository as the archival source. Do not make the existing repository public until its complete reachable history and release assets have passed review.

## Phase 2 — Review content, rights, and project metadata

- [ ] Review README, docs, plans, design references, examples, and comments for obsolete behavior, machine-specific instructions, unfinished internal notes, and contradictory install claims. Current product terminology is “Logs.”
- [x] Review TNG demo and evaluation content, names, references, visual branding, and assets for the intended public use. The repository owner approved retaining the fan-themed material and reviewed literary fixtures; attribution and a no-affiliation statement are in `THIRD-PARTY-NOTICES.md`.
- [ ] Add a project license or state clearly that the source is currently all rights reserved. `THIRD-PARTY-NOTICES.md` inventories the bundled font, software, runtime models, and reviewed fixture attributions; verify its inventory and app-bundle copies on a release build. A model's license may differ from the code license.
- [ ] Review the app's data handling and privacy claims against implementation: audio and entries remain local, models are downloaded from their documented sources, and no inference service receives user content. Document any update checks, telemetry, or network behavior if present.
- [ ] Review the ad-hoc signing and quarantine-removal behavior. Explain the trust tradeoff and install only from the project's intended release source. Verify the cask removes quarantine from the intended app path only.
- [ ] Confirm the app name, bundle identifier, CLI name, version, support/contact route, minimum macOS version, Apple Silicon requirement, storage estimate, and known limitations agree across app, cask, README, and release notes.

### Third-party asset inventory

- `Sources/CaptainsLog/Resources/Antonio-VariableFont_wght.ttf` is the Antonio typeface by the Antonio Project Authors. Its SIL Open Font License 1.1 is now included alongside the font and in the app's third-party notices.
- `Sources/CSQLiteVec/` vendors sqlite-vec source. Its MIT and Apache-2.0 license texts are already present in that directory.
- Swift packages are pinned in `Package.resolved`; review and include applicable notices for the shipped dependency set. The app bundle also includes llama.cpp runtime libraries; preserve their license and notices in the bundle.
- Whisper Large-v2, Qwen 3.5 GGUF, and multilingual-e5-small GGUF are downloaded at runtime rather than committed as model files. Their source artifacts and stated license identifiers are listed in `THIRD-PARTY-NOTICES.md`; retain the source links and review again if the model versions change.
- `eval/transcribe/audio/world-war-z.m4a` and `durins-volk.m4a` are readings of published literary text. The repository owner approved retaining the reviewed files, and their underlying rights are attributed in `THIRD-PARTY-NOTICES.md`.
- The demo and `docs/tng-eval` use Star Trek names and settings. The repository owner approved keeping the fan-created examples; the notices state that CaptainsLog is independent and unaffiliated.

The seven design screenshots are in-repository reference images. The Trufo string found in their metadata was provenance metadata, not an app dependency or visible artwork; it has been removed from the local screenshot files.

## Phase 3 — Verify the release candidate

- [ ] Start from a clean checkout of the publication candidate and run the documented build, unit tests, coverage gate, and relevant evaluation suites.
- [ ] Build the `.app` and versioned ZIP using `scripts/build-app.sh`. Inspect the app bundle contents, executable architecture, bundled frameworks/libraries, resources, and absence of developer-only files.
- [ ] Install the cask from a temporary local tap and verify the app lands in Applications, `cl` resolves from PATH, the intended quarantine attribute is removed, and both GUI and CLI launch.
- [ ] Test the downloaded release archive and Homebrew flow on a clean macOS user account or another Apple Silicon Mac with no development tools or existing model cache. Confirm first launch, model download, recording, processing, search, and CLI operation.
- [ ] Test failure and recovery paths that affect release readiness: interrupted model download, unavailable network, insufficient disk space, permission errors, and an existing user data folder.
- [ ] Confirm generated ZIP checksum exactly matches the cask. Verify install/uninstall behavior and that uninstall leaves user data intact.
- [ ] Review screenshots, README commands, release notes, cask metadata, and archive one final time from the perspective of a new user.

## Phase 4 — Publish

- [x] Choose the public source layout: the existing `CaptainsLog` repository is public.
- [x] Verify `.github/workflows/release.yml`: the `v0.1.0` run passed on an Apple Silicon macOS runner, published the versioned ZIP as a GitHub Release asset, and committed its archive checksum and version to `Casks/captainslog.rb`.
- [x] Create the public `vnglst/homebrew-captainslog` tap with the initial `captainslog` cask. The supported direct install is `brew install --cask vnglst/captainslog/captainslog`.
- [ ] For each release, update `VERSION`, run the release checks, commit and push that version to the default branch, then create and push its matching `vMAJOR.MINOR.PATCH` tag. The workflow rejects tags if the tag, `VERSION`, and default branch disagree or if the tagged commit is not on the default branch.
- [ ] Review the workflow run and generated release notes. GitHub generates notes from repository history; edit them as needed to include supported macOS/architecture, model storage/download requirements, known limitations, and ad-hoc signing/quarantine behavior.
- [ ] Test the cask against the published release URL and test upgrading from the prior release before announcing it. The workflow updates the cask automatically, but it does not perform a clean-Mac install test.
- [x] Publish the repository and initial release. The repository owner made the repository public and approved release `v0.1.0` on 2026-09-25; remaining review and clean-Mac checks above are still open for follow-up.
- [ ] Verify the documented tap/install commands from a clean machine using the public endpoints. Keep a rollback path by retaining the previous release archive and cask revision.

The release workflow uses the standard `GITHUB_TOKEN` for source releases. To publish cask updates into the separate tap, add a fine-grained personal access token as the `HOMEBREW_TAP_TOKEN` Actions secret in `vnglst/CaptainsLog`. Grant it Contents read/write access to `vnglst/homebrew-captainslog`. This is separate from Developer ID signing, which is not used. GitHub-hosted macOS Actions minutes may use the account's included Actions allowance while the repository is private.

## Publication review record

For each gate, record the date, reviewed commit or tag, commands and machines used, and unresolved issues. Any new personal data discovery resets the affected privacy and history reviews; repeat the release build, checksum, and install checks if the archived bits or cask change.

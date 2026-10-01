# ADR-010: Publish Releases From Version Tags

**Status**: Accepted  
**Date**: 2026-09-25

## Context

Homebrew users need a stable archive URL and matching checksum for each version. Release publication should use GitHub infrastructure and keep both the source cask and the separate public tap current.

## Decision

Use a GitHub Actions workflow triggered by `vMAJOR.MINOR.PATCH` tags. The workflow checks that the tag matches `VERSION` and is on the default branch, runs tests, builds the macOS archive, publishes it as a GitHub release asset, calculates its SHA-256, updates the source cask, and mirrors that cask to `vnglst/homebrew-captainslog`.

The tap update uses the repository Actions secret `HOMEBREW_TAP_TOKEN`. It should be a fine-grained personal access token limited to the tap repository with Contents read and write access.

## Changelog and release preparation

`CHANGELOG.md` records every repository change under Unreleased and preserves
versioned release sections. Historical entries were backfilled from Git tags and
commits; the initial commit is the available baseline. CI requires a changelog
update for each push or pull request. Only generated cask version/checksum edits
matching a documented release are exempt from a separate changelog edit.

`swift scripts/release.swift [auto|patch|minor|major|version]` automates local release
preparation from a clean `main` checkout. It fetches the source branch/tags,
defaults to selecting the bump from Conventional Commits since the latest reachable
version tag (which must match `VERSION`), validates notes, and runs the tooling
tests, build, deterministic suite,
and fixture pipeline/stage evaluations sequentially with isolated config/data.
After successful checks it updates `VERSION`, rolls Unreleased into a dated
section, updates comparison links, and creates a release commit and annotated
tag. `--dry-run` previews notes without changes; `--publish` atomically pushes
the commit and tag to origin. Semantic evaluation review and installed-app QA
remain human checks; preparation alone does not establish release quality.

New commits follow Conventional Commits. Automatic selection uses the highest
impact: fix/perf → patch, feat → minor, and `!` or uppercase `BREAKING CHANGE:`
/ `BREAKING-CHANGE:` → major, except breaking changes advance minor while on
`0.x`. Other types do not trigger an automatic release. No releasable commits
means no version/file/commit/tag changes. Manual bumps or explicit versions
remain available for maintenance releases. Legacy messages are reported and
ignored for inference, preserving their reviewed changelog entries. Dry runs
use committed history and local tags without fetching. Generated release and
cask commits use `chore(release)` and do not trigger another automatic release.

The tag workflow requires a nonempty, dated section matching `VERSION` before
building. That section supplies the GitHub release body through `--notes-file`,
including on reruns, so GitHub and the repository share one release history.
A failed publication push leaves the local commit/tag for retry; do not bump
again to retry publication. The release entry covers the subsequent generated
cask version/checksum commit.

## Consequences

- A release begins by pushing a correctly versioned tag that is already on the default branch.
- The release archive, checksum, source cask, and tap cask are generated or updated through one workflow.
- The secret must be configured before the tap-publishing step can succeed.
- Release builds and tests run on GitHub-hosted macOS infrastructure.

## Verification: 2026-10-01

The standalone Swift release tool's note/version checks and Bash Git/CLI fixture
suite pass using synthetic changelogs and temporary Git repositories, including
a local bare remote for atomic publication. They cover version bumps, note
extraction and validation, changelog rollover, Git change coverage, generated
cask limits, cask metadata updates, dry runs, failed checks, dirty trees, existing
tags, and branch restrictions. Commit fixtures cover bump precedence, scoped and
case-insensitive types, both breaking footers, the 0.x policy, maintenance-only
history, tag/version mismatch, and automatic Git publication. Build/inference
checks are substituted in these
tooling fixtures; their sequential invocation and config isolation are asserted.
`swift scripts/release.swift --dry-run` selects a minor release after the
Conventional Commit amendment and produces 0.2.0 notes without a
version edit, commit, tag, or network publication. Both workflow YAML files parse
and `git diff --check` passes. The release tool uses Foundation and Git, with no
additional package dependencies. It also replaces the workflow's Python cask
update; all release-tooling commands are now Swift or Bash.

`swift build` passes. The full deterministic suite passes 193/200 tests; the seven
transcription/pipeline failures hit the existing zero-capacity disk guard (log:
`/tmp/captainslog-conventional-check.TqQM7A/tests.log`). The isolated repository fixture
pipeline also stops at that guard before inference
(`tmp/evals-2026-10-01_22-18-30_73649-73649/`). No stage output changed and no further
model suites were run after that failure. The release command deliberately blocks
commit/tag creation when these checks fail. Resolve the existing guard/environment
issue and complete semantic evaluation review before publishing. GitHub archive,
release-note publication, and tap updates remain unexecuted for this change.

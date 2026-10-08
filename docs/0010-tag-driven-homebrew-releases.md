# ADR-010: Publish Releases From Version Tags

**Status**: Accepted
**Date**: 2026-09-25

## Context

Homebrew users need a stable archive URL and matching checksum per version.
Publication must keep the source cask and separate public tap consistent.

## Decision

Publish through GitHub Actions on `vMAJOR.MINOR.PATCH` tags. Require the tag to
match `VERSION`, belong to the default branch, and have a nonempty dated changelog
section. Run release-tooling and deterministic tests before building, publishing
the archive and changelog notes, calculating SHA-256, and updating both casks.
Reruns refresh the same release notes.

Use `HOMEBREW_TAP_TOKEN`, a fine-grained token limited to Contents read/write
on `vnglst/homebrew-captainslog`, for tap publication.

Prepare releases with the standalone Swift release tool. Infer version bumps
from Conventional Commits, with manual overrides. Run tooling, build, and
isolated fixture/model checks sequentially before editing versions or creating
a commit/tag. Publish commit and tag atomically; retry a failed push without
bumping again. Maintenance-only history produces no automatic release.

## Consequences

- Archive, checksum, notes, and casks share one release workflow.
- CI runs for release tags; development checks run locally.
- Every repository change needs changelog coverage; generated cask-only commits
  are covered by their release entry.
- Publication requires the tap secret and GitHub-hosted macOS infrastructure.
- Semantic model review and installed-app QA remain human release checks.

## Supporting documents

- [Release commands, versioning rules, and checklist](../README.md#changelog-and-releases)

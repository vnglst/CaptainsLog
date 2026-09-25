# ADR-010: Publish Releases From Version Tags

**Status**: Accepted  
**Date**: 2026-09-25

## Context

Homebrew users need a stable archive URL and matching checksum for each version. Release publication should use GitHub infrastructure and keep both the source cask and the separate public tap current.

## Decision

Use a GitHub Actions workflow triggered by `vMAJOR.MINOR.PATCH` tags. The workflow checks that the tag matches `VERSION` and is on the default branch, runs tests, builds the macOS archive, publishes it as a GitHub release asset, calculates its SHA-256, updates the source cask, and mirrors that cask to `vnglst/homebrew-captainslog`.

The tap update uses the repository Actions secret `HOMEBREW_TAP_TOKEN`. It should be a fine-grained personal access token limited to the tap repository with Contents read and write access.

## Consequences

- A release begins by pushing a correctly versioned tag that is already on the default branch.
- The release archive, checksum, source cask, and tap cask are generated or updated through one workflow.
- The secret must be configured before the tap-publishing step can succeed.
- Release builds and tests run on GitHub-hosted macOS infrastructure.

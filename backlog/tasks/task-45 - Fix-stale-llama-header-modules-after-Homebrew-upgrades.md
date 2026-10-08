---
id: TASK-45
title: Fix stale llama header modules after Homebrew upgrades
status: Complete
assignee: []
created_date: '2026-10-07 15:25'
updated_date: '2026-10-08 17:03'
labels: []
dependencies: []
ordinal: 593.75
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
After Homebrew upgrades llama.cpp, the release app build can succeed while the following CLI build reuses a compiler module created from older native headers. The compiler then rejects the stale module and packaging fails. The module map currently points at a mutable Homebrew header alias, so the path stays the same even when the header contents change.

Resolve llama.cpp and GGML headers through their versioned package include paths. Verify that a shared compiler cache selects the correct headers across an upgrade, then build and package the release app and CLI with the current installed versions. This fixes stale header imports; replacing Homebrew with a pinned, reproducible native runtime remains separate work in TASK-28.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 CLlama resolves the llama header through the installed package include path rather than a hardcoded mutable header alias
- [x] #2 The release app and CLI build and the app archive/signature checks pass with current Homebrew headers
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Replace the mutable absolute header reference with a local include wrapper and explicit GGML package dependency. Check header selection with old/new/old synthetic package roots sharing a compiler cache. Verify release app and CLI packaging, signatures, bundled runtime paths and isolated fixture prompt rendering.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
The module map now uses a local llama include wrapper resolved through pkg-config, with an explicit dependency on the separate GGML include path. Synthetic old/new/old header roots select correctly with a shared compiler cache.

The real release build succeeded with llama.cpp 0.6.0 and GGML 0.26.0, produced the app/CLI archive, passed both signatures and used bundled runtime-library paths. The bundled CLI responded to ping and rendered an enrichment prompt from a repository fixture with isolated configuration. No model inference, installed-app replacement or personal data was used.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Release app and CLI packaging now use the correct installed headers after upgrades. Shared-cache header selection, archive, signatures and isolated CLI checks pass. Pinned runtime builds remain TASK-28; the owner has marked this fix Complete.
<!-- SECTION:FINAL_SUMMARY:END -->

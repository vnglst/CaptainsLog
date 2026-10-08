---
id: TASK-28
title: Use a pinned project-built llama runtime in release builds
status: Next
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 16:49'
labels:
  - distribution
dependencies: []
documentation:
  - docs/0005-use-libllama-c-api-for-text-inference.md
  - docs/0006-bundle-llama-runtime-in-app.md
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Replace mutable Homebrew native dependencies with a pinned, reproducible runtime for source and release builds. TASK-45 handles the immediate stale-header repair.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pin llama.cpp, GGML and required dependencies to immutable revisions or verified checksums; match headers and libraries.
- [ ] #2 Clean builds succeed without Homebrew native libraries and ignore unrelated installed versions.
- [ ] #3 Record toolchain, macOS 26.0 target, architecture and options; two clean builds match unsigned artifacts or test documented nondeterminism.
- [ ] #4 Packaged app/CLI bundle the pinned runtime, target macOS 26.0, pass signatures and fixture smoke checks, and contain no Homebrew runtime paths.
- [ ] #5 Document upgrades/licenses; automate checks against system-library fallback.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Owner selected reproducible native builds after the Homebrew header upgrade broke packaging.
<!-- SECTION:NOTES:END -->

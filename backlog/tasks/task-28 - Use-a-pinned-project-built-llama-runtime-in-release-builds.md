---
id: TASK-28
title: Use a pinned project-built llama runtime in release builds
status: Next
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:03'
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
Source and release builds currently resolve llama.cpp, GGML and libomp from mutable Homebrew installations. A 2026-10-07 header upgrade invalidated a precompiled Swift module during app/CLI packaging, demonstrating that the same checkout can build differently or fail after unrelated system updates. Replace Homebrew runtime/header paths with a pinned project-built or vendored native runtime targeting macOS 26.0. Record the compiler/toolchain and build configuration needed to reproduce compatible artifacts. See ADR-005 and ADR-006; TASK-45 handles the immediate stale-header repair.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 llama.cpp, GGML and required native runtime dependencies are pinned to immutable source revisions or checksum-verified artifacts, with matching headers and libraries
- [ ] #2 A documented clean build succeeds without an installed Homebrew llama.cpp, GGML or libomp and ignores unrelated system versions of those libraries
- [ ] #3 The native toolchain, deployment target, architecture and build options are recorded; two clean builds with the same declared inputs produce matching unsigned runtime artifacts or document and test any unavoidable nondeterminism
- [ ] #4 The packaged app and CLI bundle the pinned runtime, target macOS 26.0, pass signature and fixture smoke checks, and contain no Homebrew runtime paths
- [ ] #5 Dependency upgrade instructions, licenses and automated checks prevent accidental fallback to system-installed native libraries
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Owner selected this work for Next on 2026-10-07 after the release build reused a stale Homebrew llama header module. Scope is reproducible native-runtime builds; immediate header import repair is tracked separately in TASK-45.
<!-- SECTION:NOTES:END -->

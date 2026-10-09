---
id: TASK-28
title: Use the same pinned native runtime for development and release builds
status: Complete
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-09 19:49'
labels:
  - distribution
dependencies: []
ordinal: 74.21875
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Local development and release builds currently resolve llama.cpp, GGML and libomp from mutable Homebrew installations. A 2026-10-07 header upgrade invalidated a precompiled Swift module during app/CLI packaging, demonstrating that the same checkout can build differently or fail after unrelated system updates.

Use the same pinned native libraries and matching headers for local development and release builds, targeting macOS 26.0. The owner permits verified prebuilt libraries and requires reproducibility. Record the compiler/toolchain and build configuration needed to reproduce compatible artifacts. ADR-005 and ADR-006 describe the current runtime integration; TASK-45 handled the immediate stale-header repair.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 llama.cpp, GGML and required native runtime dependencies are pinned to immutable source revisions or checksum-verified artifacts, with matching headers and libraries; verified prebuilt libraries are permitted.
- [x] #2 Local development and release builds use the same pinned native libraries. Documented clean builds succeed without Homebrew llama.cpp, GGML or libomp and ignore unrelated system versions of those libraries.
- [x] #3 The native toolchain, deployment target, architecture and build options are recorded; two clean builds with the same declared inputs produce matching unsigned runtime artifacts or document and test any unavoidable nondeterminism.
- [x] #4 The packaged app and CLI bundle the pinned runtime, target macOS 26.0, pass signature and fixture smoke checks, and contain no Homebrew runtime paths.
- [x] #5 Dependency upgrade instructions, licenses and automated checks prevent accidental fallback to system-installed native libraries.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Owner selected this work for Next on 2026-10-07 after the release build reused a stale Homebrew llama header module. Scope is reproducible native-runtime builds; immediate header import repair is tracked separately in TASK-45.

Owner clarification on 2026-10-08: verified prebuilt libraries are acceptable; local development and release builds must use the same pinned libraries, with reproducibility required.
<!-- SECTION:NOTES:END -->

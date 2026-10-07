---
id: TASK-45
title: Fix stale llama header modules after Homebrew upgrades
status: Verify
assignee: []
created_date: '2026-10-07 15:25'
updated_date: '2026-10-07 15:36'
labels: []
dependencies: []
ordinal: 45000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The release app build succeeds but the following CLI build can reuse a precompiled CLlama module made from older Homebrew headers. The supplied log reports llama.h changing from 85393 to 89978 bytes after llama.cpp 0.5.0 to 0.6.0. The module map hardcodes the mutable /opt/homebrew/include header instead of using the versioned pkg-config include path.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 CLlama resolves the llama header through the installed package include path rather than a hardcoded mutable header alias
- [x] #2 The release app and CLI build and the app archive/signature checks pass with current Homebrew headers
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Replace the absolute Homebrew llama.h module-map entry with a local include wrapper that resolves through existing pkg-config include flags. 2. Verify versioned header selection using two synthetic header roots and a shared module cache. 3. Run the release app packaging command while inference is idle, inspect compiler outputs/runtime links and signatures, and record the result without changing main-thread source work or personal data.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Initial header-selection fixture passed old/new/old roots with a shared cache. Native release rebuild exposed a missing transitive include dependency: Homebrew llama.pc exports only the llama.cpp include directory, although llama.h includes separate GGML headers. Added an explicit CGGML system-library dependency using ggml.pc alongside the CLlama wrapper; no new runtime or third-party package is introduced.

Verification completed: old/new/old synthetic llama+GGML header roots selected correctly with a shared compiler cache. The real release build resolved llama.cpp 0.6.0 and GGML 0.26.0, built CaptainsLogApp (95s) and cl (85s), assembled dist/CaptainsLog.app, passed app/CLI signature checks and produced dist/CaptainsLog-0.1.2.zip. Bundled cl ping and enrich --print-prompt on eval/enrich/input/03_mixed_topics.md passed with an isolated temporary config/data path. CLI runtime references use bundled @rpath libraries. No model inference, installed-app replacement or personal data was used for these checks. Main-thread eval/source changes are untouched. TASK-28 was separately moved to Next at the owner request for pinned, reproducible native builds.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Replace the hardcoded mutable Homebrew llama.h alias with a local CLlama include wrapper and declare the existing GGML pkg-config dependency explicitly. Synthetic shared-cache version-selection checks and the complete release app/CLI packaging command pass, including signatures, archive creation and isolated bundled-CLI fixture prompt smoke. Source builds still use Homebrew today; pinned reproducible runtime builds are TASK-28, now Next.
<!-- SECTION:FINAL_SUMMARY:END -->

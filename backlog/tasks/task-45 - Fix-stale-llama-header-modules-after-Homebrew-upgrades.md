---
id: TASK-45
title: Fix stale llama header modules after Homebrew upgrades
status: Verify
assignee: []
created_date: '2026-10-07 15:25'
updated_date: '2026-10-08 16:49'
labels: []
dependencies: []
ordinal: 45000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Prevent release CLI builds reusing CLlama modules compiled against older Homebrew headers.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Resolve llama headers through versioned package includes instead of the mutable absolute alias.
- [x] #2 Release app/CLI builds, archive and signatures pass with current headers.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Use a local include wrapper and explicit GGML pkg-config dependency; verify shared-cache header selection and packaging.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
[Evidence](../../docs/testing-verification.md#native-header-and-release-packaging-checks-2026-10-07): synthetic old/new/old headers pass; llama.cpp 0.6.0/GGML 0.26.0 package successfully. Archive, signatures, bundled runtime links, ping and isolated fixture prompt smoke pass. No inference, installed-app replacement or personal data used.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed stale imports; pinned reproducible runtime remains TASK-28.
<!-- SECTION:FINAL_SUMMARY:END -->

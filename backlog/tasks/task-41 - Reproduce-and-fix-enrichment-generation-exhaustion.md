---
id: TASK-41
title: Reproduce and fix enrichment generation exhaustion
status: Complete
assignee: []
created_date: '2026-10-05 17:53'
updated_date: '2026-10-08 16:59'
labels: []
dependencies: []
ordinal: 2375
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Reproduce and fix native enrichment context exhaustion. Use fixtures or the explicitly supplied workspace copy; never access original personal folders/context or commit supplied content/traces.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Fixture-backed CLI reproduces exhaustion and records failure behavior.
- [x] #2 Fixed case produces valid grounded metadata and preserves the body.
- [x] #3 Review existing fixtures and deterministic checks with concrete semantic findings.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Reproduce, trace, apply enrichment-only repetition protection and completion limits, then verify sequentially.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
[Evidence](../../docs/testing-verification.md#enrichment-entity-list-loop-reproduction-and-fix-2026-10-07): 9,254 prompt + 9,434 output tokens exhausted context. Final budget: 4,096. Final build/154 unit checks passed; 209 tests and transcript-seeded continuation/resume/search passed at 2,048. Full audio gate failed in Whisper (DRAFT-1).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed runaway generation. Supplied input/four fixtures complete; finite duplicates, omissions and date errors remain documented. Installed app unchanged.
<!-- SECTION:FINAL_SUMMARY:END -->

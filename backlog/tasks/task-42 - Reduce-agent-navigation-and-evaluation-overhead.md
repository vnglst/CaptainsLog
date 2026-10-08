---
id: TASK-42
title: Reduce agent navigation and evaluation overhead
status: Verify
assignee:
  - '@codex'
created_date: '2026-10-07 14:38'
updated_date: '2026-10-08 16:49'
labels: []
dependencies: []
references:
  - scripts/run-evals.sh
  - scripts/validate-eval-run.sh
documentation:
  - docs/0005-use-libllama-c-api-for-text-inference.md
  - docs/0007-framework-free-test-coverage.md
type: enhancement
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Reduce evaluation/navigation overhead; coordinate public-doc scope with TASK-22. [Rationale/history](../../docs/evaluation-runner-history.md).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 One isolated execution/naming entry point; skills retain review guidance.
- [x] #2 Stage/case selection preserves full release gates.
- [x] #3 Linked source map covers UI, launcher, coordinator, inference, config, CLI, tests and legacy boundaries.
- [x] #4 Per-case evidence includes input, expected/generated output, validation and optional baselines.
- [x] #5 Validation rejects malformed metadata/types/values and changed source bodies.
- [x] #6 Sequential model reuse isolates case contexts without generation changes.
- [x] #7 Concise reports capture omissions, hallucinations, regressions/improvements; owner semantic judgment remains required.
- [x] #8 Metadata records model, prompt/fixture hashes, revision/dirty state and generation settings.
- [x] #9 Fix navigation, troubleshooting and local installation/rollback/build identification with TASK-22.
- [x] #10 Fixture-backed timing/effort comparisons distinguish measurements from estimates.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Consolidate runner, validation/evidence and navigation; verify sequentially.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Build/209 tests, 66 evaluator checks, enrichment checks and focused native integration passed. Dutch filename date failure persists; speedup unproven.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented; [verification/limits](../../docs/testing-verification.md). Owner review pending.
<!-- SECTION:FINAL_SUMMARY:END -->

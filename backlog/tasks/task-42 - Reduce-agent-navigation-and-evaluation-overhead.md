---
id: TASK-42
title: Reduce agent navigation and evaluation overhead
status: Complete
assignee:
  - '@codex'
created_date: '2026-10-07 14:38'
updated_date: '2026-10-08 17:03'
labels: []
dependencies: []
references:
  - scripts/run-evals.sh
  - scripts/validate-eval-run.sh
documentation:
  - docs/0005-use-libllama-c-api-for-text-inference.md
  - docs/0007-framework-free-test-coverage.md
type: enhancement
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Agents spend too much time finding source files, discovering evaluation commands and assembling results for review. Stage instructions contain duplicated or stale commands, and focused changes can require running unrelated model evaluations.

Provide one documented entry point for evaluating a stage or a single fixture. Keep the existing full pipeline and release checks. Assemble each case’s input, expected result, generated result and validation into a review bundle, with enough model and configuration information to compare runs. Reuse the loaded text model sequentially while keeping each case’s context separate.

Add a source map, repair misleading navigation and troubleshooting advice, and explain isolated local installation and rollback. Coordinate these targeted documentation corrections with TASK-22, which retains the broader public-documentation review. Use repository fixtures and isolated data throughout. Measure representative elapsed time and effort; do not present estimated savings as proven improvements.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 One documented execution entry point owns isolated fixture runs and output naming; stage skills reference it and retain only review guidance without conflicting recipes.
- [x] #2 One stage or case can be evaluated independently; required full pipeline and suite release gates remain available.
- [x] #3 A compact linked source map identifies active UI/Settings, launcher, coordinator, inference, config, CLI and tests, embedded types and legacy UI boundaries.
- [x] #4 Review evidence groups input, expected/generated output, validation and optional baseline differences for each case.
- [x] #5 Mechanical validation covers malformed output, enrichment list item types/required values and source-body preservation; validator failures fail the run.
- [x] #6 Multi-case text evals reuse a loaded model sequentially without case-context leakage or unintended generation changes.
- [x] #7 Concise shared reporting captures concrete omissions, hallucinations, regressions and improvements; semantic review and owner judgment remain required.
- [x] #8 Run metadata records actual model identity, prompt/fixture hashes, code revision and dirty state, and generation settings for reproducible comparisons.
- [x] #9 Active-suite navigation, stale troubleshooting/source-path advice and local development installation/rollback/build identification are addressed in coordination with TASK-22.
- [x] #10 Representative before/after effort and elapsed-time evidence distinguishes measured savings from estimates; applicable checks use repository fixtures.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Provide a shared runner for isolated fixture execution, stage/case selection and saved-result validation.
2. Assemble review evidence and run metadata, and reuse model weights sequentially with a fresh context per case.
3. Improve source navigation and local development instructions.
4. Verify CLI behavior, model output and measured timing; record limitations for owner review.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
The consolidated runner supports stage/case selection, isolated configuration, sequential text-model reuse, strict output validation, reproducibility metadata and per-case review bundles. Source navigation and local installation/rollback guidance are included. Integration into main preserves the newer per-case enrichment dates, seeds, diagnostics and fixture checks.

Build and 209 deterministic tests passed. Evaluator tooling passed 66 checks on both installed Ruby versions; 25 enrichment validation checks and six CLI seed boundaries passed. The full native fixture pipeline completed and its corrected saved-output checks pass 5/5. Eight native filename cases were manually reviewed; one Dutch case still ignores the supplied date and is correctly rejected. The merged fictional enrichment case completes with valid bounded metadata and exact body preservation, but shortens its artificial name.

Measured filename time was 95.98 seconds for separate calls versus 106.54 seconds for the complete new runner, including hashing, build and review assembly. This does not establish an end-to-end speedup or agent-token savings. Full native suites were not repeated for the integration.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Integrated on main with focused evaluation, assembled review evidence, strict validation and clearer project navigation. Verification and known limits are summarized above. TASK-22 retains broader documentation review; the owner has marked this task Complete.
<!-- SECTION:FINAL_SUMMARY:END -->

---
id: TASK-42
title: Reduce agent navigation and evaluation overhead
status: Verify
assignee:
  - '@codex'
created_date: '2026-10-07 14:38'
updated_date: '2026-10-07 20:07'
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
Reduce agent time and token overhead identified in the last ten CaptainsLog coding sessions. Repeated discovery, guessed source filenames and duplicated/stale evaluation recipes obscure the existing runner and semantic review workflow.

Priorities, in order: single evaluation execution entry point; stage/case selection; compact source map; assembled review evidence; stronger mechanical validation; sequential model reuse; concise shared review format; reproducibility metadata; corrected troubleshooting/navigation and local deployment instructions. Coordinate public-doc corrections with TASK-22. Deliver incrementally and split focused implementation tasks when selected.

Observed defects include missing --input in cleanup/enrich/filename skill examples, cleanup reading an output name without its generated timestamp, UI docs pointing at the launcher rather than FieldNotesContentView.swift, and outdated ANE/llama-cli/41-layer troubleshooting. Agents repeatedly guessed nonexistent source files. Preserve isolated config/data, repository eval fixtures, sequential inference, existing full release gates and human semantic judgment.

Gross estimated savings per relevant occurrence (agent tokens; elapsed time), not measured and not additive:
1. Execution entry point: 2000-6000; 2-6 min per eval session.
2. Stage/case selection: 3000-15000; 5-30+ min per focused iteration that otherwise runs/reviews full suites.
3. Source map: 1000-5000; 1-5 min per unfamiliar-code session.
4. Evidence bundle: 2000-8000; 2-8 min per suite review.
5. Validation: 500-3000; 1-5 min per run with mechanical failures.
6. Model reuse: 0-500; 1-5 min per multi-case suite.
7. Concise reports: 1000-5000; 1-4 min per suite report.
8. Metadata: 1000-6000; 2-10 min per later reproduction/comparison.
9. Doc repairs: 1000-5000; 2-10 min per affected session.
Combined hypothesis for a focused eval iteration: 5000-15000 tokens and 5-20 minutes saved. Measure rather than treating these estimates as guarantees.

ADR assessment: no new ADR now. These reversible improvements implement ADR-005 shared serialized inference and ADR-007 automated checks plus semantic review. Reassess if implementation changes runtime, quality-gate authority or durable artifact contracts.
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
1. Consolidate suite selection, isolated configuration and artifact naming behind scripts/run-evals.sh; preserve pipeline/release modes.
2. Add a sequential text batch CLI using existing stage APIs and fresh inference contexts, plus run metadata, assembled review evidence and strict saved-output validation.
3. Add deterministic runner/validator regression checks and compare representative fixture timings; run build, deterministic tests and sequential model fixture checks.
4. Replace stage execution recipes with shared review guidance; add source navigation and scoped troubleshooting/local deployment corrections coordinated with TASK-22.
5. Record semantic findings, measured limits and supported acceptance criteria; hand off in Verify when checks finish.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Initial inspection: run-evals.sh reloads Qwen per case and requires both models even for categorize; validator hard-codes suite output count and does not propagate comparison failures. TASK-22 remains To Do; TASK-42 will correct only active evaluation/navigation/runtime/development advice and note this boundary for TASK-22.

Implemented one runner entry point with stage/case/list/baseline/saved-validation modes, isolated configs and exact selected model pinning. Added hidden sequential eval-batch transport using existing stage APIs with fresh per-call LLM contexts/samplers; production generation settings and prompts are unchanged. Added model/prompt/fixture/source/binary/runtime provenance, assembled input/expected/generated evidence and preserved concise authored reports.
Verification: swift build passed; full swift run run-tests passed 209/209. Final ruby scripts/test-evals.rb passed 62 checks under both Ruby 4.0.7 and macOS Ruby 2.6.10, including combined --all release mode, stage/case selection, missing models/artifacts, failed validation, metadata, baselines and report preservation. Native invalid batch exits 64 before loading a model. Legacy category saved validation passed 4/4; shell syntax, links and git diff --check passed.
Native evidence: eight standalone filename calls took 95.98 s. New runner took 106.54 s including hashing/build/evidence; reported batch load plus stage-call durations sum to 92.73 s (different timing scope). One ordered trial does not establish a speedup or agent-token savings. Both filename runs fail the supplied-date requirement for the Dutch case (spoken Jan 14 overrides supplied Jan 15); all slugs were manually reviewed against input/expected/baseline.
Full native fixture pipeline completed in tmp/task42-pipeline; native artifact generation, completed resume and search ran. Initial adapter validation failed because markers store stems without .md; corrected artifact resolution and explicit Bash 3.2 assertion failures are covered by regression checks. Corrected saved validation passes 5/5; resolved native artifacts, unchanged resume hashes and actual enriched-path search readback pass. Audio inference was not repeated for the adapter-only correction. Full 23-case native suites were not repeated; their orchestration/combined release gate is covered with subprocess fixtures.
Semantic limits: transcription retains vollendje, liefdelokaal and science/site-project errors; cleanup repairs the first two but retains science project, uses three long paragraphs and several spoken connectors. Enrichment omits large language model from entities and explicit original-audio/cross-computer details from its summary. No production quality fix or new bug task was added. Detailed evidence and measured effort limits are recorded in ADR-007; per-case reports remain in ignored run bundles.
Source map, shared evaluation guidance and isolated local install/rollback/build-identification docs added. Corrected active UI paths, TNG reference-versus-suite navigation and stale runtime troubleshooting; TASK-22 contains the public-doc coordination boundary. No architectural decision changed, so no new ADR was needed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Consolidated fixture execution and review behind run-evals.sh with focused selection, shared-model text batches, strict validation, provenance and per-case evidence. Added source/development navigation and corrected stale recipes. Build and 209 deterministic tests passed; 62 evaluator checks passed on both Ruby versions; native pipeline saved validation passed 5/5. Reviewed eight native filename cases; Dutch supplied-date failure remains correctly rejected. Timing evidence does not establish an end-to-end speedup. See ADR-007 for semantics, measurements and limits. Ready for owner review; broader public-doc review remains TASK-22.
<!-- SECTION:FINAL_SUMMARY:END -->

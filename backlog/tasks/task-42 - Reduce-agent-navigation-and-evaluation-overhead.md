---
id: TASK-42
title: Reduce agent navigation and evaluation overhead
status: To Do
assignee: []
created_date: '2026-10-07 14:38'
labels: []
dependencies: []
references:
  - scripts/run-evals.sh
  - scripts/validate-eval-run.sh
documentation:
  - docs/0005-use-libllama-c-api-for-text-inference.md
  - docs/0007-framework-free-test-coverage.md
type: enhancement
ordinal: 42000
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
- [ ] #1 One documented execution entry point owns isolated fixture runs and output naming; stage skills reference it and retain only review guidance without conflicting recipes.
- [ ] #2 One stage or case can be evaluated independently; required full pipeline and suite release gates remain available.
- [ ] #3 A compact linked source map identifies active UI/Settings, launcher, coordinator, inference, config, CLI and tests, embedded types and legacy UI boundaries.
- [ ] #4 Review evidence groups input, expected/generated output, validation and optional baseline differences for each case.
- [ ] #5 Mechanical validation covers malformed output, enrichment list item types/required values and source-body preservation; validator failures fail the run.
- [ ] #6 Multi-case text evals reuse a loaded model sequentially without case-context leakage or unintended generation changes.
- [ ] #7 Concise shared reporting captures concrete omissions, hallucinations, regressions and improvements; semantic review and owner judgment remain required.
- [ ] #8 Run metadata records actual model identity, prompt/fixture hashes, code revision and dirty state, and generation settings for reproducible comparisons.
- [ ] #9 Active-suite navigation, stale troubleshooting/source-path advice and local development installation/rollback/build identification are addressed in coordination with TASK-22.
- [ ] #10 Representative before/after effort and elapsed-time evidence distinguishes measured savings from estimates; applicable checks use repository fixtures.
<!-- AC:END -->

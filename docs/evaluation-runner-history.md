# Evaluation runner rationale and implementation history

Supporting history for [TASK-42](../backlog/tasks/task-42%20-%20Reduce-agent-navigation-and-evaluation-overhead.md).
This records historical proposals and observations, including unmeasured savings
estimates. Current execution guidance is in [EVALUATIONS.md](EVALUATIONS.md);
open scope and acceptance remain in the task.

## Original scope and estimates

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

## Implementation record

Initial inspection: run-evals.sh reloads Qwen per case and requires both models even for categorize; validator hard-codes suite output count and does not propagate comparison failures. TASK-22 remains To Do; TASK-42 will correct only active evaluation/navigation/runtime/development advice and note this boundary for TASK-22.

Implemented one runner entry point with stage/case/list/baseline/saved-validation modes, isolated configs and exact selected model pinning. Added hidden sequential eval-batch transport using existing stage APIs with fresh per-call LLM contexts/samplers; production generation settings and prompts are unchanged. Added model/prompt/fixture/source/binary/runtime provenance, assembled input/expected/generated evidence and preserved concise authored reports.
Verification: swift build passed; full swift run run-tests passed 209/209. Final ruby scripts/test-evals.rb passed 62 checks under both Ruby 4.0.7 and macOS Ruby 2.6.10, including combined --all release mode, stage/case selection, missing models/artifacts, failed validation, metadata, baselines and report preservation. Native invalid batch exits 64 before loading a model. Legacy category saved validation passed 4/4; shell syntax, links and git diff --check passed.
Native evidence: eight standalone filename calls took 95.98 s. New runner took 106.54 s including hashing/build/evidence; reported batch load plus stage-call durations sum to 92.73 s (different timing scope). One ordered trial does not establish a speedup or agent-token savings. Both filename runs fail the supplied-date requirement for the Dutch case (spoken Jan 14 overrides supplied Jan 15); all slugs were manually reviewed against input/expected/baseline.
Full native fixture pipeline completed in tmp/task42-pipeline; native artifact generation, completed resume and search ran. Initial adapter validation failed because markers store stems without .md; corrected artifact resolution and explicit Bash 3.2 assertion failures are covered by regression checks. Corrected saved validation passes 5/5; resolved native artifacts, unchanged resume hashes and actual enriched-path search readback pass. Audio inference was not repeated for the adapter-only correction. Full 23-case native suites were not repeated; their orchestration/combined release gate is covered with subprocess fixtures.
Semantic limits: transcription retains vollendje, liefdelokaal and science/site-project errors; cleanup repairs the first two but retains science project, uses three long paragraphs and several spoken connectors. Enrichment omits large language model from entities and explicit original-audio/cross-computer details from its summary. No production quality fix or new bug task was added. Detailed evidence and measured effort limits are recorded in the [testing verification history](testing-verification.md); per-case reports remain in ignored run bundles.
Source map, shared evaluation guidance and isolated local install/rollback/build-identification docs added. Corrected active UI paths, TNG reference-versus-suite navigation and stale runtime troubleshooting; TASK-22 contains the public-doc coordination boundary. No architectural decision changed, so no new ADR was needed.

Integration requested by owner on 2026-10-08: merged newer main enrichment controls into the consolidated runner, preserving per-case dates/times/seeds, diagnostics, synthetic fixture fingerprints, bounded metadata and unique-name gates. Retained --enrich and legacy enrichment-only validation. Merged build and full deterministic suite pass (209/209); 66 evaluator checks pass on Ruby 4.0.7 and system Ruby 2.6.10; all 25 enrichment validator checks and six CLI seed boundaries pass. Native focused integration check pending before default main checkout update.

Native merged-run check completed: tmp/task42-merge-enrich passes the fictional long-name case with supplied 2025-02-18 / 20:30 / seed 42, per-case diagnostics and EOG after 177 tokens. Strict structure, source fingerprint and exact body pass. Manual review retains main’s shortened-name and omitted-tag/summary-detail limits; recorded in the [testing verification history](testing-verification.md) and the run report. Full native suites/audio pipeline were not repeated for transport integration. Task remains Verify for owner review.

---
id: TASK-41
title: Reproduce and fix enrichment generation exhaustion
status: Verify
assignee: []
created_date: '2026-10-05 17:53'
updated_date: '2026-10-07 15:06'
labels: []
dependencies: []
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Enrichment again exhausted its allocated context: the screenshot reports 9376 prompt tokens and 9568 output tokens filling 18944 tokens. The earlier prompt mitigation did not reproduce or eliminate the failure. First reproduce through the CLI, then fix and verify it. Use repository eval fixtures and the Markdown copy explicitly supplied by the owner for this reproduction; never access original personal data folders or speaker context.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A fixture-backed CLI run reproduces enrichment exhaustion and records the generated failure behavior
- [x] #2 The reproduced case completes with valid grounded metadata and preserves the source body after the fix
- [x] #3 Existing enrichment fixtures and relevant deterministic checks are reviewed with concrete semantic findings
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Native reproduction and bounded trace completed using only the authorized workspace copy and isolated context. 2. Enrichment-only DRY sequence protection, strict completion and prompt clarifications implemented and verified with a 2048-token trial budget. 3. At owner review, raise the final budget to 4096 for metadata headroom and recheck build/unit tests, supplied input and all four enrichment fixtures sequentially. 4. Record final non-content evidence and quality limits; original personal data folders remain prohibited and supplied content/traces stay outside Git. Full audio gate has a separate Whisper assertion; transcript-seeded shared-model continuation/resume/search already passed.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Baseline mixed-topics fixture repeated 30 times (22228 bytes) completed successfully with grounded short metadata. Dutch side-project fixture repeated 8 times, seed 42, also completed (6955 prompt tokens, 14080 context). Temporary CL_FIXTURE_TRACE and CL_FIXTURE_SEED instrumentation is used only for synthetic CLI trials and will be removed from the final change. Testing a 9503-token Dutch prompt next.

Ten standalone native enrichment runs have completed without exhaustion: six long fixture-derived inputs (prompt counts 6955, 9503 twice, 11667, 8659, plus an untraced mixed-topics run) and all four standard enrichment inputs. All emitted parseable YAML and preserved the input body. Semantic review found existing omissions, the Dutch date being taken from the input instead of the supplied date, and Picard being misclassified as an entity in the standard Dutch case. Installed app prompt SHA-256 matches repository; libllama/libggml/libggml-base Mach-O UUIDs match Homebrew runtime. Now checking the installed cl resume path from categorizing with one reused Qwen container. Temporary instrumentation has been removed from source; no production behavior change selected because native exhaustion has not been reproduced.

Installed bundled cl resume also completed categorization, filename and enrichment with one reused Qwen container on the 31678-byte Dutch synthetic input. Its YAML parsed and body was unchanged; supplied-date override was again ignored. Eleven native enrichment attempts in total did not reproduce exhaustion. Dated evidence is in ADR-007; all four standard per-case reports have prefix 2026-10-05_20-09-17_Qwen3.5-9B-Q4_K_M. No acceptance criteria are checked and task remains Next. Exact failing-input reproduction would require explicit owner authorization to override the repository prohibition on using personal transcripts/context.

After removing temporary instrumentation, swift build passed and swift run run-tests --unit passed 152/152. Checked AC 3 for the baseline semantic review and deterministic checks only. AC 1 (native exhaustion reproduction) and AC 2 (verified fix) remain unmet; status remains Next. Final source and prompt diff is empty.

2026-10-07: Owner explicitly declined any access to personal data folders or speaker context and supplied a Markdown copy in the repository for reproduction. Authorization is limited to that copy. Use isolated config and empty context; do not request or read the original data. The supplied source and generated output will remain outside Git.

The provided workspace Markdown is 30113 bytes, 91 lines, with no frontmatter. The installed CLI baseline uses date 2026-10-05, recording time 16:44, isolated config/data and empty speaker context. Sandboxed execution failed before inference with Failed to create llama context; an approved outside-sandbox retry is running to permit Metal GPU access. No access to original app data or context was requested or performed. Temporary source tracing is prepared but has not been built or used; production behavior is not changed yet.

2026-10-07 native reproduction confirmed: the installed CLI, unchanged prompt/sampler, provided workspace Markdown and empty isolated context failed with Generation exhausted its allocated 18688-token context after a 9254-token prompt and 9434 output tokens. No output file was written. A one-second stack sample confirmed the native token sampling loop. Counts differ from the screenshot because this isolated run has no original speaker context; no original data folders were accessed. Next capture a bounded diagnostic prefix without changing normal production behavior, then choose and validate a fix.

The bounded diagnostic trace reproduces a specific runaway sequence: initial YAML fields are plausible, then one project name repeats indefinitely as entities list items before any summary. Investigating DRY sequence-level repetition protection for enrichment, which can preserve repeated short YAML punctuation rather than penalizing every reused token as previous presence-penalty trials did. Correction: the exact cause of the 122-token difference from the screenshot is unverified; the isolated reproduction intentionally excludes original speaker context.

The first production sampler trial completed the supplied input with EOG, parseable-looking metadata and exact body preservation instead of exhausting context. Semantic review found two repeated entity entries and an unsupported side-project category. Clarifying the existing unique-name/cross-field and professional-work category prompt rules before final fixture evaluation. Build passed; unit suite 154/154 and full deterministic suite 209/209 passed. No automatic retry has been added: the targeted sequence protection already completed the failing input; retain the strict budget rather than broadening recovery without evidence.

Final provided-input run completes with EOG, valid YAML and string-only lists, supplied date/time, exact source-body preservation, work category and a grounded three-sentence summary. It still repeats a project identifier twice in entities and omits two organizations used in illustrative examples; these finite extraction-quality limits are recorded separately from the resolved runaway loop. All four final enrichment fixtures completed; per-case reports use prefix 2026-10-07_16-52-00_Qwen3.5-9B-Q4_K_M. Work omits documentation; personal omits beach and replaces food with grounded dining; mixed matches expected; Dutch correctly classifies the named fictional person but omits side-projects, collapses raw/polished transcript distinctions and still takes the spoken date instead of the supplied date. The full fixture audio pipeline is running sequentially.

Final integration evidence: the full audio fixture pipeline rebuilt successfully but aborted in unchanged Whisper transcription (exit 134, MPSGraphTensorData shape/strides assertion), before enrichment. Saved separately as DRAFT-1. Seeding only the repository expected transcript allowed resume from cleanup: cleanup, categorization, filename and enrichment passed with one reused Qwen model; correct side_project category and grounded filename, valid enriched YAML and exact cleaned-body preservation. Completed resume artifact hashes were unchanged; search indexing/readback passed. This is a transcript-seeded continuation, not a passing full audio gate. No temporary instrumentation remains and no original personal folders/context were accessed. Source fix is ready for owner review; installed app has not been rebuilt/replaced.

Owner review: increase the enrichment output budget for additional headroom. Raising 2048 to 4096; keep sequence repetition protection and strict completion checks. Rebuild, run deterministic checks and recheck the authorized workspace input before returning to Verify.

Owner-requested headroom completed: final enrichment budget is 4096 tokens. Rebuild and unit suite 154/154 pass. Supplied-input run completes with valid YAML/string lists, supplied date/time and exact body; grounded work category/summary, finite duplicate entity and omissions remain, with one inferred organization label in this run. All four fixtures rerun at 4096; reports prefix 2026-10-07_17-02-38_Qwen3.5-9B-Q4_K_M. Work omits documentation, personal omits beach/food, mixed matches, Dutch now matches all lists but still uses spoken date and omits synchronization/raw-polished distinctions in summary. No further sampler/prompt changes. Shared-model continuation/full209 suite were checked at initial2048 budget; unchanged constant-only increase does not rerun blocked audio transcription.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Reproduced native enrichment exhaustion on the explicitly supplied workspace copy (9254 prompt + 9434 output = 18688 tokens); bounded tracing showed repeated entity-list items. Added enrichment-only DRY sequence protection, a final owner-requested 4096-token metadata budget, correct single sampler acceptance, strict completion and EOG-boundary handling, and prompt clarifications. Copied input and all four enrichment fixtures complete with valid YAML and exact body preservation; remaining metadata/date limitations are documented in ADR-007. Final build and154 unit tests pass;209 full deterministic tests and transcript-seeded shared-model continuation/resume/search passed during initial2048-budget validation. Full audio gate hits a separate Whisper assertion (DRAFT-1). Supplied content/traces remain outside Git; installed app unchanged. Ready for owner review.
<!-- SECTION:FINAL_SUMMARY:END -->

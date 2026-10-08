---
id: TASK-44
title: Add a synthetic enrichment loop regression evaluation
status: Verify
assignee: []
created_date: '2026-10-07 15:19'
updated_date: '2026-10-08 06:35'
labels: []
dependencies: []
ordinal: 44000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The enrichment loop fix currently relies on a privately supplied reproduction input that must not be committed. Add independently authored synthetic evidence that exposes the pre-fix native model failure and can detect its return in the sequential eval suite.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A synthetic transcript in the enrichment eval inputs demonstrably reproduces the native entity-list loop under recorded pre-fix settings without using personal content
- [x] #2 The fixed implementation completes the same seeded input with valid bounded metadata and unchanged transcript, with semantic findings recorded against expected metadata
- [x] #3 Sequential eval generation and saved-output validation include the regression, with repeatable seed control and checks for completion, types, date/time, body preservation and runaway or duplicate metadata
- [x] #4 Deterministic checks validate the evaluation gate and relevant existing enrichment fixtures are reviewed
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Retain the confirmed 5,084-word synthetic native reproducer selected by the owner. Seed and fingerprint the fixture; run the sequential five-case enrichment suite and saved-output gates; record native and semantic evidence, remove private reproduction material, and commit related changes.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Confirmed independent synthetic fixture: SHA256 ec8193ed72a53aaf919cef027b4cc445a96ebd4f7a5da9842fe4b2f1f4d0e658, 5084 words. Fresh unbounded pre-fix CLI with seed 42, date/time 2026-10-05/16:44, Qwen3.5-9B-Q4_K_M and llama.cpp 0.5.0/GGML 0.25.3 exhausted 18688 context tokens after 9254 prompt and 9434 output tokens; exit 1, no completed output, 1846 repeated Lili entries. One full historical failure observed; shorter variants terminated and the owner selected the confirmed source. Fixed code completes in 288 tokens on both historical and current runtimes; two current runs produce identical metadata. All five sequential enrichment cases and separate saved validation pass (2026-10-08_07-54-18_57974_Qwen3.5-9B-Q4_K_M). Manual semantic findings remain against unchanged expectations, including the added side-project category, omitted benchmarks/business-KPI tag and unsupported summary project designation. Build, 209/209 deterministic tests, 25 validator checks, six CLI seed boundaries and full audio pipeline through resume/search pass. Historical observational patch applies and compiles without changing sampling, budgets or error behavior. Original workspace transcript, all private controls/traces and both experiment roots deleted; only whitelisted synthetic evidence retained in ignored tmp/enrich-synthetic-evidence-2026-10-08. See eval/enrich/README.md and ADR-007 for reproduction procedure, fingerprints, minimization limits and semantic evidence.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added the confirmed synthetic native context-exhaustion reproducer, byte-pinned seeded case settings, expected metadata, historical reproduction patch/procedure and strict sequential generation/saved-output gates. Pre-fix: 9254+9434=18688 tokens, native error/no output. Fixed: 288 tokens on both historical and current runtimes. All five enrichment fixtures, build, 209 deterministic tests, 25 gate checks, six seed boundaries and full audio pipeline pass. Semantic limitations documented; original/private copies deleted. Ready for owner review.
<!-- SECTION:FINAL_SUMMARY:END -->

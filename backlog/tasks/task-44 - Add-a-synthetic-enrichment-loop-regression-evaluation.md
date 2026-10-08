---
id: TASK-44
title: Add a synthetic enrichment loop regression evaluation
status: Verify
assignee: []
created_date: '2026-10-07 15:19'
updated_date: '2026-10-08 16:36'
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
- [x] #1 A wholly fictional transcript demonstrably reproduces native repeated-metadata generation and context exhaustion under recorded pre-fix settings, without private content or calibration
- [x] #2 The fixed implementation completes the same seeded input with valid bounded metadata and unchanged transcript, with semantic findings recorded against expected metadata
- [x] #3 Sequential eval generation and saved-output validation include the regression, with repeatable seed control and checks for completion, types, date/time, body preservation and runaway or duplicate metadata
- [x] #4 Deterministic checks validate the evaluation gate and relevant existing enrichment fixtures are reviewed
- [x] #5 The replacement uses an unrelated fictional scenario, invented names and arbitrary settings, with no presentation-derived terms, outline, token positions or length matching
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Keep the compact 66-word/965-byte independently fictional bedtime-story reproducer. Record two fresh ordinary historical failures, fixed completion in historical/current runtimes, the full five-case eval and semantic limits. Stop further search/minimization at the owner request, retain the correct reference and source fingerprint, and commit the related fixture/docs/backlog changes.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Wholly fictional source 04_fictional_name_loop.md, SHA256 65e941e63d2ad73a1782556382f4905d1872cf8634c154f2abeae76c517a9a85: 66 words/965 bytes, invented caterpillar name (144 Vevu units), invented character and village, arbitrary date/time. No private names, subject matter, outline, token positions or length calibration. Two fresh ordinary historical CLI runs, seeds 42 and 0, both exit 1 with actual native context exhaustion: allocated 4864, prompt 2372, output 2492; no completed file, no summary. Repetition is within a named persons item (808/810 units), not complete repeated rows; the native error is the same. Seed-42 trace matches discovery byte-for-byte; interrupted run excluded. Fixed code completes in 177 tokens on both historical 0.5.0/0.25.3 and current 0.6.0/0.26.0 runtimes, valid bounded metadata and exact source preservation. Correct reference retains full name; generated name is shortened to four units in persons and three in summary. Tag/detail omissions documented. All five sequential eval cases and saved checks pass, prefix 2026-10-08_18-31-07_71234_Qwen3.5-9B-Q4_K_M. Build, 25 gate checks and six seed boundaries pass. Four existing outputs are byte-identical to their manually reviewed versions; per-case reports retained. Original/private roots remain deleted; rejected presentation-related fixture/artifacts were removed previously. Owner requested wrapping up after reproduction, so further search and prepared shortening trials stopped. See eval/enrich/README.md and ADR-007 for native settings, model/source fingerprints and dated evidence.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Reproduced native context exhaustion twice in fresh ordinary CLI runs using wholly invented 66-word content. Added the byte-pinned fictional fixture and correct expected metadata to the five-case eval set. Fixed code completes in 177 tokens in both historical/current runtimes; all structural and saved-output checks pass. Shortened artificial-name and other semantic limitations recorded. Original/private material remains deleted. Search stopped at owner request; ready for review.
<!-- SECTION:FINAL_SUMMARY:END -->

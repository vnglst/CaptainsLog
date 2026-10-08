---
id: TASK-44
title: Add a synthetic enrichment loop regression evaluation
status: Complete
assignee: []
created_date: '2026-10-07 15:19'
updated_date: '2026-10-08 17:13'
labels: []
dependencies: []
ordinal: 1187.5
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The enrichment-loop fix was originally demonstrated using a privately supplied transcript that cannot be committed or reused as a repository test. Add a wholly fictional example that reproduces the actual pre-fix failure: repeated metadata generation fills the native model context, exits with an error and produces no completed output.

Write the scenario independently in an unrelated domain, with invented names and arbitrary settings. Do not copy private subject matter, outlines, token positions or length targets. Run the same recorded input and seed against the fixed implementation, verify bounded metadata and an unchanged transcript, and include it in the sequential evaluation suite and saved-output checks. Record semantic differences as well as mechanical success; completing generation does not guarantee perfect name extraction.
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
Retain the independently fictional bedtime-story input and its correct expected metadata. Pin its source bytes, record fresh historical CLI failures and fixed completion, and include it in the five-case sequential suite. Preserve semantic limitations and stop further search or minimization as requested.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
The committed example is a 66-word invented bedtime story about a caterpillar whose name repeats the syllable Vevu 144 times. Its characters, village, date and time are invented independently. A source fingerprint pins the exact input bytes.

Two fresh ordinary historical CLI runs, with seeds 42 and 0, both exhausted a 4,864-token context after 2,372 prompt tokens and 2,492 output tokens, writing no completed file. Repetition occurs within one extracted name. Fixed code finishes in 177 tokens on both the matching historical runtime and the current runtime, with valid bounded metadata and the exact original body.

All five sequential enrichment cases and saved-output checks pass, along with the build, 25 validator checks and six CLI seed boundaries. The generated artificial name is shortened to four syllable units in persons and three in the summary; some tags and story details are omitted. The expected reference retains the full correct name. Further search/minimization stopped at the owner’s request.

Historical provenance correction: the earlier presentation-related candidate and its artifacts were rejected and removed. Its failure/success evidence does not transfer to a replacement. An intermediate fictional festival story completed normally on historical code and was not a demonstrated exhaustion reproducer; only the independently authored long-name bedtime story established the recorded native failure. This migration retains that distinction without rerunning inference.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added an independently fictional regression that demonstrates actual native context exhaustion before the fix and bounded completion afterwards. Structural checks pass; shortened-name and semantic omissions remain visible for future regression review.
<!-- SECTION:FINAL_SUMMARY:END -->

---
id: TASK-44
title: Add a synthetic enrichment loop regression evaluation
status: Next
assignee: []
created_date: '2026-10-07 15:19'
updated_date: '2026-10-08 08:56'
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
- [ ] #1 A synthetic transcript in the enrichment eval inputs demonstrably reproduces the native entity-list loop under recorded pre-fix settings without using personal content
- [x] #2 The fixed implementation completes the same seeded input with valid bounded metadata and unchanged transcript, with semantic findings recorded against expected metadata
- [ ] #3 Sequential eval generation and saved-output validation include the regression, with repeatable seed control and checks for completion, types, date/time, body preservation and runaway or duplicate metadata
- [x] #4 Deterministic checks validate the evaluation gate and relevant existing enrichment fixtures are reviewed
- [x] #5 The replacement uses an unrelated fictional scenario, invented names and arbitrary settings, with no presentation-derived terms, outline, token positions or length matching
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Remove the rejected presentation-related fixture and its generated artifacts. Write a wholly fictional transcript in an unrelated domain with invented names and events, then test it against historical and fixed native code before making any reproduction claim.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Owner rejected the previous fixture because real names and subject matter connected it to the private presentation. Removed that input/expected pair and its generated candidates, outputs, reports and native traces. The replacement is an independently written imaginary lantern-festival diary with invented characters, places and creatures, arbitrary date/time, and no reused outline or calibration from private content. Previous native reproduction does not establish coverage for this source; testing historical and fixed behavior separately.

The unrelated 871-word replacement completed normally on historical code with seeds 42 and 0 (211/227 output tokens; 2885 prompt, 5888 context). It does not currently reproduce native context exhaustion. Original failure coverage is withdrawn rather than transferred. The fixed sequential suite is running; native reproduction acceptance remains unchecked and task stays Next.

Fixed replacement completes in 208 tokens, with bounded valid metadata and unchanged body. All five enrichment generation/saved-output checks pass (2026-10-08_10-53-26_63479_Qwen3.5-9B-Q4_K_M); build, 25 validator checks and six seed boundaries pass. Semantic review records a hallucinated Whisper entity, overinclusive creature/object entities and omitted tags/summary details; expected metadata remains correct. Privacy correction is complete, but native failure reproduction and its regression coverage remain unverified, so task stays Next.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Removed the rejected presentation-related fixture and local generated artifacts, replaced it with an unrelated imaginary festival diary, and added strict synthetic-fixture provenance guidance. The replacement and existing four cases pass fixed structural evals; manual findings are recorded. Historical seeds 42 and 0 both complete normally, so this replacement is not a native reproducer. TASK-44 remains Next with native reproduction/coverage acceptance unchecked. Earlier Git history is unchanged.
<!-- SECTION:FINAL_SUMMARY:END -->

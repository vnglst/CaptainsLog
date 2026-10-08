---
id: TASK-41
title: Reproduce and fix enrichment generation exhaustion
status: Complete
assignee: []
created_date: '2026-10-05 17:53'
updated_date: '2026-10-08 17:03'
labels: []
dependencies: []
ordinal: 2375
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Enrichment adds categories, tags, names and a summary to a cleaned transcript. For some inputs the model keeps generating repeated metadata until it fills the entire context window and fails, leaving no completed log. Earlier prompt changes did not reliably reproduce or eliminate this failure.

Reproduce the failure through the CLI, identify the repeating output, and fix generation so it completes with valid metadata while preserving the transcript exactly. Verify the fix against the reproduced case and existing synthetic evaluation fixtures, and record remaining metadata-quality limitations.

The owner authorized only a supplied workspace copy for the original reproduction. Original personal data folders and speaker context remain prohibited; supplied content and traces must stay out of Git. Independently fictional regression coverage is handled by TASK-44.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A fixture-backed CLI run reproduces enrichment exhaustion and records the generated failure behavior
- [x] #2 The reproduced case completes with valid grounded metadata and preserves the source body after the fix
- [x] #3 Existing enrichment fixtures and relevant deterministic checks are reviewed with concrete semantic findings
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Reproduce the actual CLI failure with the authorized workspace copy and isolated configuration. Inspect a bounded diagnostic trace, apply a targeted enrichment fix and verify completion, metadata and exact transcript preservation. Run deterministic checks and the existing synthetic fixtures sequentially; report any separate pipeline failures and remaining extraction issues.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
The unchanged CLI reproduced native exhaustion after a 9,254-token prompt and 9,434 generated tokens. Diagnostic output showed one name repeating as entity-list entries before the summary. The fix adds sequence repetition protection for enrichment, a 4,096-token metadata budget, strict unfinished-output rejection and correct sampler acceptance.

The supplied case and four repository fixtures complete with valid YAML and unchanged transcripts. Build and 154 unit tests passed at the final budget; 209 full tests and a transcript-seeded continuation through cleanup, categorization, naming, enrichment, resume and search passed during the initial budget trial. The full audio check stopped at a separate Whisper assertion before enrichment.

Finite extraction issues remain: repeated entity names, omitted tags/details and the Dutch fixture using its spoken date instead of the supplied date. The installed app was not replaced. Supplied content and traces remain outside Git.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed the reproduced runaway metadata loop and bounded enrichment output. Relevant CLI and fixture checks pass; the separate audio failure and remaining extraction issues are recorded above. Marked Complete by the owner.
<!-- SECTION:FINAL_SUMMARY:END -->

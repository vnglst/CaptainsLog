---
id: TASK-33
title: 'Run build, test, and semantic release gates'
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:13'
labels:
  - release
dependencies: []
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
From a clean release candidate, run the build, full deterministic tests, coverage gate, sequential stage evaluations and full synthetic audio pipeline. Review every selected model output for missing content, changed meaning, invented facts and downstream effects before publication.

The deterministic coverage floor is 80% for ordinary production logic. Declarative UI and direct native/hardware adapters remain visible in the aggregate report but require separate integration checks. Do not improve coverage by excluding ordinary logic. Use isolated configuration/data and repository fixtures, bypass demo seeding, and never run inference jobs concurrently or compile during inference.

Record the candidate commit, runtime/model identities, commands, semantic findings and unresolved limits. Historical passes do not establish a fresh release gate, and a transcript-seeded continuation does not count as a full audio-pipeline pass.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Historical baselines: September 26 passed 184/184 full tests and 132/132 unit tests, with 82.16% deterministic-production coverage and 31.58% all-source coverage. Later October checks reached 209/209 full tests. These totals describe their respective revisions, not the current tree.

October 2 pipeline and resume/search checks passed with synthetic audio, but known transcription and summary omissions remained. October 7 enrichment integration encountered a separate Whisper Metal shape/strides assertion before enrichment; transcript-seeded downstream success did not pass the full audio gate. October 8 task-42 evidence includes a completed native pipeline, corrected saved validation 5/5, and a focused seeded enrichment check. Model suites were not all repeated for that transport integration.

Native UI review on September 26 used isolated fixtures and accessibility, not screenshot geometry or microphone/model operation. Safe logs/detail/search/queue/Settings states and deletion flows were exercised; real recording, downloads, folder persistence and processing retries still require their own checks. Earlier source-only legacy UI review removed no symbols. Keep these limits visible when deciding what fresh release evidence is still needed.

Historical search implementation checks used fake embeddings and a multilingual synthetic query corpus. Real-model relevance, offline packaged-app behavior, corrupt model/index recovery, interrupted setup and edit/rename/Trash convergence still require explicit integration evidence. The search index is derived and disposable; canonical Markdown must not be changed by recovery.
<!-- SECTION:NOTES:END -->

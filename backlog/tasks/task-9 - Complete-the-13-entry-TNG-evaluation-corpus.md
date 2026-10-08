---
id: TASK-9
title: Complete the 13-entry TNG evaluation corpus
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:13'
labels:
  - evaluation
dependencies: []
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Expand the evaluation set into 13 coherent fictional voice memos: eleven English, one Dutch and one German. Each reference entry contains a raw spoken script, polished text, expected metadata and filename. The unused reference corpus has been retained separately from the active stage suites; moving it does not make it release evidence.

Use the Starfleet Analytics narrator and the prepared work, personal, technical, conference, mentoring, health and side-project scenarios. Record the scripts naturally in a quiet room, keeping self-corrections and filler words intentional. Pair each recording with its raw transcript, cleaned text, metadata and filename expectations, and review the meaning at every stage before replacing the current cases.

Completion means all 13 entries have audio and consistent stage inputs/expected outputs, multilingual and category coverage is checked, and the sequential suites and full pipeline have been reviewed semantically. Existing fixtures remain the quality gate until the replacement is ready. Use synthetic material only; do not import personal recordings.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Reference-corpus scope: work-week review, API architecture, personal weekend, enterprise kickoff, home-assistant side project, conference, retrospective, mentoring/career, health/fitness, annual review and book reflection in English; mixed weekend/work planning in Dutch; cluster debugging in German. The original target durations range from roughly 10 to 25 minutes.

The narrator works at fictional Starfleet Analytics. Recurring colleagues, clients and projects use TNG terminology. Coverage includes work-only, personal-only, mixed and side-project categories; technical names, emotions, books/events, multiple people/projects and short-versus-long topic distillation.

For each entry, use raw narration for transcription expectations and cleanup input; polished text for cleanup expectations and enrichment/filename input; full YAML plus unchanged body for enrichment expectations; and the single expected name for filename checks. Keep all stage stems consistent. Review the new corpus before deleting any currently active fixtures. No recordings were added or replaced during documentation consolidation.

The complete unused scripts and ground truth are preserved together under eval/tng-reference. They remain reference data; the active runner discovers only its existing stage directories. No reference entry was activated during this cleanup.
<!-- SECTION:NOTES:END -->

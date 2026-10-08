---
id: TASK-10
title: Resolve meaning-changing transcription errors
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:09'
labels:
  - evaluation
dependencies: []
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Current transcription errors change the meaning of recordings and can propagate into cleanup, naming and summaries. Reproduce them with the repository’s synthetic evaluation audio, improve the transcription configuration or model behavior, and rerun both transcription and the full pipeline with semantic review.

Known findings include Dutch side-project references becoming “science project” or “site project,” a folder word becoming “vollendje,” and “Liefst een lokaal model” becoming “Een liefdelokaal model.” Literary fixtures lose or change character names, “New” in a place name, and speaker attributions; an English run added a blank-audio marker. Cleanup repairing some words does not establish correct transcription.

Compare full sentences, omissions, order, names and additions against ground truth. Record remaining errors and downstream impact rather than relying on word scores. Keep source audio unchanged and use isolated configuration and data.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Historical comparison, April 2025: Qwen3-ASR through a streaming/VAD path dropped complete sentences and speaker attributions, jumbled order and corrupted names. Whisper Large-v2 made spelling/proper-noun errors but preserved sentence order and content better on the same four fixtures. Quantization was a possible cause, not a demonstrated explanation; future candidates need independent native comparison.

September 2026 semantic baseline: Dutch side-project errors propagated into cleanup and summaries; literary names and English place names changed, and an English run added a blank-audio marker. Word-alignment scores were unreliable for hyphenated terms, so sentence-level manual review was required. These are dated findings, not newly run evaluations.
<!-- SECTION:NOTES:END -->

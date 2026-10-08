---
id: TASK-22
title: Review public documentation for stale or internal content
status: Next
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:53'
labels:
  - publication
dependencies: []
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Review public-facing instructions, architecture records, examples, design references and comments for obsolete behavior, machine-specific directions, unfinished internal notes and contradictory installation claims.

Use “Logs” for the current product. Concept images are design references and must not be presented as current app captures; older LCARS explorations are historical. Installation guidance must consistently state Apple Silicon/macOS requirements, ad-hoc signing, lack of notarization and Homebrew quarantine removal.

TASK-42 delivered targeted evaluation/navigation corrections, and the documentation consolidation removes separate plans and reports. Those changes do not complete the broader public-content, rights and installation review. Verify the remaining material as a new user and record concrete corrections and limits.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Publication context retained from the removed plan: the repository became public and v0.1.0 was owner-approved on September 25, 2026. The seven concept images were approved as design references and had embedded creator metadata removed; their illustrative paths/counts/device labels do not make them current screenshots. Fan-created TNG content remains unofficial and requires attribution/no-affiliation notices.

The current documentation cleanup changes organization only. Wider rights, network-privacy, clean-machine and installation acceptance tasks remain open in their existing records.

## Diagnostic context retained from the removed troubleshooting guide

The current transcriber selects CPU/GPU for encoder and decoder. Older ANE advice may describe a different installed bundle; identify its revision and transcription settings first. Whisper Metal assertion failures must be recorded as failures, even when a transcript-seeded continuation succeeds. Text processing uses in-process libllama and requests all available GPU layers, rather than llama-cli or a fixed 41-layer setting. Source header/library problems should be checked against versioned llama/GGML pkg-config paths and the actual bundled library links.

Reproduce with repository fixtures and isolated config/data, compile before inference, and never run models concurrently. Verify the actual model/runtime before diagnosing memory or speed. A URL-cache warning alone does not prove a download failed. Keep original failing synthetic cases and distinguish context exhaustion from an explicit output-budget failure; unfinished responses must not be treated as completed metadata.

Owner requested archiving during backlog refinement on 2026-10-08 because the purpose of this task was unclear. Archiving does not claim the review was implemented or completed.
<!-- SECTION:NOTES:END -->

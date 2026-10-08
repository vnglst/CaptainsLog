---
id: TASK-15
title: Add optional Kev selection if quality gates pass
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:09'
labels:
  - kev
dependencies:
  - TASK-14
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Only after the adoption gates pass, expose Kev as an optional decision model while preserving the existing Qwen-only workflow. Add CLI and configuration support before Settings controls, with model selection, location, revision and any validated confidence policy.

Provide verified downloads and capability checks. An explicitly selected unsupported model must produce an actionable error. Define any low-confidence fallback openly, including its extra inference cost; do not silently repair model answers or hide retries.

Share decision code between CLI and app, validate finite probabilities and allowed labels, and preserve category manifests, resumability and earlier-stage files. Schedule model lifetimes sequentially so Qwen and Kev are not kept loaded together unnecessarily. Test configuration migration, cancellation, unsupported models/runtimes, model lifetime and fallback behavior with deterministic cases and actual fixture CLI runs.
<!-- SECTION:DESCRIPTION:END -->

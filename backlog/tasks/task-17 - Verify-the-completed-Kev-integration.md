---
id: TASK-17
title: Verify the completed Kev integration
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:09'
labels:
  - kev
dependencies:
  - TASK-15
ordinal: 17000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
After optional Kev support is implemented, verify the integrated CLI and packaged app rather than relying on isolated decision experiments. Confirm the supported older configuration and unchanged Qwen-only path.

Run the build, full deterministic tests, a focused filename smoke check, all stage suites sequentially and the full synthetic audio pipeline. Review generated output for omissions, changed meaning and invented content. Measure model switching, cancellation and unsupported-runtime errors in the real command path.

Verify offline operation after downloads, correct model loading in the packaged app, expected configuration migration, notices and error behavior. Record exact versions and remaining limits. Passing structural checks or a category benchmark alone does not establish summary grounding or release readiness.
<!-- SECTION:DESCRIPTION:END -->

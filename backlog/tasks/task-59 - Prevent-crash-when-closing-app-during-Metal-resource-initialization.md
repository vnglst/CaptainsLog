---
id: TASK-59
title: Prevent crash when closing app during Metal resource initialization
status: Verify
assignee: []
created_date: '2026-10-13 13:44'
updated_date: '2026-10-14 06:04'
labels: []
dependencies: []
type: bug
ordinal: 52000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Closing CaptainsLog caused an EXC_CRASH (SIGABRT, abort trap) while the app was being closed. The report identifies CaptainsLog 0.5.0 (ARM64) on macOS 26.7.1, build 25G241; the process had been running for about 1 hour 45 minutes.

The main-thread stack enters AppKit application termination, then C++ static finalization, and aborts in the bundled llama framework: ggml_abort → ggml_metal_rsets_free → ggml_metal_device_free. At the same time, a default-QoS background thread is executing __ggml_metal_rsets_init_block_invoke. This is consistent with Metal resource-set initialization overlapping backend teardown during exit, but the crash report alone does not prove the cause. Investigate the shutdown lifecycle and fix the crash.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Closing the app in a similar situation does not crash.
<!-- AC:END -->

---
id: TASK-54
title: CaptainsLog 0.5.0 crashes in CoreML Metal prediction
status: Complete
assignee: []
created_date: '2026-10-12 05:05'
updated_date: '2026-10-27 13:18'
labels: []
dependencies: []
type: bug
ordinal: 0.009059906005859375
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The owner-supplied bug report records CaptainsLog 0.5.0 (0.5.0), a native ARM-64 background process, terminating with EXC_CRASH (SIGABRT) and SIGNAL code 6 (Abort trap: 6).

The crash occurred on 11 October 2026 at 22:58:26 +0200, after launch at 20:26:25 +0200. The environment was macOS 26.7.1 (25G241) on Mac16,12, with Apple M4 graphics and 16 GB memory. System Integrity Protection was enabled.

Thread 8 crashed on com.apple.coreml.DefaultAsyncPredictionQueue. Its stack runs through __assert_rtn, MTLReportFailure, and MPSGraphTensorData initWithMTLBuffer:shape:strides:interleaves:dataType:, followed by Espresso MpsGraphInferenceOperation EncodeMemoryBuffers and EncodeOperation, and CoreML asynchronous prediction submission. The main thread was in the application event loop. A separate thread was in llama __ggml_metal_rsets_init_block_invoke.

The supplied crash report does not include reproduction steps, the active user operation, an assertion message, or acceptance criteria.
<!-- SECTION:DESCRIPTION:END -->

---
id: TASK-50
title: Stop active work and quit promptly without crashing
status: Next
assignee: []
created_date: '2026-10-11 11:27'
updated_date: '2026-10-11 11:39'
labels: []
dependencies: []
type: bug
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When the user quits CaptainsLog, stop active work and quit as soon as possible without crashing or waiting for processing to finish.

Crash report summary: CaptainsLog 0.4.0 aborted during quit while bulk reprocessing was active. The main thread was terminating the app and freeing llama Metal resources, with ggml_metal_rsets_free calling ggml_abort (SIGABRT). A background thread was still running the processing pipeline in llama_decode and waiting for Metal command-buffer completion.
<!-- SECTION:DESCRIPTION:END -->

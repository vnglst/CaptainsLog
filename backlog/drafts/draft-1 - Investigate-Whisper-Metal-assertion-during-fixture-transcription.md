---
id: DRAFT-1
title: Investigate Whisper Metal assertion during fixture transcription
status: Draft
assignee: []
created_date: '2026-10-07 14:57'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Discovered while verifying TASK-41 on 2026-10-07. The unchanged transcription stage in the full repository audio fixture pipeline aborted (exit 134) in MPSGraphTensorData.mm with shape.count = 0 != strides.count = 4, before cleanup or enrichment. Isolated config/data under tmp/enrich-exhaustion-2026-10-07/pipeline-check; input was eval/transcribe/audio/2025-01-14 side project.m4a. No production transcription change is part of TASK-41. Investigate native transcription compatibility and whether a supported compute fallback is appropriate. The CLI currently selects cpuAndGPU and exposes no compute fallback.
<!-- SECTION:DESCRIPTION:END -->

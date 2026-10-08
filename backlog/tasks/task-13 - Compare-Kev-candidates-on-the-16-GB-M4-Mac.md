---
id: TASK-13
title: Compare Kev candidates on the 16 GB M4 Mac
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:09'
labels:
  - kev
dependencies:
  - TASK-11
  - TASK-12
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Compare compatible Kev 4B Q8 and Kev 0.8B candidates with the Qwen baseline on the M4 MacBook Air with 16 GB unified memory and an 8-core GPU. The purpose is to determine whether better bounded decisions justify another model’s memory and switching costs.

Run candidates sequentially on short and long synthetic English/Dutch cases. Record cold load time, warm decision latency, peak process memory, memory pressure, swap growth and responsiveness. Release Whisper and Qwen before loading Kev, and include unloading/reloading in end-to-end pipeline measurements.

Bound supported input length explicitly and reject oversized requests rather than silently truncating them. Stop trials if responsiveness or memory pressure deteriorates. Exclude 27B and keep 9B outside the initial experiment. Measure decision accuracy, repeat-run variation, choice-order sensitivity and calibration against predeclared acceptance limits.
<!-- SECTION:DESCRIPTION:END -->

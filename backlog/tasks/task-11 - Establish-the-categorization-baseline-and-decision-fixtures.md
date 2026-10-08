---
id: TASK-11
title: Establish the categorization baseline and decision fixtures
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:09'
labels:
  - kev
dependencies: []
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Kev is being considered as an optional local model for bounded category choices. Before evaluating it, establish the current Qwen categorization baseline and a fair set of synthetic English and Dutch decision cases.

Include ambiguous work/side-project boundaries, mixed topics, short notes, negation, quoted statements, unfamiliar names and long entries. Define expected labels and their rationale before comparing models. Pair equivalent questions and reorder answer choices to test stability.

Keep development cases separate from held-out acceptance cases. Define acceptable error and latency limits before inspecting held-out output, and calibrate confidence only on development data. Review each wrong category and explain the semantic impact; a well-formed label or high probability is not proof of correctness. Run only one model task at a time with isolated data.
<!-- SECTION:DESCRIPTION:END -->

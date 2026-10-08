---
id: TASK-16
title: Evaluate summary grounding separately
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:16'
labels:
  - kev
dependencies: []
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Evaluate whether Kev can identify unsupported summary claims independently of its categorization accuracy. Use synthetic source/summary pairs with human-reviewed labels, including Dutch sources with English summaries.

Include invented entities, changed numbers, reversed negation, missing uncertainty and fluent but unsupported statements, as well as correct claims. Report missed unsupported claims and false alarms separately. Omission detection is a different rubric from factual grounding and should not be folded into one unexplained score.

Expose results as a CLI evaluation report first. Preserve the generated summary and earlier-stage files; do not silently rewrite content or retry generation based on an unvalidated score. Decide whether the benefit justifies an optional pipeline stage, define default-off configuration and review behavior, and reserve stable UI space before adding app controls.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
October 8, 2026: Consolidated into TASK-11 at the owner’s request. Its scope and any historical findings are preserved in that task. Archived as a superseded planning item, not completed implementation.
<!-- SECTION:NOTES:END -->

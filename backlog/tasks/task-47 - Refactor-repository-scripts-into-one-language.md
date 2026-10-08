---
id: TASK-47
title: Refactor repository scripts into one language
status: To Do
assignee: []
created_date: '2026-10-08 19:14'
updated_date: '2026-10-08 19:15'
labels: []
dependencies: []
ordinal: 39000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The repository scripts under `scripts/` are currently implemented in more than one programming language, which makes maintenance, review, and execution consistency harder. Refactor every script in that directory to Swift while preserving the repository automation they provide.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every script under `scripts/` is implemented in Swift, with no remaining scripts in another implementation language in that directory.
- [ ] #2 All existing Make targets and documented script entry points continue to work without behavioral regressions.
- [ ] #3 Relevant script documentation identifies Swift as the implementation language and documents any changed usage details.
- [ ] #4 The refactored scripts pass `make build`, `make tests`, and `make evals-pipeline`.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Refinement confirmed on 2026-10-08: target language is Swift; scope is all scripts under scripts/; preserve all existing Make targets and documented script entry points; validation requires make build, make tests, and make evals-pipeline.
<!-- SECTION:NOTES:END -->

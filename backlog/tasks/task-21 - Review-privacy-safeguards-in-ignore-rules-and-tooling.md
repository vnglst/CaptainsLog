---
id: TASK-21
title: Review privacy safeguards in ignore rules and tooling
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:09'
labels:
  - publication
dependencies: []
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Review ignore rules, build/test scripts and release workflows to prevent accidental publication of local configuration, caches, recordings, generated outputs, signing material and build artifacts.

A machine-specific local Claude configuration was removed from the current tree and given an exact ignore rule, but it remains in older history. Verify that broader safeguards cover future files rather than relying on that one exception. Tests and evaluation commands must use isolated data and synthetic fixtures; microphone checks require explicit confirmation. Record gaps without automatically adding unrelated cleanup tasks.
<!-- SECTION:DESCRIPTION:END -->

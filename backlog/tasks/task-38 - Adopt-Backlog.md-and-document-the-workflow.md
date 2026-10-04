---
id: TASK-38
title: Adopt Backlog.md and document the workflow
status: Complete
assignee: []
created_date: '2026-10-04 13:25'
updated_date: '2026-10-04 13:31'
labels: []
dependencies: []
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The project previously kept all open work in docs/PLAN.md, while Codex sessions needed a durable Git-native task record. Migrate the existing work without losing linked procedures or decisions, and explain the CLI workflow to people and agents.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 All 37 open plan items are represented as Backlog.md tasks with usable references and dependencies.
- [x] #2 README.md explains how to review, create, and update tasks; AGENTS.md defines the agent task lifecycle.
- [x] #3 The old plan is removed, links resolve, and Backlog.md can list and view the migrated tasks.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Migrate the plan through the Backlog.md CLI; update repository links and guidance; verify task counts, references, and documentation; commit and push the result.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 37 migrated source items, 38 unique tasks including this record, task links and references, README/AGENTS workflow commands, backlog doctor, and git diff --check. No Swift code changed, so Swift tests were not run.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Adopted Backlog.md, migrated all 37 open plan items, retained linked details and decisions, and documented the CLI workflow for people and agents. Verified task counts, references, backlog doctor, and git diff --check.
<!-- SECTION:FINAL_SUMMARY:END -->

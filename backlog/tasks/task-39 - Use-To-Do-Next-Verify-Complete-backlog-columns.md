---
id: TASK-39
title: 'Use To Do, Next, Verify, Complete backlog columns'
status: Verify
assignee: []
created_date: '2026-10-04 13:30'
updated_date: '2026-10-04 13:34'
labels: []
dependencies: []
ordinal: 39000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The owner chooses which tasks agents may pick up and wants a separate personal verification step before work is considered ready for release.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The Backlog.md board shows To Do, Next, Verify, and Complete in that order, with no old status remaining.
- [x] #2 Agents only pick up Next tasks, record implementation findings, and move finished work to Verify for the owner.
- [x] #3 The owner moves verified work to Complete; README.md and AGENTS.md describe the flow and CLI commands.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Configure the four columns, migrate the existing completed task, update human and agent guidance, then verify the board and task states.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified board columns and order via backlog board; backlog config list shows the exact statuses; backlog doctor reports no dependency issues; no task retains In Progress or Done. TASK-38 moved to Complete. README and AGENTS document owner selection, agent handoff, and owner verification. No Swift code changed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Configured To Do, Next, Verify, and Complete; migrated TASK-38 to Complete and documented the owner-selected agent workflow. Verified the board, CLI config, task states, and backlog doctor.
<!-- SECTION:FINAL_SUMMARY:END -->

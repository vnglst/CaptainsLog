---
id: TASK-2
title: Define and add collections navigation
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:41'
labels:
  - logs
dependencies: []
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Let users browse related log entries together instead of finding each entry in the full Logs list. For example, someone working on a project could open that project and see the logs associated with it.

“Collections” is a proposed name for these groups, not a defined feature yet. Logs already expose project names, but this task does not specify whether collections should use those names, be groups created by the user, or mean something else. Agree that behavior with the owner before implementing it; do not assume a new grouping system is required.

Define what a group represents, how a log belongs to it, and how that relationship is saved. Then add a way to browse the agreed groups and open their associated logs. Define what users see when there are no groups, when a selected group contains no logs, and when a log belongs to no group. Those screens are what the old wording called “empty states.”

This task concerns grouping and navigation. Category setup and category filters remain separate work.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The owner has agreed what collections mean, how they relate to existing project names, how logs belong to them and how membership is saved.
- [ ] #2 Users can browse the agreed groups and open their associated logs without losing access to the full Logs list.
- [ ] #3 The behavior for no groups, an empty selected group and ungrouped logs is defined and verified with synthetic data.
<!-- AC:END -->

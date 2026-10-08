---
id: TASK-18
title: Audit tracked files and Git LFS for private material
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:09'
labels:
  - publication
dependencies: []
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Audit every tracked file, including hidden files and any Git LFS objects, for private content, credentials, private URLs, absolute home paths and machine/account identifiers. The owner permits their own name and email; that exception does not cover other people’s information or personal recordings.

Inspect binary files and images as well as text. Distinguish visible artwork from embedded creator metadata, device labels and screenshots of real notes. Record what was inspected, at which commit, and any unresolved exposure. Do not treat deleting a current-tree file as removing it from Git history; that is separate work in TASK-19.
<!-- SECTION:DESCRIPTION:END -->

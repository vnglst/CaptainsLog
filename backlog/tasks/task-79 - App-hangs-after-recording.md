---
id: TASK-79
title: App hangs after recording
status: Complete
assignee: []
created_date: '2026-10-27T19:01:00Z'
updated_date: '2026-10-27T19:02:00Z'
labels: []
dependencies: []
ordinal: 70000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
After recording the app hangs. Had to force quit to continue.

Cause: loadEntries() ran on the main thread after a recording and read a .slug marker file that was a dataless (cloud-evicted) file; the read blocked ~64s.
Fix: entry lists now refresh off the main thread (955f76c).
<!-- SECTION:DESCRIPTION:END -->

---
id: TASK-19
title: Audit reachable Git history and releases for private material
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:16'
labels:
  - publication
dependencies: []
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The repository is already public, so private material in older commits remains an exposure even if it has been removed from the current tree. Review every reachable branch, tag and release, including historical local configuration, recordings, generated copies and binary metadata.

For any finding, assess what was exposed and what remediation is needed, such as credential rotation or a sanitized public history/repository. Preserve an appropriate archival copy before any destructive history operation and obtain authorization for that operation. Record reviewed refs, release assets and remaining limits. Current-tree cleanup alone cannot complete this task.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
October 8, 2026: Consolidated into TASK-18 at the owner’s request. Its scope and any historical findings are preserved in that task. Archived as a superseded planning item, not completed implementation.
<!-- SECTION:NOTES:END -->

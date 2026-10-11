---
id: TASK-51
title: Delete processing outputs and use existing processing in CLI and UI
status: Next
assignee: []
created_date: '2026-10-11 11:28'
updated_date: '2026-10-11 15:01'
labels: []
dependencies: []
type: enhancement
ordinal: 43000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Remove separate reprocessing functionality from both the CLI and UI. Remove the CLI reprocess command and its backup and batch-resume machinery.

Provide only deletion of all processing outputs, including intermediate results, finished logs and existing legacy backups, while keeping the original source audio files and settings. Make this deletion available in both the CLI and Settings. Deletion must not start processing automatically. After deletion, process the recordings again using the existing CLI processing commands or the existing main-screen functionality for processing all unprocessed files.
<!-- SECTION:DESCRIPTION:END -->

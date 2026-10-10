---
id: TASK-6
title: Add menu bar recording controls
status: Verify
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-10 12:31'
labels:
  - logs
dependencies: []
ordinal: 2500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Users should be able to minimize the app to the menu bar. Clicking its menu bar icon should show a record button so users can quickly start a new voice memo, with start and stop recording controls. The menu bar interface should also show when memos are being processed and provide a way to quit the app.

While recording, show a clear recording indicator and elapsed time. Include an Open CaptainsLog action to return to the main window and brief error feedback if recording or processing fails. Keep the interface minimal.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The app can be minimized to the menu bar.
- [ ] #2 Clicking the menu bar icon reveals controls to start and stop recording a voice memo.
- [x] #3 The menu bar interface shows when memos are being processed.
- [x] #4 Users can quit the app from its menu bar interface.
- [x] #5 The menu bar interface remains minimal.
- [x] #6 While recording, the menu bar interface shows a clear recording indicator and elapsed time.
- [x] #7 An Open CaptainsLog action returns the user to the main window.
- [x] #8 The menu bar interface shows a brief error message if recording or processing fails.
<!-- AC:END -->

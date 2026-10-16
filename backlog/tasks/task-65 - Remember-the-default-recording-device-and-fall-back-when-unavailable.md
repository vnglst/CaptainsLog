---
id: TASK-65
title: Remember the default recording device and fall back when unavailable
status: To Do
assignee: []
created_date: '2026-10-16 06:19'
updated_date: '2026-10-16 06:21'
labels: []
dependencies: []
type: enhancement
ordinal: 58000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Remember the last microphone selected by the user across app restarts. When the app is opened again and that microphone is available, preselect it as the default recording device. If it is unavailable, for example because it has been unplugged, fall back to another available recording input.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The last microphone selected by the user is remembered across app restarts.
- [ ] #2 When the app is reopened and the remembered microphone is available, it is preselected as the default recording device.
- [ ] #3 When the remembered microphone is unavailable, for example because it has been unplugged, another available recording input is used as a fallback.
<!-- AC:END -->

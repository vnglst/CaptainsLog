---
id: TASK-80
title: Remove remaining main-thread file reads
status: Verify
assignee: []
created_date: '2026-10-27T19:09:00Z'
updated_date: '2026-10-27T19:18:00Z'
labels: []
dependencies: []
ordinal: 71000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Other places still read the data folder on the main thread and can hang the app. Move them to the background.
<!-- SECTION:DESCRIPTION:END -->

---
id: TASK-3
title: Add category setup to Settings and onboarding
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-09 19:22'
labels:
  - logs
dependencies: []
ordinal: 875
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The current categories are personal, professional and side project. Users should be able to control categories in Settings, adding any number of categories and removing categories they no longer want. Category setup is also included in onboarding.

The configured categories should determine the category folders created and where entries are placed the next time an audio file is processed. A category can be removed even when it contains entries. Removing it must not delete existing folders or their entries. Existing files can be placed in the configured categories when they are processed again.

A way to reprocess all audio files belongs in a separate PBI and is outside this item.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Users can add any number of categories in Settings.
- [ ] #2 Users can remove categories in Settings, including categories that contain entries.
- [ ] #3 Removing a category does not delete existing folders or their entries.
- [ ] #4 Subsequent processing of an audio file uses the configured categories for folder creation and entry placement.
<!-- AC:END -->

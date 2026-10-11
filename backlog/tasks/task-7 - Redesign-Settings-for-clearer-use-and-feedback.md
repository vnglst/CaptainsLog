---
id: TASK-7
title: Redesign Settings for clearer use and feedback
status: Next
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-11 18:11'
labels:
  - settings
dependencies: []
ordinal: 21500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Redesign the Settings screen for visual polish and better usability: clear grouping and navigation, readable labels and help text, consistent spacing and controls, and understandable save, progress and error feedback.

Before implementation, use the image generation skill to create four alternative design previews. Show all four alternatives to the owner and ask the owner to review and choose one. Move to implementation only after that review and selection.

The owner selected the separate Context navigation item from alternative 2. Context should contain all settings that affect the output. Do not show the preview, and keep the current designs of the individual settings, including corrections and categories.

Reorganize Settings in the order shown in alternative 1, without a submenu. Category drag-and-drop reordering is separate work.

The selected menu label is Context. The combined design reference below still uses the earlier Writing label; use Context and preserve the current individual settings designs.

Design reference: [Combined Context and Settings concept](design/logs/screens/09-context-settings-concept.png).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Before implementation, the image generation skill is used to create four alternative Settings design previews.
- [x] #2 All four previews are shown to the owner for review and selection.
- [x] #3 Implementation begins only after the owner has reviewed the previews and selected an alternative.
- [ ] #4 Context is a separate navigation item containing all settings that affect the output, without a preview.
- [ ] #5 The current designs of individual settings, including corrections and categories, are preserved.
- [ ] #6 Settings follows the order of alternative 1 without a submenu.
<!-- AC:END -->

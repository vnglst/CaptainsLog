---
id: TASK-29
title: Remove unused legacy UI components
status: Next
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:53'
labels:
  - distribution
dependencies: []
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Remove unused legacy UI and common components, cleaning up as much unused code as possible within this scope. The owner authorized removal during backlog refinement on 2026-10-08 and confirmed there are no external Swift package users, so external compatibility is not a constraint.

The historical review identified older ContentView and FirstRunView, LCARS controls, and entry-row, microphone-selector, delete-confirmation and model-status views as candidates. The current launcher uses FieldNotesContentView. Check current uses, previews, debug flags and resource dependencies to distinguish unused components from active functionality before removal. DesignFixtures and DemoMode were active debug seams, and the vendored sqlite-vec header was a required public include surface; the historical review alone did not establish that these were unused.

This task delivers cleanup rather than only a list of removal candidates.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Unused legacy UI and common components are removed rather than only identified; external package compatibility does not block removal.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
September 26, 2026 review removed no code. AppMain selected FieldNotesContentView as its root. Legacy EntryRow, MicSelectorView, DeleteConfirmationView and ModelStatusView were candidate public types, not proven dead code. DesignFixtures/CAPTAINSLOG_UI_FIXTURE, DemoMode and the sqlite-vec header remained required. Downstream, preview and resource checks were still outstanding.

Owner clarification on 2026-10-08 supersedes the earlier review-only restriction: remove unused components and clean up as much as possible. There are no external users, so downstream compatibility review is not required. Current in-repository uses still determine whether a component is unused.
<!-- SECTION:NOTES:END -->

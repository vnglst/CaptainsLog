---
id: TASK-29
title: Review legacy UI symbols before removal
status: Next
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:43'
labels:
  - distribution
dependencies: []
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Some older public UI types appear unused by the current Logs entry point, but removing them based on a source search alone could break downstream Swift package users, previews or resources. Determine which symbols are actually safe to remove before changing code.

The historical review identified older ContentView and FirstRunView, LCARS controls, and public entry-row, microphone-selector, delete-confirmation and model-status views as candidates. The current launcher uses FieldNotesContentView. DesignFixtures and DemoMode remain active debug seams, and the vendored sqlite-vec header is a required public include surface.

Check downstream clients, previews, debug flags and resource dependencies for each candidate. Record retained and removable symbols with evidence; do not treat the earlier review as deletion approval.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
September 26, 2026 review removed no code. AppMain selected FieldNotesContentView as its root. Legacy EntryRow, MicSelectorView, DeleteConfirmationView and ModelStatusView were candidate public types, not proven dead code. DesignFixtures/CAPTAINSLOG_UI_FIXTURE, DemoMode and the sqlite-vec header remained required. Downstream, preview and resource checks were still outstanding.
<!-- SECTION:NOTES:END -->

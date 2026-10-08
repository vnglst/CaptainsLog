---
id: TASK-46
title: Consolidate documentation into ADRs and self-contained tasks
status: Verify
assignee:
  - '@codex'
created_date: '2026-10-08 17:07'
updated_date: '2026-10-08 17:13'
labels: []
dependencies: []
ordinal: 39000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The docs directory mixes architecture decisions with implementation plans, operating guides and evaluation histories. The owner wants only ADRs and tasks, with tasks readable in the Backlog app without file links. Migrate relevant scope and findings into existing tasks, preserve durable decisions, remove redundant documents and update guidance. Keep the unused TNG reference corpus outside docs and separate from active suites. Active fixtures, demo data and product behavior must remain unchanged.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The docs directory contains only numbered ADRs and no other files or subfolders.
- [x] #2 Relevant unfinished scope, operational checks and important verification limits are explained in self-contained backlog tasks without file links.
- [x] #3 Existing task statuses, ordering, dependencies and checked criteria are preserved; historical results are not represented as new verification.
- [x] #4 Guidance and links reflect the new layout; all 13 TNG reference entries, active fixtures and demo assets are preserved.
- [x] #5 Backlog, ADR and documentation checks pass, with the migration recorded in the changelog.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Inventory documents; migrate relevant context and findings to existing tasks and decisions; move TNG reference data outside docs; remove superseded docs; update links and verify structure, task state and unchanged assets.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Removed 16 non-ADR documents and relocated the complete unused TNG corpus outside docs. Preserved existing search decisions in ADR-019 and recorded the documentation policy in ADR-020. Migrated actionable scope, essential procedures and dated verification limits into existing self-contained tasks; removed active-task file-reference fields and updated inbound guidance. Hash checks confirm all 13 reference entries and all active fixture/demo/runtime assets are unchanged. Existing task statuses, ordering, dependencies and checked criteria are preserved. Backlog/ADR health, local Markdown targets, ADR length and layout checks pass; evaluator tooling passes 66 checks. No native inference or Swift code changed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Documentation now uses numbered ADRs and self-contained backlog tasks. All 13 unused TNG entries are retained separately from active suites. Migration, link and asset-integrity checks pass; ready for owner review.
<!-- SECTION:FINAL_SUMMARY:END -->

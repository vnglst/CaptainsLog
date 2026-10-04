---
id: TASK-40
title: Adopt adrs for architecture decisions
status: Verify
assignee: []
created_date: '2026-10-04 13:54'
updated_date: '2026-10-04 13:59'
labels: []
dependencies: []
ordinal: 40000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The repository has individual ADR files but the agent guidance still holds five architectural decisions as a list, and the existing filenames and numbering do not form a usable adrs repository.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 All five decisions from AGENTS.md are preserved in individual Markdown ADRs under docs/ with no invented rationale
- [x] #2 Existing ADR content remains available and adrs lists each decision with unique numbers
- [x] #3 Agent guidance distinguishes architectural decisions from Backlog.md work and explains supersession
- [x] #4 The obsolete decision list is removed after migration and documentation links resolve
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Retain the existing ADR prose while converting filenames to unique adrs-compatible numbers and updating links. 2. Move the five architectural rules from AGENTS.md into minimal decision files using adrs; add short usage guidance. 3. Check adrs listing, links, changelog, and task acceptance.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Found twelve existing ADR files, including two numbered 011 and a historical gap at 002. The remaining five-item decision list is in AGENTS.md; no matching Backlog task existed.

Verified adrs lists all 17 ADRs and doctor reports no issues. Compared each historical ADR with its prior Git version after normalizing link and duplicate-number changes; all prose is retained. Checked local Markdown links across 62 relevant files.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Moved five architecture requirements into individual ADRs; configured adrs, repaired historical numbering and links, and replaced the old agent list with brief guidance. Verified adrs list/doctor, historical text preservation, and local Markdown links.
<!-- SECTION:FINAL_SUMMARY:END -->

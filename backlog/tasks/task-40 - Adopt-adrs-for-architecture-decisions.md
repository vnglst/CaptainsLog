---
id: TASK-40
title: Adopt adrs for architecture decisions
status: Complete
assignee: []
created_date: '2026-10-04 13:54'
updated_date: '2026-10-08 17:03'
labels: []
dependencies: []
ordinal: 4750
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Architecture decisions explain why the project uses a particular design or technology. The repository already has individual architecture decision records (ADRs), but five more decisions are buried in agent instructions and duplicate numbering makes the collection difficult to browse.

Make these decisions discoverable through the adrs command-line tool. Preserve the existing decisions and their history, move the five remaining rules into individual records, and explain how people and agents find, create and supersede decisions. Backlog tasks continue to track work; ADRs record the lasting decisions behind it.
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
All 17 architecture decisions are listed with unique numbers. Existing decision text was preserved, local links were checked, and adrs list/search/doctor passed. README and agent instructions explain how to find records, create new decisions and supersede old ones. Legacy status lines must be read in the files because the tool does not parse all of them correctly.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Migrated architecture rules and configured adrs, then documented how contributors and agents find, create, and supersede ADRs while using Backlog.md for work. Verified adrs list/search/doctor, historical text preservation, and links.
<!-- SECTION:FINAL_SUMMARY:END -->

---
id: TASK-40
title: Adopt adrs for architecture decisions
status: Verify
assignee: []
created_date: '2026-10-04 13:54'
updated_date: '2026-10-04 14:03'
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

Owner requested clearer human and agent instructions for the adopted ADR workflow; updating README and AGENTS guidance before returning to Verify.

Clarified the human workflow in README and linked it from AGENTS. Confirmed documented adrs list/search/doctor commands work; doctor is healthy, links resolve, and diff has no whitespace errors. Detailed adrs listing misreads legacy status lines, so the documented workflow uses the standard list and directs readers to the record for status.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Migrated architecture rules and configured adrs, then documented how contributors and agents find, create, and supersede ADRs while using Backlog.md for work. Verified adrs list/search/doctor, historical text preservation, and links.
<!-- SECTION:FINAL_SUMMARY:END -->

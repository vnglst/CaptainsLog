---
id: TASK-36
title: Prepare and publish the next release
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:09'
labels:
  - release
dependencies:
  - TASK-33
  - TASK-34
  - TASK-35
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Prepare and publish the next release from clean main after the release gates and semantic findings are reviewed. Preview the standalone Swift release command with --dry-run, then run it to infer or explicitly select the version bump, execute sequential checks, update VERSION/changelog and create a release commit and annotated tag.

Review the result before publishing. Push commit and tag atomically through --publish or the printed command; if publication fails, retry that push rather than creating another version. Verify the tag workflow, matching release notes, archive URL/checksum and updates to both the source cask and public tap. The tap publication token requires Contents read/write access only to the intended tap repository.

A successful initial public release is historical evidence, not verification of this release. Test the published upgrade and public install path before announcing, and retain the previous archive/cask revision for rollback.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Historical release-tooling verification, October 1, 2026: synthetic Git/changelog fixtures covered bump precedence, breaking footers, maintenance-only history, tag/version mismatch, note rollover, dirty-tree and failed-check rejection, cask limits and atomic publication against a local bare remote. Native build/model commands were substituted in those tooling tests. A dry run selected 0.2.0 without editing files or publishing.

The full suite at that revision passed 193/200 and the audio pipeline stopped at the unrelated disk-capacity guard. The tool correctly blocked release commit/tag creation. Initial v0.1.0 publication had previously produced the archive and public tap; it does not establish that later release automation or current token permissions still work.
<!-- SECTION:NOTES:END -->

---
id: TASK-18
title: 'Audit publication privacy across files, history, fixtures and tooling'
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:16'
labels:
  - publication
dependencies: []
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Establish whether the public repository and its published assets expose private material, and whether the tooling prevents future accidental publication. Review the current tree, reachable history, fixtures and safeguards as parts of one audit. Record the exact reviewed commit, refs, assets, date, findings and unresolved exposure; a clean current tree alone is insufficient.

### Inspect tracked files and Git LFS

Audit every tracked file, including hidden files and any Git LFS objects, for private content, credentials, private URLs, absolute home paths and machine/account identifiers. The owner permits their own name and email; that exception does not cover other people’s information or personal recordings.

Inspect binary files and images as well as text. Distinguish visible artwork from embedded creator metadata, device labels and screenshots of real notes. Record what was inspected, at which commit, and any unresolved exposure. Do not treat deleting a current-tree file as removing it from Git history; the history review below must cover it too.

### Review reachable history and release assets

The repository is already public, so private material in older commits remains an exposure even if it has been removed from the current tree. Review every reachable branch, tag and release, including historical local configuration, recordings, generated copies and binary metadata.

For any finding, assess what was exposed and what remediation is needed, such as credential rotation or a sanitized public history/repository. Preserve an appropriate archival copy before any destructive history operation and obtain authorization for that operation. Record reviewed refs, release assets and remaining limits. Current-tree cleanup alone cannot complete this task.

### Review fixture provenance and attribution

Review demonstration data, evaluation inputs, expected outputs and generated reports for accidental personal content. Fictional labeling must be clear, and replacing names in private prose does not make it an independently synthetic fixture.

The owner previously approved the specific side-project evaluation recording and matching transcript copies, reviewed literary recordings, and fan-created TNG material. These are narrow historical approvals, not permission to add other personal recordings or use personal folders for testing. The TNG reference corpus remains unused by active suites until it is deliberately migrated and reviewed.

Check any newly created content independently, retain applicable attribution and no-affiliation notices, and record the exact reviewed scope and date. Any new personal-content discovery resets the affected publication/privacy review.

### Check preventive safeguards

Review ignore rules, build/test scripts and release workflows to prevent accidental publication of local configuration, caches, recordings, generated outputs, signing material and build artifacts.

A machine-specific local Claude configuration was removed from the current tree and given an exact ignore rule, but it remains in older history. Verify that broader safeguards cover future files rather than relying on that one exception. Tests and evaluation commands must use isolated data and synthetic fixtures; microphone checks require explicit confirmation. Record gaps without automatically adding unrelated cleanup tasks.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Tracked text, hidden files, Git LFS objects, binaries and images are reviewed for private content, credentials and identifying metadata, respecting only the stated narrow owner exceptions.
- [ ] #2 Reachable branches, tags and release assets are reviewed, with exposure and proposed remediation recorded; destructive history changes require separate authorization.
- [ ] #3 Demo and evaluation material is reviewed for provenance, personal content, attribution and fictional labeling; the unused TNG corpus remains outside active suites.
- [ ] #4 Ignore rules and build, test and release tooling are reviewed for accidental publication risks and isolated synthetic-data use.
- [ ] #5 The audit records its exact scope, dates, unresolved findings and required remediation without presenting historical approvals or current-tree deletion as a complete privacy guarantee.
<!-- AC:END -->

---
id: TASK-25
title: Review signing and quarantine removal
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:09'
labels:
  - publication
dependencies: []
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Review the trust implications of distributing an ad-hoc-signed, non-notarized macOS application whose Homebrew cask removes quarantine. Installation instructions should state this plainly and direct users to the intended release source.

Verify that quarantine removal targets only the intended application bundle, signatures and checksums are checked as documented, and no broader filesystem path is affected. This review does not introduce Developer ID signing or a new distribution channel.
<!-- SECTION:DESCRIPTION:END -->

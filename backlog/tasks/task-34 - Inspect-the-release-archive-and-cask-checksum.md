---
id: TASK-34
title: Inspect the release archive and cask checksum
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:09'
labels:
  - release
dependencies: []
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Build and inspect the release app and ZIP before publication. Verify executable architecture, bundled native libraries and resources, prompts, required notices and absence of developer-only files or private configuration.

Check app/CLI signatures and that their library paths resolve to bundled resources rather than a developer’s Homebrew installation. Calculate the final archive checksum and match it exactly to the source cask and public tap. If the archived bits or cask change, repeat the affected checks. Record the inspected version, commit, archive identity and findings.
<!-- SECTION:DESCRIPTION:END -->

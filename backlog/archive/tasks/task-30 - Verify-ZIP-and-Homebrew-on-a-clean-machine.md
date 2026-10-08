---
id: TASK-30
title: Verify ZIP and Homebrew on a clean machine
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:16'
labels:
  - distribution
dependencies: []
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Verify both the published ZIP and Homebrew installation on a clean macOS account or another Apple Silicon Mac, without development tools or existing model caches. Test public install commands, first launch, downloads, recording, processing, search and the bundled CLI.

Previous installation checks on the development machine confirmed the app/CLI paths, quarantine handling, model downloads and uninstall behavior. They do not replace a clean-machine check. Confirm user logs and configuration survive uninstall, optional cleanup only targets managed models, and source requirements are not accidentally required by the shipped app. Record the tested release, machine and unresolved issues.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Historical public-cask test: app installation, bundled CLI, quarantine removal, first-run model setup and strict cask audit passed on the development machine. Optional uninstall cleanup removed managed model folders through Trash while retaining the config checksum and default logs. That run downloaded approximately 5.7 GB in Application Support and 2.9 GB in Caches; these are observed cache sizes, not guaranteed requirements. Clean-account/second-machine acceptance remained open.

October 8, 2026: Consolidated into TASK-36 at the owner’s request. Its scope and any historical findings are preserved in that task. Archived as a superseded planning item, not completed implementation.
<!-- SECTION:NOTES:END -->

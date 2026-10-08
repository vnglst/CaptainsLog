---
id: TASK-32
title: Verify a published Homebrew upgrade and relaunch
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:16'
labels:
  - distribution
dependencies: []
ordinal: 32000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Verify a real published old-to-new Homebrew app upgrade, automatic replacement and OS relaunch. Synthetic updater fixtures check command flow and scheduling but cannot establish that the installed app is successfully replaced and restarted.

Confirm launch/daily checks, persisted preferences, manual controls, visible failure/retry behavior and idle gating for recording, queued/reserved processing and model setup. Check checksum enforcement, duplicate restart prevention and successful operation after relaunch. Keep the previous archive and cask revision available for rollback.

Historical fixture runs passed simulated check/install/check, preference persistence and SSH-to-HTTPS tap fetching while preserving stored remotes. Some full-suite runs were blocked by an unrelated disk-capacity guard or by the installed app running. No real upgrade/relaunch was performed in those checks; record fresh release-specific evidence.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
October 1, 2026 historical checks: build and updater-specific tests passed, including a simulated checksum-required upgrade, idle scheduling, default/disabled preferences, network failures, malformed casks, retry and duplicate-restart guards. The original full suite passed 183/190, later 193/200, because seven unrelated transcription/pipeline checks stopped at a zero-capacity disk guard. Native fixture launch also failed before UI inspection. A real metadata check encountered SSH transport errors; a temporary HTTPS Git wrapper fixed that check without changing other taps. No installed-version replacement or OS relaunch was verified.

October 2 integration had two updater test failures while the real installed app was running, because the install guard checks running-app state even with fake transport. Close or isolate that prerequisite for a valid fixture check rather than labeling the updater flow broken. These historical outcomes do not close the real published-upgrade task.

October 8, 2026: Consolidated into TASK-36 at the owner’s request. Its scope and any historical findings are preserved in that task. Archived as a superseded planning item, not completed implementation.
<!-- SECTION:NOTES:END -->

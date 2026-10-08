---
id: TASK-43
title: Use Make to manage and execute repository scripts
status: Next
assignee: []
created_date: '2026-10-07 15:17'
updated_date: '2026-10-08 16:49'
labels: []
dependencies: []
references:
  - scripts/README.md
  - backlog/tasks/task-42 - Reduce-agent-navigation-and-evaluation-overhead.md
documentation:
  - README.md
  - docs/0007-framework-free-test-coverage.md
  - docs/0010-tag-driven-homebrew-releases.md
type: chore
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Use Make as the discoverable workflow entry point; retain specialized scripts and coordinate evaluations with TASK-42.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Root Makefile exposes help, build/package/test/coverage/eval/validation/release targets; every script has a target or documented helper/direct-command exception.
- [ ] #2 Forward documented arguments/environment and propagate failures.
- [ ] #3 Serialize inference even with parallel Make; preserve release gates/model reuse.
- [ ] #4 Use isolated eval fixtures, bypass demo seeding and retain microphone confirmation.
- [ ] #5 Create numbered ADR via adrs: rationale, alternatives, compatibility, wrapper/script responsibilities, serialization; link related ADRs/task.
- [ ] #6 Align README, script/contributor/eval/release guidance and prerequisites; require no Xcode.
- [ ] #7 Verify targets, forwarding, failures, parallel safeguards and affected fixture/required checks; update changelog.
<!-- AC:END -->

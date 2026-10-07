---
id: TASK-43
title: Use Make to manage and execute repository scripts
status: Next
assignee: []
created_date: '2026-10-07 15:17'
updated_date: '2026-10-07 15:57'
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
Build, test, evaluation, packaging and release commands currently require contributors and agents to discover individual Bash and Swift scripts and their invocation details. Adopt Make as the documented command entry point so common workflows are easy to discover and run consistently while retaining specialized script logic where appropriate. Include an ADR explaining why Make fits this command-line Swift project and the tradeoffs against direct script invocation and other task runners. Coordinate evaluation entry points with TASK-42; broader evaluation selection, evidence and runtime changes remain in that task.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A root Makefile provides discoverable help and documented targets for the supported build, app packaging, test, coverage, evaluation, validation and release workflows; each existing repository script has a documented target or an explicit reason to remain a helper or direct command.
- [ ] #2 Targets forward documented arguments and environment settings correctly and propagate script failures as nonzero exits.
- [ ] #3 Model-backed targets execute sequentially, including when Make is invoked with parallel jobs; existing release checks and model reuse behavior are preserved.
- [ ] #4 Fixture checks use repository eval inputs and isolated temporary config/data, bypass demo seeding, and preserve explicit confirmation for microphone capture.
- [ ] #5 A numbered ADR created with adrs records the Make decision, rationale, alternatives and consequences, including tool compatibility, wrapper versus script responsibilities, and sequential inference constraints; it links relevant existing ADRs and this task.
- [ ] #6 README.md, scripts/README.md and affected contributor, evaluation and release guidance consistently document Make entry points and prerequisites; the CLI remains usable without Xcode.
- [ ] #7 Representative targets and argument forwarding are verified, failure propagation and parallel invocation safeguards are checked, and affected fixture workflows and existing required checks pass; CHANGELOG.md records the delivered changes.
<!-- AC:END -->

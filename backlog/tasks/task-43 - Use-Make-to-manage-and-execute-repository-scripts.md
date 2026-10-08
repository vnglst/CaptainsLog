---
id: TASK-43
title: Use Make to manage and execute repository scripts
status: Next
assignee: []
created_date: '2026-10-07 15:17'
updated_date: '2026-10-08 17:04'
labels: []
dependencies: []
type: chore
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Build, test, evaluation, packaging and release workflows are spread across Bash and Swift scripts. Contributors and agents have to discover each script and remember its arguments.

Add a root Makefile as the documented entry point, with help that lists supported workflows and their options. Keep specialized logic in the existing scripts where appropriate, forward arguments and environment settings correctly, and make failures visible. Model inference must remain sequential even when Make is run with parallel jobs, because the models share limited GPU memory.

Document the Make decision and its tradeoffs in an architecture decision record. Preserve isolated fixture data, explicit microphone confirmation and command-line builds without Xcode. Coordinate evaluation targets with TASK-42; do not redesign evaluation selection, evidence or model behavior here.
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

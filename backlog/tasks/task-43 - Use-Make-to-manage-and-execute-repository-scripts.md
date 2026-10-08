---
id: TASK-43
title: Use Make to manage and execute repository scripts
status: Next
assignee: []
created_date: '2026-10-07 15:17'
updated_date: '2026-10-08 17:57'
labels: []
dependencies: []
type: chore
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Use Make for all repository development activities: building, running the app, tests, evaluations, packaging and releases.

Provide the commands make build, make run, make tests, make evals, make packaging and make release. Running plain make starts the app in dev mode. Additional supporting targets may be chosen as needed for iteration. Use standard Make variables for options, with the agent choosing suitable defaults and details during implementation.

Make commands drive the workflows. Maintain scripts only when they are needed to run the Make commands, and keep necessary background scripts in the scripts directory.

The owner will run these commands to check that they work.
<!-- SECTION:DESCRIPTION:END -->

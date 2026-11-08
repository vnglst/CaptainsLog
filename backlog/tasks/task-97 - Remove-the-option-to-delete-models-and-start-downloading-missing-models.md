---
id: TASK-97
title: Remove the option to delete models and start downloading missing models
status: Next
assignee: []
created_date: '2026-11-08T15:35:00Z'
labels: []
dependencies: []
ordinal: 88000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Remove the option to delete models and all the code that is making this work. Start downloading models if you detect that they haven’t downloaded yet. So first user should immediately see notification that downloading has started. Also check startup time, if that still matches original optimized baseline. Add a test for startup time to make sure we don’t have regressions there.
<!-- SECTION:DESCRIPTION:END -->

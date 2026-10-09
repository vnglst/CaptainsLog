---
id: TASK-48
title: Enable local review of completed PBIs with video demos and agent feedback
status: To Do
assignee: []
created_date: '2026-10-09 19:09'
updated_date: '2026-10-09 19:11'
labels: []
dependencies: []
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The owner does not want agent-generated material published directly to GitHub because automated publishing could leak sensitive data. Keep that material on the local machine. Provide a local alternative outside GitHub and Codex for reviewing a completed list of PBIs. Review is primarily about app behavior rather than code. The video is the most important part of the review.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each PBI review includes a short description and a few steps the owner should take or check.
- [ ] #2 Every review includes a video demonstrating what changed or that the app still works.
- [ ] #3 Review videos contain no private data.
- [ ] #4 The owner can give feedback that is fed back to the agent working on the PBI and picked up once that agent is ready to resume.
- [ ] #5 The owner can inspect the code changes; opening them in VS Code is sufficient.
- [ ] #6 Agent-generated review material remains on the local machine and is not published directly to GitHub.
- [ ] #7 When an agent delivers work, the owner can easily open its worktree.
- [ ] #8 The review flow is straightforward: click to open the delivered work, watch the video, see the changed files, then approve or give feedback.
<!-- AC:END -->

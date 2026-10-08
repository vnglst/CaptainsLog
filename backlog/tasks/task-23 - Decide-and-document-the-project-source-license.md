---
id: TASK-23
title: License CaptainsLog under MIT and reference third-party licenses
status: Next
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:53'
labels:
  - publication
dependencies: []
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
License CaptainsLog's own source code under the MIT license. The owner chose MIT during backlog refinement on 2026-10-08 and requested conventional open-source license organization with references to third-party licenses.

Use the standard MIT license text for the project's code and reference separate third-party notices alongside it, keeping the components' own license terms intact. Review the shipped dependency set, font, native runtime, downloaded models and approved fixture attributions. Preserve the Antonio font's SIL Open Font License, sqlite-vec's MIT/Apache notices, applicable Swift package and llama.cpp notices, and model-source/license information. Verify that the release app contains the required notice copies. Record any rights questions before announcing a release.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 CaptainsLog's own source code is licensed under MIT using the standard license text.
- [ ] #2 Third-party licenses are referenced alongside the project license using conventional open-source organization, while retaining their own terms and notices.
<!-- AC:END -->

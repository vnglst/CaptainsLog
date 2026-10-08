---
id: TASK-12
title: Prove Kev checkpoint and runtime compatibility
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:09'
labels:
  - kev
dependencies: []
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A Kev model loading successfully does not prove that CaptainsLog can use its trained decision head. Establish exact checkpoint and llama.cpp runtime compatibility before attempting product integration.

Start with a compatible Kev 4B Q8 conversion and verify the checkpoint, conversion provenance, license, calibration information and checksum. Pin model and runtime revisions. Community weight-file sizes are download estimates, not measured runtime memory. Verify that the installed and packaged native runtime exposes the required decision head and numeric probability readout.

Build a small Swift CLI experiment using in-process libllama, then compare fixed requests with the model’s reference implementation or published reference outputs. Validate finite probabilities and allowed choices; loading only a Qwen backbone is insufficient. Keep Qwen as the production default and do not add a cloud, Python inference service, daemon or separate model server.
<!-- SECTION:DESCRIPTION:END -->

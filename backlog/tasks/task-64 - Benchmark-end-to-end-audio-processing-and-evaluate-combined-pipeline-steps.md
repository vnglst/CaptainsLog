---
id: TASK-64
title: Benchmark the processing pipeline
status: To Do
assignee: []
created_date: '2026-10-16 06:18'
updated_date: '2026-10-16 06:23'
labels: []
dependencies: []
type: enhancement
ordinal: 57000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
First benchmark the current time it takes to process an audio file all the way to the end of the processing pipeline. Try a small audio file and a larger file. Target hardware would be just this Mac. Look at what steps can be combined: metadata, renaming and categorizing can maybe be combined into one step. Transcription is a separate step. Iterate, look at the evals to see if it still delivers the same results, and measure how much that improves the overall processing speed.
<!-- SECTION:DESCRIPTION:END -->

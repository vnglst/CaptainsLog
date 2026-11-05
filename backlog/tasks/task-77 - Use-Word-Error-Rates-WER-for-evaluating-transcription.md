---
id: TASK-77
title: Use Word Error Rates (WER) for evaluating transcription
status: Next
assignee: []
created_date: 2026-10-27 18:29
updated_date: '2026-11-05T08:01:00Z'
labels: []
dependencies: []
ordinal: 68000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
This replaces the current setup for evaluating transcription.

- Build an eval for transcription around the Dutch TNG recording first. For now, do only audio. Check if I made mistakes while reading the generated text.
- Do transcription yourself or use a different model you have access to.
- Make a list of specific passages for me to check and verify.
- Make it easier for me to review: side-by-side text + audio fragments in an app.
- Make the eval app part of the eval suite.
- The Dutch TNG recording can be used in the demo/dev app as well. In the future I will add the German + English recordings.
- In some cases the audio is corrupted/incorrect. Add recording of corrected audio in the UI.
- Combine/consolidate this into one audio recording.
- Make sure the design aligns with the app, same style.
- Make it easier for me to find the right location.
- I should be able to select correct recording device.
- Make the UI clearer, with clear primary actions.
- Do a second review with the corrected audio.
- How do I go back to the overview? Fix the UI and make sure the app is usable.
- If a review is done, it should be marked as such. Make sure it is possible to reach that state in a logical manner.
- This is our first new transcription eval. Clean up, keeping the intermediate steps (how we got here and the web app that got us there), but make sure the eval is simple and organized.
- Remove old transcription evals. Review other recordings at some other time; for now, these are not part of transcription eval.
<!-- SECTION:DESCRIPTION:END -->

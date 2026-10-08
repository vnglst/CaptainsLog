---
name: transcription-eval
description: Assess transcription quality for CaptainsLog by comparing Whisper-generated output against ground truth. The agent reads both files and documents word-level differences manually.
---

# Transcription review

Run fixtures through [scripts/run-evals.sh](../../scripts/run-evals.sh); see [the shared workflow](../../README.md#fixture-evaluations) for stage/case selection, saved runs, metadata and baselines. The runner owns isolation and output names. Review the selected cases from its printed `review.md`; required release runs still include all suites and the full pipeline.

## Stage review

Read the expected text and original uncleaned generated transcript word by word. Never substitute cleaned output for raw transcription.

- List meaning-changing substitutions as expected → generated.
- List missing and added content words, including invented phrases and markers.
- Explain semantic consequences of changed names, merged words, numbers or topics.
- Ignore capitalization, punctuation and name-spelling variants unless they alter identity or meaning.

Optional `scripts/compare.swift` in this skill offers alignment heuristics. Verify every result manually; word merging and hyphenation can misalign it.

## Reporting

Use each case's generated `report.md` and the [shared concise report format](../../README.md#semantic-review). Read every selected case, record concrete differences and semantic impact, and identify regressions or improvements when a baseline is available. Avoid generic judgments such as “mostly good.” Mechanical checks and heuristic scores never replace semantic review or the owner's final judgment.

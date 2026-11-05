---
name: transcription-eval
description: Assess transcription quality for CaptainsLog by comparing Whisper-generated output against ground truth. Use aligned Word Error Rate measurements and review concrete word-level differences against a verbatim reference.
---

# Transcription review

Run fixtures through `make evals STAGE=transcribe`; see [the shared workflow](../../README.md#fixture-evaluations) for stage/case selection, saved runs, metadata and baselines. The runner owns isolation and output names. Review the selected cases from its printed `review.md`; model evaluations run separately from release preparation. For dependency upgrades, new features or significant refactors, follow the build, test and sequential fixture pipeline checks in [AGENTS.md](../../AGENTS.md#development).

## Listening app

Runs containing audio prepare a listening-review app. Reopen it with
`make evals-review RUN_DIR=...`; optionally add `COMPARISON_RUN=...` for a saved
run or directory of per-recording `.txt` transcripts. This serves saved evidence
without inference. Side-by-side text, clipped playback, replay, speed and loop
controls support owner verification. Exact words and decisions persist per run in
`review-app/review-state.json` and can be exported.

Use only the selected run's raw transcription. Segment definitions under
`eval/transcribe/review/` pin audio/reference hashes and word offsets; stale offsets
fall back to the full recording. Comparison outputs and approximate alignment
remain navigation aids. Audio/reference changes invalidate earlier verification,
without discarding the owner's saved text. The app does not edit fixture references
or promote their status automatically. For bad audio, flag the original passage,
record/preview a separate replacement take and explicitly select it. The corrected
recording action exports an M4A plus an edit map; it rejects overlapping ranges and
preserves the original fixture. Do not start real microphone capture during agent
verification; use synthetic capture tests and repository audio fixtures.

For a new two-model discrepancy review, use `make evals-review RUN_DIR=...
COMPARISON_RUN=... ARGS=--differences` (on one command line). The comparison folder
contains per-recording `.txt`, whisper.cpp full JSON timestamps and `.run.json`
with matching audio/output hashes. Timestamped comparisons automatically select
this mode; saved reviews remember it. Passages are selected from both complete
word alignments, including omissions and final insertions. Each clip must contain
a difference in at least one model; per-model edit counts distinguish shared and
model-specific discrepancies. Matching segments are not generated as error items.
Keep the older completed checklists and their owner decisions as history; generate
a separate comparison run rather than replacing their passage contexts. Times
are approximate model segment boundaries with listening context.

## Stage review

Read the expected text and original uncleaned generated transcript word by word. Never substitute cleaned output for raw transcription.

- List meaning-changing substitutions as expected → generated.
- List missing and added content words, including invented phrases and markers.
- Explain semantic consequences of changed names, merged words, numbers or topics.
- Ignore capitalization, punctuation and name-spelling variants unless they alter identity or meaning.

## Word Error Rate

Use the standard [WER definition](https://github.com/huggingface/evaluate/blob/main/metrics/wer/README.md).

The runner scores every transcription case, including pipeline transcription, with
`WER = (substitutions + deletions + insertions) / reference words`. It writes
`wer.json` and `wer.md` beside each review and a word-weighted aggregate in
`transcription-scores.json`. Scores may exceed 100%. A score is a measurement,
not a semantic pass or an arbitrary accuracy threshold.

Normalization `unicode-words-v1` applies Unicode NFC, lowercase, curly-to-straight
apostrophes and Unicode word tokenization. Punctuation and whitespace are ignored;
hyphens separate words. Internal apostrophes and diacritics remain. Numbers are
not expanded and names are not aliased. Unit-cost Levenshtein ties prefer diagonal,
then deletion, then insertion. This policy is recorded in every score.

`eval/transcribe/cases.json` pins audio/reference hashes and reference status for
every recording. Keep scripts separate from verbatim references. Compare script
and raw transcript first, then check differences against the audio. Never turn
the system under test's output into its own ground truth. Record confirmed reading
slips in the verbatim reference, preserving the original script. Use `model-assisted` after a separately identified model comparison; retain a
passage checklist for owner listening and never equate model agreement with
verified speech. Only mark a reference `audio-reviewed` after independent audio
review. Every other status produces provisional scores.
If audio cannot be independently checked, report the uncertainty and request
owner confirmation of the exact suspected reading differences.

The comparison helper uses the same scorer:
`swift skills/transcription-eval/scripts/compare.swift --expected PATH --generated PATH`.
Alignment positions are zero-based normalized word offsets. Review the full
context; alignment does not distinguish reading slips from recognition errors.

## Reporting

Use each case's generated `report.md` and the [shared concise report format](../../README.md#semantic-review). Read every selected case, record concrete differences and semantic impact, and identify regressions or improvements when a baseline is available. Avoid generic judgments such as “mostly good.” Mechanical checks and heuristic scores never replace semantic review or the owner's final judgment.

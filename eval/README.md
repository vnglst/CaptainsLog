# Evaluation fixtures

Active stages are `transcribe`, `cleanup`, `categorize`, `filename` and `enrich`.
Transcription inputs live in `transcribe/audio/`; text-stage inputs live in each
stage's `input/`. Expected outputs are semantic references, not the only valid
wording. The reviewed Dutch TNG recording is the single active transcription fixture.
End-to-end evaluation remains separate follow-up work (TASK-82).

Use the runner from the repository root:

```sh
make evals-list
make evals STAGE=filename CASE=01_single_topic
make evals-pipeline
make evals-suites
make evals ARGS="--validate-run RUN_DIR"
```

The runner snapshots fixtures, isolates config/data, records model/runtime
identity, and prints a review bundle under its temporary run directory. Text
cases reuse one model sequentially with fresh contexts and samplers. Stage `history/generated/` and `history/reports/` folders preserve previous results; new run bundles contain their own outputs, validation and per-case reports.

See [evaluation commands and isolation](../README.md#fixture-evaluations) and the
[stage review skills](../skills/) for semantic review. Discovery and saved-run
validation do not load inference models. Generation requires the selected models;
never run concurrent inference jobs or use personal recordings. Model evaluations
run separately from release preparation.

## Transcription

The only active case is **Een vrije dag op de Enterprise**, the corrected Dutch
recording accepted by the owner after two listening rounds on 2026-10-30.

- Audio: `transcribe/audio/tng-nl01-vrije-dag-enterprise-corrected.m4a`
- Verbatim reference: matching file in `transcribe/expected/`.
- Manifest: `transcribe/cases.json` pins both hashes and `audio-reviewed` status.
- Passage timing and provenance: matching files in `transcribe/review/`.

Run `make evals STAGE=transcribe` for the single WER case. Full pipeline evaluation is separate follow-up work (TASK-82). Every run snapshots
inputs, raw output and an aligned WER report. WER measures word edits; semantic
review still matters, especially for hallucinations and changed meaning.

Earlier recordings are **not active transcription evaluations**. Their audio,
references and timing definitions live in `transcribe/history/` for later review
and existing synthetic regression checks. Text-stage fixtures remain independent.

The two preserved review rounds in `transcribe/history/review-1/` and `review-2/`
contain raw outputs, measurements, owner decisions, replacement takes, timing maps
and the browser review app. Reopen either with, for example:

```sh
make evals-review RUN_DIR=eval/transcribe/history/review-2
```

The [TNG scripts](tng-reference/README.md) preserve the original script separately
from the verbatim reference. English and German recordings are still to be supplied.
The development demo copies the reviewed Dutch audio into its isolated runtime.
The existing pipeline configuration is retained in `pipeline/cases.json`; its
downstream references have not been verified as part of the audio-only baseline.

## Listening review

For a new comparison, generate passages from both full word alignments:

```sh
make evals-review RUN_DIR=RUN COMPARISON_RUN=COMPARISON PORT=8779 ARGS=--differences
```

The comparison directory must retain each recording’s `.txt`, whisper.cpp full
JSON timestamps and `.run.json` with matching audio and output hashes. New
comparison reviews remember this mode on reopening. Every selected clip contains
at least one word difference in one or both models; matching segments are not
created as review items. Clip boundaries follow timestamped comparison segments
with context padding. Both models’ substitutions, omissions and insertions,
including invented endings, contribute to selection across the whole recording.
The prior completed checklists remain preserved as history.

The pinned [two-model discrepancy review](transcribe/history/comparisons/2026-11-05-whisper-v2-v3/README.md)
contains only the four remaining recordings. The completed Dutch TNG review remains visible as completed; its contents and
eval are unchanged and excluded from the new pending review; these historical comparisons do not add active transcription evals.

Every saved run containing transcription prepares `review-app/`. Use
`make evals-review RUN_DIR=...` to serve it locally, optionally adding
`COMPARISON_RUN=...` for another eval run or a directory of per-recording `.txt`
transcripts. The reference and raw output come from that run, not a global search
for whatever output is newest. Audio must match a pinned synthetic fixture.

`transcribe/review/` stores listening times and reference word ranges for the active
recordings. Definitions pin the audio and reference hashes; when a reference
changes, the app falls back to the full recording until those offsets are updated.
Additional recordings work without segment definitions, using their full audio.
Only passages containing actual word differences appear in transcript review.
There is no matching-text toggle. Passage titles quote the relevant wording;
transcript columns retain model identities. The overview shows the current recordings plus completed history. Completed
reviews have a secondary Open action and are never added to the pending queue.
Text agreement does not verify audio or change saved decisions.
Text alignment is approximate and is not proof of the spoken wording.

Decisions and exact wording persist in the run's `review-app/review-state.json`.
Regenerating assets preserves this file. Audio/reference changes prevent earlier
verification from silently applying to new wording, while preserving the saved
text. Only explicit owner verification establishes a verbatim reference; the app
never applies corrections or marks fixtures verified automatically.

For corrupted or incorrectly read audio, mark the original passage and use
**Record replacement**. Stop, preview and save the take; then select it for the
corrected recording. Takes remain in the run's `review-app/assets/retakes/`.
You can adjust a saved take's original replacement range inside its passage.
**Build corrected recording** joins selected takes with untouched original spans
into `assets/consolidated/*.m4a`, with a JSON edit map recording original/corrected
times and source/replacement/output hashes. Overlapping replacements are rejected.
Neither recording nor consolidation modifies fixtures or reruns inference.

Capture starts only with the Record button and browser microphone permission.
The browser converts captured audio locally to mono 16 kHz PCM WAV, with a ten
minute limit per take. Native AVFoundation exports the combined M4A. Optional
capture lifecycle tests run with `node --test scripts/tests/review-capture.mjs`;
`make tests-evals` covers storage and native consolidation with repository fixtures.

The fresh owner-reviewed Dutch baseline is preserved in `transcribe/history/baselines/2026-10-30-whisper-large-v2/`: WER 3.66% (44 edits / 1,203 words). Its report retains the remaining recognition errors and ungrounded Korean ending.

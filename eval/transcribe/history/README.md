# Transcription history

`cases.json` explicitly labels recordings that have not been reviewed and the superseded original Dutch recording.

These recordings are excluded from active transcription evaluation selection.
`cases.json` preserves their original hash/status records. Some are still used as
synthetic audio or text by non-inference regression tests.

- `audio/`, `expected/`, `review/`: original recordings, references and passages.
- `review-1/`: initial native/model comparison, owner wording corrections and takes.
- `review-2/`: corrected recording, native raw transcript, 3.66% WER measurement,
  owner decisions and inherited verification for unchanged passages.

Each review retains its manifest, input/output snapshots and `review-app/` with
saved decisions and audio. Reopen with `make evals-review RUN_DIR=eval/transcribe/history/review-1`
or `RUN_DIR=eval/transcribe/history/review-2`. The maintained app implementation is
in the tooling resources; preparing a historical review refreshes those UI assets
without rewriting owner decisions. Historical scores retain the reference status
recorded at the time; the active case now has owner-reviewed status.

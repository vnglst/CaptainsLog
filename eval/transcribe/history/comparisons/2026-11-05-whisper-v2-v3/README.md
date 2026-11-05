# Transcript review · remaining recordings

The review passages are selected from complete word alignments of both Whisper models against each recording’s reference. A passage must contain a difference in at least one model. Passage titles follow **Topic: specific issue to check**, such as **Kheled-zâram: name spelling**; model identities remain available above the transcripts. Matching context inside an error clip is retained for listening; error-free clips are not selected.

This review contains the completed comparisons for Alle mensen zijn sterfelijk,
Durins volk and World War Z. TNG appears as a completed recording in the overview.
Side project audio and decisions are retained as historical evidence. The four
reviewed recordings are active transcription cases. Comparison model identity,
timestamps and logs are under `comparison/`, with native metadata under
`provenance/`.

Rebuild or open the discrepancy review without inference:

```sh
make evals-review RUN_DIR=eval/transcribe/history/comparisons/2026-11-05-whisper-v2-v3 COMPARISON_RUN=eval/transcribe/history/comparisons/2026-11-05-whisper-v2-v3/comparison PORT=8779 ARGS=--differences
```

Inspect the reference and both model outputs in every clip. Model agreement does not prove the spoken wording. Names, number formatting and compound tokenization can produce word edits without equivalent meaning changes; omissions, changed content and invented endings still require listening review.

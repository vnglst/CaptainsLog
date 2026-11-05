# Transcript review · remaining recordings

The review passages are selected from complete word alignments of both Whisper models against each recording’s reference. A passage must contain a difference in at least one model. Passage titles follow **Topic: specific issue to check**, such as **Kheled-zâram: name spelling**; model identities remain available above the transcripts. Matching context inside an error clip is retained for listening; error-free clips are not selected.

This review contains Side project, Alle mensen zijn sterfelijk, Durins volk and World War Z only. TNG stays visible in the overview as completed, with a secondary Open action. It is excluded from the pending manifest; its completed reviews and active eval are preserved. Large-v2 native outputs and matching-audio Large-v3 comparisons are preserved from the earlier runs. Comparison runtime/model identity, output/audio hashes, timestamps and logs are retained under `comparison/`; native metadata is under `provenance/`. Times come from Large-v3 segments with 0.75-second context padding and are approximate.

These four recordings remain excluded from active transcription evals; this review does not promote their references. Existing review rounds, owner decisions, takes and active baseline remain unchanged.

Rebuild or open the discrepancy review without inference:

```sh
make evals-review RUN_DIR=eval/transcribe/history/comparisons/2026-11-05-whisper-v2-v3 COMPARISON_RUN=eval/transcribe/history/comparisons/2026-11-05-whisper-v2-v3/comparison PORT=8779 ARGS=--differences
```

Inspect the reference and both model outputs in every clip. Model agreement does not prove the spoken wording. Names, number formatting and compound tokenization can produce word edits without equivalent meaning changes; omissions, changed content and invented endings still require listening review.

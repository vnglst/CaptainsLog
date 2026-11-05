# Whisper discrepancy review · 2026-11-05

The review passages are selected from complete word alignments of both Whisper models against each recording’s reference. A passage must contain a difference in at least one model. Model-specific and shared differences are labelled separately. Matching context inside an error clip is retained for listening; error-free clips are not selected.

Large-v2 native outputs are preserved from the earlier runs. Large-v3 uses the same audio hash for every pair; corrected Dutch Large-v3 was run anew on 2026-11-05. Comparison runtime/model identity, output/audio hashes, timestamps and logs are retained under `comparison/`; native metadata is under `provenance/`. Times come from Large-v3 segments with 0.75-second context padding and are approximate.

Only the corrected Dutch reference is owner-verified. The other four recordings remain excluded from active transcription evals; this review does not promote their references. Existing review rounds, owner decisions, takes and active baseline remain unchanged.

Rebuild or open the discrepancy review without inference:

```sh
make evals-review RUN_DIR=eval/transcribe/history/comparisons/2026-11-05-whisper-v2-v3 COMPARISON_RUN=eval/transcribe/history/comparisons/2026-11-05-whisper-v2-v3/comparison PORT=8779 ARGS=--differences
```

Inspect the reference and both model outputs in every clip. Model agreement does not prove the spoken wording. Names, number formatting and compound tokenization can produce word edits without equivalent meaning changes; omissions, changed content and invented endings still require listening review.

# Reviewed Dutch transcription baseline

Fresh audio-only baseline from 2026-10-30: **WER 3.66% (44 / 1,203)**.

`input.m4a`, `expected.md` and `transcript.md` preserve the measured pair and raw output. `wer.json` / `wer.md` retain alignment; `report.md` explains semantic errors and the Korean-tail hallucination. `metadata.json` retains model/runtime identity, settings, revision, hashes and timings. No model/config cache is bundled.

Recheck the saved measurement without inference:

```sh
make evals ARGS="--validate-run eval/transcribe/history/baselines/2026-10-30-whisper-large-v2"
```

Generate a new isolated measurement with `make evals STAGE=transcribe`.

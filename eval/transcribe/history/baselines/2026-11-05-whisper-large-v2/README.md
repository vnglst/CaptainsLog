# Transcription baseline · 2026-11-05

Fresh local Whisper Large-v2 inference from revision `93abde3`. The four audio-reviewed references yielded a word-weighted **4.03% WER** (88 edits across 2,181 words). All raw outputs match the earlier saved Large-v2 transcripts byte for byte.

| Recording | Word errors | WER |
|---|---:|---:|
| Alle mensen zijn sterfelijk | 18 / 369 | 4.88% |
| Durins volk | 10 / 200 | 5.00% |
| Een vrije dag op de Enterprise | 44 / 1,203 | 3.66% |
| World War Z | 16 / 409 | 3.91% |

The [review index](review.md) links to source audio, verbatim references, raw transcripts, aligned edits and semantic reports. [Metadata](metadata.json) records the actual model and runtime, source hashes and timing. Mechanical validation passed on all four cases. The reports identify unresolved name errors, changed meaning and invented closing words.

Run a fresh measurement with `make evals STAGE=transcribe`. To check the saved outputs without inference, copy this directory under `tmp/` and run `make evals ARGS="--validate-run tmp/<copy>"`. The copied manifest points to the archived inputs and outputs.

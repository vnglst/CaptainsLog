# Enterprise end-to-end evaluation · 2026-11-05

`make evals-pipeline` processed the reviewed Enterprise recording from M4A through Whisper Large-v2 transcription and Qwen3.5-9B cleanup, categorization, naming and enrichment. The search check used the multilingual E5 model. The run started from revision `93abde3` with an isolated configuration.

All five stages passed mechanical validation. Transcription matched the fresh standalone baseline at **3.66% WER** (44 / 1,203). The entry was filed under `professional`, which the fixture accepts. Resume left all file hashes unchanged, and the search query returned the final note.

Cleanup removed Whisper's invented sign-off and restored the radiation and measurement sentence, but lost the event where Keiko collects Molly. The generated summary also says that Keiko joined lunch and that the planned Riker conversation already happened. The [stage reviews](review.md) retain the references, generated outputs and semantic findings. [Run metadata](metadata.json) records model and runtime hashes and elapsed time.

To rerun inference, use `make evals-pipeline`. To revalidate the saved stage files without inference, copy this directory under `tmp/` and run `make evals ARGS="--validate-run tmp/<copy>"`. Resume and search readback require a fresh pipeline run.

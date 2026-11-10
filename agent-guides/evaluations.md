# Fixture evaluations

Agent reference; read the relevant sections for the work at hand.
See [repository instructions](../AGENTS.md) for policy.

## Fixture evaluations

Run `make evals-list` to discover cases without loading models.
Use `make evals STAGE=filename CASE="fixture stem"` for focused work,
`make evals-pipeline` for the full audio fixture pipeline and `make evals-suites`
for all stage suites. Select the Dutch TNG pipeline with
`make evals-pipeline`; its default is the reviewed Dutch TNG recording. Plain `make evals` runs pipeline then suites. Quote stems
containing spaces; categorization and enrichment also use `STAGE`. Additional
evaluator flags are passed with `ARGS="..."`.

Revalidate a saved bundle with `make evals ARGS="--validate-run RUN_DIR"`; legacy
timestamped outputs support `ARGS="--validate-categorize STAMP"` and
`ARGS="--validate-enrich STAMP"`. Use `ARGS="--baseline RUN_DIR"` for comparison evidence. `ARGS="--combined-metadata"` evaluates experimental combined generation with fixture seeds defaulting to 42. `cl pipeline --combined-metadata` opts a fresh pipeline into the experiment; default processing keeps separate stages because semantic equivalence is not established. Individual stage commands retain their separate prompts. Missing models, malformed
outputs and existing run directories fail explicitly. `make tests-evals`
checks orchestration without inference.

Each run isolates config/data under a new temporary run directory, pins the selected
model files and snapshots fixtures. Model overrides use the `CAPTAINS_LOG_EVAL_`
QWEN_FOLDER, QWEN_FILE, QWEN_LABEL, WHISPER_FOLDER and WHISPER_MODEL variables;
`CAPTAINS_LOG_EVAL_RUN_DIR` selects a new run directory. Enrichment dates, times and
seeds come from its case manifest; the pipeline and other stages retain their
sampling defaults. Text cases reuse weights sequentially with fresh contexts and
samplers. Compile before inference; never edit a running evaluator or start another
model job concurrently. The [TNG reference folder](../eval/fixtures/tng-reference/README.md)
contains three personal log scripts aboard the Enterprise, each about ten
minutes long, in English, Dutch and German, with paired expected outputs.
The transcription suite includes three owner-reviewed Dutch recordings and one English recording.
The [fresh transcription baseline](../eval/suites/transcribe/history/baselines/2026-11-05-whisper-large-v2/README.md) measures all four recordings.
The [Enterprise pipeline run](../eval/suites/pipeline/history/2026-11-05-enterprise/README.md) covers audio through search. Earlier review rounds live under
`eval/suites/transcribe/history/`; English
and German TNG audio are still to be recorded by the owner.

For opt-in native startup and quit performance checks, close the installed app,
provide the prepared `CAPTAINSLOG_WHISPER_MODEL_FOLDER` and
`CAPTAINSLOG_QWEN_MODEL_FOLDER`, and run
`make tests-app-performance RUN_DIR=/absolute/new/output`. It uses only eval
fixtures and fresh isolated config/data, records real native decoding and process
termination, and does not use the microphone. See the
[native performance check](../scripts/README.md#native-performance-regression-check)
for timing scopes, hardware-dependent limits, retained evidence and abort behavior.

Audio evaluation runs also prepare a local listening-review app. Reopen a saved run
without loading models:

```sh
make evals-review  # Reopen the last review and passage in your browser
# Or choose a specific saved run:
make evals-review RUN_DIR=tmp/evals-RUN
# Optional: compare another saved run or a folder of per-recording .txt transcripts:
make evals-review RUN_DIR=tmp/evals-RUN COMPARISON_RUN=tmp/comparison-RUN
```

Open the printed localhost URL. The app pairs audio fragments with the selected
run's reference and raw transcripts, highlights differences, and saves your wording
and decisions in `review-app/review-state.json` inside that run. Export provides a
JSON copy. Mark corrupted or incorrect audio, record and preview a replacement,
then select the take to use. **Build corrected recording** exports one M4A with
approved replacements and an edit map for shifted timestamps. Original fixtures
stay intact; overlapping ranges must be adjusted before combining. Microphone
permission is requested only when you press Record. Regenerating the app preserves saved reviews; changed audio or reference
text requires verification again. Reviews do not overwrite fixture references.
Use `PORT=8778` for another local port or `ARGS=--prepare-only` to prepare files
without serving them. The app uses bundled Swift tooling and browser audio seeking;
Python, FFmpeg and additional model downloads are not required.

Transcription cases are pinned in `eval/suites/transcribe/cases.json`. Every transcription
review includes aligned Word Error Rate (`wer.json`, `wer.md`); the run's
`transcription-scores.json` contains a word-weighted aggregate. WER counts
substitutions, deletions and insertions against verbatim spoken words. Unverified
scripts and legacy references produce explicitly provisional scores until checked
against the recording; do not copy Whisper output into its own reference.
The normalization and alignment policy lives in the transcription review skill.

Evaluation bundles include source and generated text, validation results, model/runtime
identity, hashes, settings and timings. Heuristic scores do not establish completeness
or grounding; see the [semantic review guidance](../AGENTS.md#semantic-review).

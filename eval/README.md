# Evaluation fixtures

Active stages are `transcribe`, `cleanup`, `categorize`, `filename` and `enrich`.
Transcription inputs live in `transcribe/audio/`; text-stage inputs live in each
stage's `input/`. Expected outputs are semantic references, not the only valid
wording. The `2025-01-14 side project` recording exercises the full pipeline.

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
cases reuse one model sequentially with fresh contexts and samplers. Legacy
`generated/` and `reports/` directories retain older ignored outputs; new run
bundles contain their own outputs, validation and per-case reports.

See [evaluation commands and isolation](../README.md#fixture-evaluations) and the
[stage review skills](../skills/) for semantic review. Discovery and saved-run
validation do not load inference models. Generation requires the selected models;
never run concurrent inference jobs or use personal recordings. Model evaluations
run separately from release preparation.

The [TNG reference corpus](tng-reference/README.md) is retained material, not an
active suite. Demo inputs under `demo/` are presentation material.

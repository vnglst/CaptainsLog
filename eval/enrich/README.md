# Enrichment evaluations

Run `bash scripts/run-evals.sh --enrich` from the repository root. This runs every
input sequentially with isolated config/data and the date, time and sampling seed
in `cases.json`. It requires the local Qwen model, but not Whisper. Validate a
saved run with `bash scripts/run-evals.sh --validate-enrich <run-stamp>`.

The structural gate rejects unfinished inference, malformed or repeated YAML,
changed transcript bodies, incorrect supplied date/time, wrong list types,
duplicate names and excessive metadata. Expected files are semantic references;
review additions, omissions and summaries with
[`enrich-eval`](../../skills/enrich-eval/SKILL.md), even when the gate passes.

## Entity-list regression

`04_entity_list_loop.md` is an independently written, fictional Dutch rehearsal
about evaluating document assistants and research agents. Mila van Dalen and the
demonstration scenarios are invented. Recognizable company/product names are
examples, not claims about real deployments or relationships. The source contains
no request to generate repeated metadata.

The initial 5,084-word synthetic version reproduced native context exhaustion on
2026-10-08: **9,254 prompt tokens + 9,434 output tokens exhausted an allocated
18,688-token context**. The CLI exited 1 and wrote no completed output. Its trace
contained 1,846 identical `Lili` entity-list entries and no summary. This was a
fresh, ordinary, unbounded native invocation, not a diagnostic cutoff or injected
error.

Recorded baseline:

| Setting | Value |
|---|---|
| Source SHA256 | `ec8193ed72a53aaf919cef027b4cc445a96ebd4f7a5da9842fe4b2f1f4d0e658` |
| Code before fix | `556ef708fd6f9f4ac07408cc9689a5cbc2ac00db` |
| Model | `Qwen_Qwen3.5-9B-Q4_K_M.gguf` |
| Model SHA256 | `d784ce9eda1a5a7b51e8f705a9e6310844bf4f173654d115823c775fdea56d43` |
| Native runtime | llama.cpp 0.5.0 / GGML 0.25.3, Metal, M4 |
| Sampling | seed 42, temperature 0.3, top-k 40, top-p 0.9 |
| Repetition protection | none; original redundant sampler acceptance retained |
| Output budget | 0 (old unbounded mode) |
| Supplied date/time | 2026-10-05 / 16:44 |
| Speaker context | none |

Only seed passthrough and observational diagnostics/tracing were added to the
historical generation code. Discovery-only batch, state-restoration and
diagnostic-stop controls were disabled for the full failure.
[`baseline-observability.patch`](baseline-observability.patch) preserves a smaller
reproduction setup with none of those discovery controls. It also selects copied
legacy headers and explicitly loads the backend directory supplied through
`GGML_BACKEND_PATH`; it does not change sampling, decoding, budgets or errors.
Historical comparisons must use matching native headers and libraries;
substituting today's Homebrew libraries does not recreate that runtime.

For a historical run, supply absolute `CAPTAINS_LOG_BASELINE_LLAMA_DIR` (0.5.0),
`CAPTAINS_LOG_BASELINE_GGML_DIR` (0.25.3) and `CAPTAINS_LOG_BASELINE_QWEN_DIR` paths.
Use original unpacked runtime packages, not a Homebrew upgrade of the same paths.
From the repository root, prepare an isolated snapshot without changing the
working checkout:

```bash
REPO_DIR="$PWD"
mkdir -p tmp
REPRO_DIR="$(mktemp -d "$REPO_DIR/tmp/enrich-baseline-XXXXXX")"
git archive 556ef708fd6f9f4ac07408cc9689a5cbc2ac00db | tar -x -C "$REPRO_DIR"
git apply --directory="${REPRO_DIR#"$REPO_DIR/"}" eval/enrich/baseline-observability.patch
mkdir -p "$REPRO_DIR/Sources/CLlama/legacy-include"
cp "$CAPTAINS_LOG_BASELINE_LLAMA_DIR/include/llama.h" "$REPRO_DIR/Sources/CLlama/legacy-include/"
cp "$CAPTAINS_LOG_BASELINE_GGML_DIR/include/"*.h "$REPRO_DIR/Sources/CLlama/legacy-include/"
export DYLD_LIBRARY_PATH="$CAPTAINS_LOG_BASELINE_LLAMA_DIR/lib:$CAPTAINS_LOG_BASELINE_GGML_DIR/lib:${CAPTAINS_LOG_BASELINE_OMP_DIR:-/opt/homebrew/opt/libomp/lib}"
export GGML_BACKEND_PATH="$CAPTAINS_LOG_BASELINE_GGML_DIR/libexec"
export CAPTAINS_LOG_CONFIG_PATH="$REPRO_DIR/config.json"
ruby -rjson -e 'File.write(ARGV[0], JSON.generate(schemaVersion: 1, dataDir: ARGV[1], qwenModelFolder: ARGV[2]))' "$CAPTAINS_LOG_CONFIG_PATH" "$REPRO_DIR/data" "$CAPTAINS_LOG_BASELINE_QWEN_DIR"
swift build --package-path "$REPRO_DIR" --scratch-path "$REPRO_DIR/.build" --product cl
export CAPTAINS_LOG_EVAL_TRACE="$REPRO_DIR/synthetic-prefix.txt"
"$REPRO_DIR/.build/debug/cl" enrich --input "$REPO_DIR/eval/enrich/input/04_entity_list_loop.md" --output "$REPRO_DIR/synthetic-output.md" --prompt "$REPRO_DIR/prompts/enrich.md" --date 2026-10-05 --recording-time 16:44 --seed 42 --diagnostics
```

Run this only while other native inference is idle. The historical failure is a
nonzero native context-exhaustion error, no completed output file, and a sustained
duplicate entity list without a summary in the trace. A prefix cutoff, malformed
YAML, or long but completed response is not equivalent evidence. The normal eval
suite uses the fixed CLI; it does not run this deliberately failing historical
comparison.

Public-name token positions and total request length were used as calibration
metadata from the authorized control. All prose, personal names and scenario
facts were authored independently. No private transcript wording or business
facts belong in these fixtures.

Preserve fixture bytes when rerunning the regression. Its SHA256 in `cases.json`
is checked before inference and during saved-run validation. Punctuation normalization
alone changed the baseline request by three tokens and made generation terminate;
paragraph reformatting also removed the failure. A fixed seed supports repetition
on the recorded model/runtime, not identical output across hardware or upgrades.
The current implementation is checked for completed, bounded, structurally valid
output and semantic changes, rather than an exact generated-text snapshot.

## Fixed-code verification: 2026-10-08

The same seeded source completed in **288 output tokens** with the fixed code
against both the historical llama.cpp 0.5.0/GGML 0.25.3 runtime and the current
0.6.0/0.26.0 runtime. Both used the 4,096-token budget and preserved the source
body. Two fresh current-runtime runs produced identical regression metadata.
This comparison isolates the fix from the runtime upgrade. The historical
failure was observed once in a full unbounded run; no all-seed guarantee is made.

All five enrichment cases passed sequential generation and saved-output checks
in run `2026-10-08_07-54-18_57974_Qwen3.5-9B-Q4_K_M`. Reports under
`eval/enrich/reports/` record field-by-field semantic review. The regression
still adds an incorrect side-project category, omits MMLU/GPQA and the
business-KPI tag, and calls WNR Innovation a project without support. Its summary
also omits the concrete policy correction and remaining human checking effort.
These finite quality errors are recorded against the unchanged correct semantic
reference; structural success does not establish perfect extraction.

The full repository audio-fixture pipeline also passed transcription through
search readback, including resume immutability. `swift build`, 209 deterministic
tests, 25 validator checks and six CLI seed-boundary checks passed. The authorized
original transcript and all private reproduction copies/traces were deleted.

See [TASK-44](../../backlog/tasks/task-44%20-%20Add-a-synthetic-enrichment-loop-regression-evaluation.md)
for implementation status and [ADR-007](../../docs/0007-framework-free-test-coverage.md)
for dated evaluation evidence.

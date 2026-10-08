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

## Fictional festival fixture

`04_moonmoth_festival.md` is a newly authored diary about an imaginary lantern
festival, populated entirely by invented characters, places and creatures. It
contains no presentation material, real organizations/products, or borrowed
outline. No private-source token positions or request lengths were used.
`cases.json` pins its bytes, date/time and seed.

The previous attempted regression was rejected by the owner because it retained
presentation-related names and subject matter. It, its semantic reference and
its generated artifacts were removed. The previous native failure does not prove
that this unrelated replacement triggers the same bug. Historical and fixed
results for this exact source must establish its coverage independently.

## Replacement verification

The historical code completed this 871-word source normally under seeds 42 and 0
(211 and 227 output tokens respectively; 2,885 prompt tokens, 5,888 allocated
context). Both were fresh uncapped runs against llama.cpp 0.5.0/GGML 0.25.3.
**This fixture has not reproduced native context exhaustion.** It is an additional
semantic/structural evaluation case, not evidence that the original native
failure is covered. TASK-44 remains open for an acceptable independent reproducer.

The fixed CLI completed the replacement in 208 tokens (2,938 prompt tokens,
7,168 allocated context, 4,096-token output budget). All five enrichment cases
passed sequential generation and saved-output checks in run
`2026-10-08_10-53-26_63479_Qwen3.5-9B-Q4_K_M`; build, 25 validator checks and
six CLI seed boundaries passed. Field-by-field reports are under
`eval/enrich/reports/`. The replacement's generated metadata incorrectly adds
Whisper, which is absent from the source. It also omits three reference tags and
some summary details. Expected metadata is unchanged; structural success does
not imply semantic accuracy.

## Historical comparison procedure

[`baseline-observability.patch`](baseline-observability.patch) adds seed passthrough,
diagnostics and optional tracing to code before the fix, without altering its
sampler, decoding, unbounded budget or error behavior. It selects matching copied
headers and loads the native backend directory explicitly. Use matching native
headers and runtime libraries, not today's Homebrew libraries.

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
"$REPRO_DIR/.build/debug/cl" enrich --input "$REPO_DIR/eval/enrich/input/04_moonmoth_festival.md" --output "$REPRO_DIR/synthetic-output.md" --prompt "$REPRO_DIR/prompts/enrich.md" --date 2025-02-18 --recording-time 20:30 --seed 42 --diagnostics
```

Run this only while other native inference is idle. The historical failure is a
nonzero native context-exhaustion error, no completed output file, and a sustained
duplicate entity list without a summary in the trace. A prefix cutoff, malformed
YAML, or long but completed response is not equivalent evidence. The normal eval
suite uses the fixed CLI; it does not run this historical comparison.

A completed historical response is a negative reproduction result. Do not count
a malformed response or diagnostic cutoff as native context exhaustion, and do
not call this fixture a native reproducer without observing that error.

See [TASK-44](../../backlog/tasks/task-44%20-%20Add-a-synthetic-enrichment-loop-regression-evaluation.md)
for implementation status and [ADR-007](../../docs/0007-framework-free-test-coverage.md)
for dated evaluation evidence.

# Enrichment evaluations

Run `bash scripts/run-evals.sh --enrich` from the repository root. Every input
runs sequentially with isolated config/data and the date, time and seed in
`cases.json`. It requires Qwen, not Whisper. Check saved output with
`bash scripts/run-evals.sh --validate-enrich <run-stamp>`.

The structural gate rejects unfinished inference, malformed/repeated YAML,
changed source bodies, incorrect supplied date/time, wrong types, duplicate names
and excessive metadata. Expected files remain semantic references: review
additions, omissions and summaries with [`enrich-eval`](../../skills/enrich-eval/SKILL.md).

## Fully fictional name-extraction regression

`04_fictional_name_loop.md` is a newly written **66-word, 965-byte bedtime story**
about a tiny caterpillar in an imaginary village. Its name consists of 144
concatenations of the invented syllable `Vevu`. Nera Pindle and Pofflemere are
invented. The story does not instruct the model to repeat anything. It contains
no presentation names, subject matter or outline; its arbitrary date/time,
syllable counts and length were not calibrated against private content.

Source SHA256: `65e941e63d2ad73a1782556382f4905d1872cf8634c154f2abeae76c517a9a85`.
`cases.json` pins these exact source bytes and seed 42.

The pre-fix native sampler exhausted **4,864 context tokens after a 2,372-token
prompt and 2,492 output tokens** in the sequential discovery runner. It exited 1
and wrote no completed output. The trace contained 808 repetitions of `Vevu`
inside one `persons` item and never reached the summary. A fresh ordinary CLI
invocation independently returned the identical native error and trace. Another
fresh run with seed 0 returned the same counts and error. Both tested seeds fail;
no claim is made for all seeds or platforms. This is repetition
within an extracted name, rather than repetition of complete list rows; it
reaches the same native `contextExhausted` error. Fresh ordinary CLI confirmation
and fixed-code checks are recorded in [testing verification history](../../docs/testing-verification.md).

Recorded baseline:

| Setting | Value |
|---|---|
| Code before fix | `556ef708fd6f9f4ac07408cc9689a5cbc2ac00db` |
| Model | `Qwen_Qwen3.5-9B-Q4_K_M.gguf` |
| Model SHA256 | `d784ce9eda1a5a7b51e8f705a9e6310844bf4f173654d115823c775fdea56d43` |
| Native runtime | llama.cpp 0.5.0 / GGML 0.25.3, Metal, M4 |
| Sampling | seed 42, temperature 0.3, top-k 40, top-p 0.9 |
| Repetition protection | none; original duplicate sampler acceptance retained |
| Output budget | 0 (historical unbounded mode) |
| Supplied date/time | 2025-02-18 / 20:30 |
| Speaker context | none |

Thirteen earlier unrelated narratives completed normally. A known fictional
control matched the ordinary historical CLI exactly at 211 tokens before the
long-name case failed. Discovery reused one loaded model but created a fresh
context and sampler per case. No cutoff, context reduction or injected error was
used for the observed failure. Unexecuted shortening candidates are not evidence
of a global minimum; this compact confirmed candidate was retained.

## Fixed-code behavior

With the matching historical runtime, fixed code completed in **177 tokens**
(2,425 prompt tokens, 6,656 context, 4,096 output budget). Structural validation
and exact source preservation passed. The artificial repeated name is shortened
to four syllable units in persons and three in the summary; the semantic reference
retains all 144 units. This test demonstrates bounded completion, not perfect
extraction of unusually repetitive names. The current 0.6.0/0.26.0 runtime also
completed in 177 tokens, with byte-identical output. All five cases passed sequential generation and saved validation in run
`2026-10-08_18-31-07_71234_Qwen3.5-9B-Q4_K_M`. Build, 25 validator checks and
six CLI seed boundaries passed. Native and semantic evidence is recorded in
ADR-007 and the per-case reports under `eval/enrich/reports/`.

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
"$REPRO_DIR/.build/debug/cl" enrich --input "$REPO_DIR/eval/enrich/input/04_fictional_name_loop.md" --output "$REPRO_DIR/synthetic-output.md" --prompt "$REPRO_DIR/prompts/enrich.md" --date 2025-02-18 --recording-time 20:30 --seed 42 --diagnostics
```

Run this only while other native inference is idle. The historical failure is a
nonzero native context-exhaustion error, no completed output file, and a sustained
duplicate entity list without a summary in the trace. A prefix cutoff, malformed
YAML, or long but completed response is not equivalent evidence. The normal eval
suite uses the fixed CLI; it does not run this historical comparison.

A completed historical response is negative reproduction evidence. A diagnostic
cutoff, malformed but completed response or seeded discovery prefix alone does
not establish native context exhaustion. A fixed seed supports repeatability on
the recorded model/runtime, not identical behavior on every platform or upgrade.

The previously rejected presentation-related fixture and its generated artifacts
were removed. Its proof does not transfer to this independently written source.
See [TASK-44](../../backlog/tasks/task-44%20-%20Add-a-synthetic-enrichment-loop-regression-evaluation.md)
for implementation status.

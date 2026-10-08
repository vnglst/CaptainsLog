#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
CL="${CAPTAINS_LOG_EVAL_CL:-$ROOT_DIR/.build/debug/cl}"
if [[ ! -x "$CL" ]]; then
    printf 'Build cl before running this model-free check.\n' >&2
    exit 2
fi
mkdir -p tmp
RUN_DIR="$(mktemp -d "$ROOT_DIR/tmp/enrich-eval-checks-XXXXXX")"
export CAPTAINS_LOG_CONFIG_PATH="$RUN_DIR/config.json"
ruby -rjson -e 'File.write(ARGV[0], JSON.generate({schemaVersion: 1, dataDir: ARGV[1]}))' "$CAPTAINS_LOG_CONFIG_PATH" "$RUN_DIR/data"
ruby skills/enrich-eval/scripts/test-validate.rb
ruby skills/enrich-eval/scripts/validate.rb --cases eval/enrich/cases.json eval/enrich/input
for seed in 0 42 4294967294; do
    "$CL" enrich --input eval/enrich/input/01_work_week.md --seed "$seed" --print-prompt > "$RUN_DIR/seed-$seed.txt"
    rg -Fq 'FinanceHub' "$RUN_DIR/seed-$seed.txt"
done
for seed in -1 4294967295 4294967296; do
    if "$CL" enrich --input eval/enrich/input/01_work_week.md --seed "$seed" --print-prompt > "$RUN_DIR/invalid-$seed.txt" 2>&1; then
        printf 'Invalid seed was accepted: %s\n' "$seed" >&2
        exit 1
    fi
    rg -q 'Error:.*(seed|Seed)' "$RUN_DIR/invalid-$seed.txt"
done
printf 'PASS: seed boundaries and reserved random-seed rejection; no model loaded.\n'

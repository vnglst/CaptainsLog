#!/usr/bin/env bash
set -uo pipefail

# Validate a previously generated, timestamped run without invoking any models.
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
categorize_only=false
if [[ "${1:-}" == "--categorize-only" ]]; then
    categorize_only=true
    shift
fi
STAMP="${1:-}"
if [[ -z "$STAMP" ]]; then
    printf 'Usage: %s [--categorize-only] <run-stamp>\n' "$0" >&2
    exit 2
fi

WHISPER_MODEL="${CAPTAINS_LOG_EVAL_WHISPER_MODEL:-openai_whisper-large-v2}"
QWEN_LABEL="${CAPTAINS_LOG_EVAL_QWEN_LABEL:-Qwen3.5-9B-Q4_K_M}"
REPORT_DIR="tmp/eval-validation-$STAMP"
mkdir -p "$REPORT_DIR"
failures=0
outputs=0

fail() {
    printf 'FAIL: %s\n' "$1" | tee -a "$REPORT_DIR/validation.txt"
    ((failures += 1))
}

check_nonempty() {
    local path="$1"
    if [[ -s "$path" ]]; then
        printf 'PASS: nonempty %s\n' "$path" | tee -a "$REPORT_DIR/validation.txt"
        ((outputs += 1))
        return 0
    fi
    fail "missing or empty output: $path"
    return 1
}

: > "$REPORT_DIR/validation.txt"

if [[ "$categorize_only" != true ]]; then
for expected in eval/transcribe/expected/*.md; do
    name="$(basename "$expected" .md)"
    generated="eval/transcribe/generated/${STAMP}_${WHISPER_MODEL}_${name}.md"
    if check_nonempty "$generated"; then
        swift skills/transcription-eval/scripts/compare.swift --expected "$expected" --generated "$generated" > "$REPORT_DIR/transcribe-$name.txt"
    fi
done
fi

for expected in eval/categorize/expected/*.category; do
    name="$(basename "$expected" .category)"
    generated="eval/categorize/generated/${STAMP}_${QWEN_LABEL}_${name}.json"
    check_nonempty "$generated" || continue
    expected_category="$(tr -d '\r\n' < "$expected")"
    if ruby -rjson -e 'data = JSON.parse(File.read(ARGV.fetch(0))); abort("manifest is not an object") unless data.is_a?(Hash); abort("sourceStem mismatch: #{data["sourceStem"].inspect}") unless data["sourceStem"] == ARGV.fetch(1); abort("category mismatch: expected #{ARGV.fetch(2)}, got #{data["category"].inspect}") unless data["category"] == ARGV.fetch(2)' "$generated" "$name" "$expected_category"; then
        printf 'PASS: category manifest %s => %s\n' "$name" "$expected_category" | tee -a "$REPORT_DIR/validation.txt"
    else
        fail "invalid category manifest: $generated"
    fi
done

if [[ "$categorize_only" != true ]]; then
for expected in eval/cleanup/expected/*.md; do
    name="$(basename "$expected" .md)"
    generated="eval/cleanup/generated/${STAMP}_${QWEN_LABEL}_${name}.md"
    check_nonempty "$generated" || continue
done
fi

if [[ "$categorize_only" != true ]]; then
for expected in eval/filename/expected/*.md; do
    name="$(basename "$expected" .md)"
    generated="eval/filename/generated/${STAMP}_${QWEN_LABEL}_${name}.md"
    check_nonempty "$generated" || continue
    generated_name="$(tr -d '\n' < "$generated")"
    if [[ ! "$generated_name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[[:alnum:]]+(-[[:alnum:]]+){2,7}\.md$ ]]; then
        fail "invalid filename format: $generated_name"
    fi
    swift skills/filename-eval/scripts/compare.swift --expected "$expected" --generated "$generated" > "$REPORT_DIR/filename-$name.txt"
done

for expected in eval/enrich/expected/*.md; do
    name="$(basename "$expected" .md)"
    generated="eval/enrich/generated/${STAMP}_${QWEN_LABEL}_${name}.md"
    check_nonempty "$generated" || continue
    if ! ruby -ryaml -e 'text = File.read(ARGV.fetch(0)); parts = text.split("---", 3); abort("missing YAML frontmatter") unless parts.length >= 3; data = YAML.safe_load(parts[1]); abort("frontmatter is not a mapping") unless data.is_a?(Hash); %w[date recording_time language categories tags persons projects companies entities summary].each { |key| abort("missing #{key}") unless data.key?(key) }; %w[categories tags persons projects companies entities].each { |key| abort("#{key} is not a list") unless data[key].is_a?(Array) }; abort("summary is not text") unless data["summary"].is_a?(String)' "$generated"; then
        fail "invalid enrichment frontmatter: $generated"
        continue
    fi
    swift skills/enrich-eval/scripts/compare.swift --expected "$expected" --generated "$generated" > "$REPORT_DIR/enrich-$name.txt"
done
fi

printf 'Checked %d nonempty outputs; failures: %d. Diagnostics: %s\n' "$outputs" "$failures" "$REPORT_DIR/validation.txt"
if (( failures > 0 )); then exit 1; fi
expected_outputs=0
if [[ "$categorize_only" == true ]]; then
    expected_outputs=$(find eval/categorize/expected -maxdepth 1 -type f -name '*.category' | wc -l | tr -d ' ')
else
    expected_outputs=19
    expected_outputs=$((expected_outputs + $(find eval/categorize/expected -maxdepth 1 -type f -name '*.category' | wc -l | tr -d ' ')))
fi
if (( outputs != expected_outputs )); then
    printf 'Expected %d outputs, checked %d.\n' "$expected_outputs" "$outputs" >&2
    exit 1
fi

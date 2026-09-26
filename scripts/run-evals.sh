#!/usr/bin/env bash
set -euo pipefail

# Run real local-model evaluations in a strict sequence. Outputs and the isolated
# config live under tmp/; stage outputs and reports are retained under eval/*.
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

MODE="${1:---all}"
if [[ "$MODE" == "--validate-run" ]]; then
    if [[ "$#" != 2 ]]; then
        printf 'Usage: %s --validate-run <run-stamp>\n' "$0" >&2
        exit 2
    fi
    exec "$ROOT_DIR/scripts/validate-eval-run.sh" "$2"
fi
if [[ "$MODE" == "--validate-categorize" ]]; then
    if [[ "$#" != 2 ]]; then
        printf 'Usage: %s --validate-categorize <run-stamp>\n' "$0" >&2
        exit 2
    fi
    exec "$ROOT_DIR/scripts/validate-eval-run.sh" --categorize-only "$2"
fi
if [[ "$MODE" != "--pipeline" && "$MODE" != "--suites" && "$MODE" != "--categorize" && "$MODE" != "--all" ]]; then
    printf 'Usage: %s [--pipeline|--suites|--categorize|--all|--validate-run <run-stamp>|--validate-categorize <run-stamp>]\n' "$0" >&2
    exit 2
fi

STAMP="$(date +%Y-%m-%d_%H-%M-%S)_$$"
RUN_DIR="${CAPTAINS_LOG_EVAL_RUN_DIR:-$ROOT_DIR/tmp/evals-$STAMP-$$}"
WHISPER_MODEL="${CAPTAINS_LOG_EVAL_WHISPER_MODEL:-openai_whisper-large-v2}"
WHISPER_FOLDER="${CAPTAINS_LOG_EVAL_WHISPER_FOLDER:-$HOME/Library/Caches/CaptainsLog/models/whisper/models/argmaxinc/whisperkit-coreml/$WHISPER_MODEL}"
QWEN_FOLDER="${CAPTAINS_LOG_EVAL_QWEN_FOLDER:-$HOME/Library/Application Support/CaptainsLog/models}"
QWEN_FILE="${CAPTAINS_LOG_EVAL_QWEN_FILE:-Qwen_Qwen3.5-9B-Q4_K_M.gguf}"
QWEN_LABEL="${CAPTAINS_LOG_EVAL_QWEN_LABEL:-Qwen3.5-9B-Q4_K_M}"

if [[ ! -d "$WHISPER_FOLDER" ]]; then
    printf 'Whisper model folder not found: %s\n' "$WHISPER_FOLDER" >&2
    exit 1
fi
if [[ ! -f "$QWEN_FOLDER/$QWEN_FILE" ]]; then
    printf 'Qwen model file not found: %s\n' "$QWEN_FOLDER/$QWEN_FILE" >&2
    exit 1
fi

mkdir -p "$RUN_DIR"
RUN_DIR="$(cd "$RUN_DIR" && pwd)"
export CAPTAINS_LOG_CONFIG_PATH="$RUN_DIR/config.json"
export CAPTAINS_LOG_DATA_DIR="$RUN_DIR/data"

json_string() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '"%s"' "$value"
}
{
    printf '{\n  "schemaVersion": 1,\n  "dataDir": %s,\n  "whisperModel": %s,\n  "whisperModelFolder": %s,\n  "qwenModelFolder": %s\n}\n' \
        "$(json_string "$CAPTAINS_LOG_DATA_DIR")" \
        "$(json_string "$WHISPER_MODEL")" \
        "$(json_string "$WHISPER_FOLDER")" \
        "$(json_string "$QWEN_FOLDER")"
} > "$CAPTAINS_LOG_CONFIG_PATH"

printf 'Run directory: %s\n' "$RUN_DIR"
printf 'Config: %s\n' "$CAPTAINS_LOG_CONFIG_PATH"
swift build --product cl
BIN_DIR="$(swift build --show-bin-path)"
CL="$BIN_DIR/cl"

if [[ "$MODE" == "--pipeline" || "$MODE" == "--all" ]]; then
    PIPE_DATA="$RUN_DIR/data"
    "$CL" pipeline --input "eval/transcribe/audio/2025-01-14 side project.m4a" --data-dir "$PIPE_DATA" 2>&1 | tee "$RUN_DIR/pipeline.log"

    TRANSCRIPT="$PIPE_DATA/.pipeline/01-transcribed/2025-01-14 side project.md"
    CLEANED="$PIPE_DATA/.pipeline/02-logs/2025-01-14 side project.md"
    CATEGORY="$PIPE_DATA/.pipeline/03-category/2025-01-14 side project.json"
    if [[ ! -s "$TRANSCRIPT" || ! -s "$CLEANED" || ! -s "$CATEGORY" ]]; then
        printf 'Pipeline artifact assertion failed. See %s/pipeline.log\n' "$RUN_DIR" >&2
        exit 1
    fi
    CATEGORY_VALUE="$(plutil -extract category raw -o - "$CATEGORY")"
    case "$CATEGORY_VALUE" in
        side_project) ;;
        *) printf 'Unexpected category value: %s\n' "$CATEGORY_VALUE" >&2; exit 1 ;;
    esac
    SLUG_FILE="$PIPE_DATA/.pipeline/04-rename/2025-01-14 side project.slug.txt"
    [[ -s "$SLUG_FILE" ]]
    SLUG="$(cat "$SLUG_FILE")"
    RENAMED="$PIPE_DATA/.pipeline/04-rename/$SLUG"
    ENRICHED="$(find "$PIPE_DATA/logs" -type f -name "$SLUG" -print -quit)"
    [[ -s "$RENAMED" && -n "$ENRICHED" && -s "$ENRICHED" ]]

    find "$PIPE_DATA" -type f -exec shasum -a 256 {} \; | sort > "$RUN_DIR/before-resume.sha256"
    "$CL" resume --data-dir "$PIPE_DATA" | tee "$RUN_DIR/resume.log"
    find "$PIPE_DATA" -type f -exec shasum -a 256 {} \; | sort > "$RUN_DIR/after-resume.sha256"
    diff -u "$RUN_DIR/before-resume.sha256" "$RUN_DIR/after-resume.sha256"

    "$CL" search-index --data-dir "$PIPE_DATA" 2>&1 | tee "$RUN_DIR/search-index.log"
    "$CL" search 'Star Trek captain log side project' --data-dir "$PIPE_DATA" --limit 5 2>&1 | tee "$RUN_DIR/search.log"
    if ! rg -Fq "$ENRICHED" "$RUN_DIR/search.log"; then
        printf 'Search readback did not return the pipeline entry: %s\n' "$ENRICHED" >&2
        exit 1
    fi
    printf 'Pipeline artifact, category, resume immutability, and search readback assertions passed.\n'
fi

if [[ "$MODE" == "--suites" || "$MODE" == "--categorize" || "$MODE" == "--all" ]]; then
    if [[ "$MODE" != "--categorize" ]]; then
    for input in eval/transcribe/audio/*.m4a; do
        case_name="$(basename "$input" .m4a)"
        output="eval/transcribe/generated/${STAMP}_${WHISPER_MODEL}_${case_name}.md"
        mkdir -p eval/transcribe/generated
        "$CL" transcribe "$input" --output "$output"
        [[ -s "$output" ]]
    done

    for input in eval/cleanup/input/*.md; do
        case_name="$(basename "$input" .md)"
        output="eval/cleanup/generated/${STAMP}_${QWEN_LABEL}_${case_name}.md"
        mkdir -p eval/cleanup/generated
        "$CL" cleanup --input "$input" --output "$output"
        [[ -s "$output" ]]
    done

    for input in eval/filename/input/*.md; do
        case_name="$(basename "$input" .md)"
        output="eval/filename/generated/${STAMP}_${QWEN_LABEL}_${case_name}.md"
        mkdir -p eval/filename/generated
        "$CL" filename --input "$input" --date 2025-01-15 > "$output"
        generated_name="$(tr -d '\n' < "$output")"
        if [[ ! "$generated_name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[[:alnum:]]+(-[[:alnum:]]+){2,7}\.md$ ]]; then
            printf 'Filename format assertion failed for %s: %s\n' "$case_name" "$generated_name" >&2
            exit 1
        fi
    done

    for input in eval/enrich/input/*.md; do
        case_name="$(basename "$input" .md)"
        output="eval/enrich/generated/${STAMP}_${QWEN_LABEL}_${case_name}.md"
        mkdir -p eval/enrich/generated
        "$CL" enrich --input "$input" --output "$output" --date 2025-01-15 --recording-time 12:00
        [[ -s "$output" ]]
        ruby -ryaml -e 'text = File.read(ARGV.fetch(0)); parts = text.split("---", 3); abort("missing YAML frontmatter") unless parts.length >= 3; YAML.safe_load(parts[1])' "$output"
    done
    fi

    for input in eval/categorize/input/*.md; do
        case_name="$(basename "$input" .md)"
        output="eval/categorize/generated/${STAMP}_${QWEN_LABEL}_${case_name}.json"
        mkdir -p eval/categorize/generated
        "$CL" categorize --input "$input" --output "$output"
        [[ -s "$output" ]]
    done
    printf 'All evaluation cases generated sequentially. Compare and review each output against eval/*/expected and the matching skill.\n'
    if [[ "$MODE" == "--categorize" ]]; then
        "$ROOT_DIR/scripts/validate-eval-run.sh" --categorize-only "$STAMP"
    else
        "$ROOT_DIR/scripts/validate-eval-run.sh" "$STAMP"
    fi
fi

printf 'Run complete: %s\n' "$RUN_DIR"

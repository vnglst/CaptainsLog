#!/usr/bin/env bash
# Internal pipeline assertions; invoke through run-evals.sh.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
RUN_DIR="$1"
CL="$2"
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
[[ -s "$SLUG_FILE" ]] || { printf 'Missing slug marker: %s\n' "$SLUG_FILE" >&2; exit 1; }
SLUG="$(cat "$SLUG_FILE")"
RENAMED="$PIPE_DATA/.pipeline/04-rename/$SLUG.md"
ENRICHED="$PIPE_DATA/logs/side-project/$SLUG.md"
[[ -s "$RENAMED" && -n "$ENRICHED" && -s "$ENRICHED" ]] || { printf 'Missing renamed/enriched artifacts for %s\n' "$SLUG" >&2; exit 1; }

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

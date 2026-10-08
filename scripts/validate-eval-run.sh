#!/usr/bin/env bash
# Compatibility wrapper; run-evals.sh is the documented entry point.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "${1:-}" == "--categorize-only" ]]; then
    shift
    exec "$ROOT_DIR/scripts/run-evals.sh" --validate-categorize "$@"
fi
exec "$ROOT_DIR/scripts/run-evals.sh" --validate-run "$@"

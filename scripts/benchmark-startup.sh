#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

RUNS="${1:-5}"
ENTRY_COUNT="${CAPTAINSLOG_BENCHMARK_ENTRIES:-750}"
BIN=".build/out/Products/Debug/CaptainsLogApp"

if ! [[ "$RUNS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Usage: $0 [positive-run-count]" >&2
    exit 2
fi

swift build --product CaptainsLogApp >/dev/null

BENCH_DIR=$(mktemp -d "${TMPDIR:-/tmp}/captainslog-startup.XXXXXX")
APP_PID=""
cleanup() {
    if [ -n "$APP_PID" ]; then
        kill "$APP_PID" 2>/dev/null || true
    fi
    rm -rf "$BENCH_DIR"
}
trap cleanup EXIT

SOURCE_CONFIG="$HOME/Library/Application Support/CaptainsLog/config.json"

for run in $(seq 1 "$RUNS"); do
    MARKER="$BENCH_DIR/ready-$run"
    CONFIG="$BENCH_DIR/config-$run.json"
    DATA_DIR="$BENCH_DIR/data-$run"
    mkdir -p "$DATA_DIR/audio"
    for entry in $(seq 1 "$ENTRY_COUNT"); do
        touch "$DATA_DIR/audio/benchmark-$(printf '%06d' "$entry").m4a"
    done
    if [ -f "$SOURCE_CONFIG" ]; then
        jq --arg data "$DATA_DIR" \
            '{schemaVersion: 1, dataDir: $data, whisperModelFolder, whisperModel, qwenModelId, qwenModelFolder}' \
            "$SOURCE_CONFIG" > "$CONFIG"
    else
        printf '{"schemaVersion":1,"dataDir":"%s"}\n' "$DATA_DIR" > "$CONFIG"
    fi
    START=$(python3 -c 'import time; print(time.monotonic_ns())')
    CAPTAINS_LOG_CONFIG_PATH="$CONFIG" \
    CAPTAINSLOG_STARTUP_BENCHMARK_MARKER="$MARKER" \
        "$BIN" >"$BENCH_DIR/app-$run.log" 2>&1 &
    PID=$!
    APP_PID="$PID"

    for _ in $(seq 1 400); do
        if [ -f "$MARKER" ]; then
            break
        fi
        if ! kill -0 "$PID" 2>/dev/null; then
            wait "$PID" || true
            echo "Run $run: app exited before recording became ready" >&2
            cat "$BENCH_DIR/app-$run.log" >&2
            exit 1
        fi
        sleep 0.025
    done

    if [ ! -f "$MARKER" ]; then
        kill "$PID" 2>/dev/null || true
        wait "$PID" 2>/dev/null || true
        echo "Run $run: timed out waiting for recorded audio" >&2
        cat "$BENCH_DIR/app-$run.log" >&2
        exit 1
    fi

    END=$(python3 -c 'import time; print(time.monotonic_ns())')
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
    APP_PID=""
    python3 -c "print('Run $run: %.1f ms' % (($END - $START) / 1_000_000))"
done

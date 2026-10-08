#!/usr/bin/env bash
# Checks must not read or seed the developer's normal CaptainsLog storage.
set -euo pipefail
check_root="$(mktemp -d "${TMPDIR:-/tmp}/captainslog-check.XXXXXX")"
trap 'rm -rf "$check_root"' EXIT
export CAPTAINS_LOG_CONFIG_PATH="$check_root/config.json"
export CAPTAINS_LOG_DATA_DIR="$check_root/data"
mkdir -p "$CAPTAINS_LOG_DATA_DIR"
ruby -rjson -e 'File.write(ARGV[0], JSON.generate({schemaVersion: 1, dataDir: ARGV[1]}))' \
    "$CAPTAINS_LOG_CONFIG_PATH" "$CAPTAINS_LOG_DATA_DIR"
"$@"

#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    printf 'Recorder hardware smoke requires macOS and Core Audio.\n' >&2
    exit 2
fi
if [[ ! -t 0 ]]; then
    printf 'Run this smoke test interactively; it records three seconds after confirmation.\n' >&2
    exit 2
fi
command -v afinfo >/dev/null || {
    printf 'The macOS afinfo utility is required to validate the output file.\n' >&2
    exit 2
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
smoke_root="$(mktemp -d "${TMPDIR:-/tmp}/captainslog-recorder-smoke.XXXXXX")"
trap 'rm -rf "$smoke_root"' EXIT
output_path="$smoke_root/recording.m4a"

printf 'This will record three seconds from the default microphone to a temporary file.\n'
printf 'The temporary file and isolated config will be removed when the script exits.\n'
printf 'Continue? [y/N] '
IFS= read -r answer
case "$answer" in
    y|Y|yes|YES) ;;
    *) printf 'Recorder smoke cancelled.\n'; exit 0 ;;
esac

cd "$repo_root"
CAPTAINS_LOG_CONFIG_PATH="$smoke_root/config.json" \
CAPTAINS_LOG_DATA_DIR="$smoke_root/data" \
    swift run cl record --duration 3 --output "$output_path"

test -s "$output_path" || {
    printf 'Recorder returned without creating a non-empty audio file.\n' >&2
    exit 1
}
afinfo "$output_path" >/dev/null
printf 'Recorder hardware smoke passed: audio was captured and the M4A file is readable.\n'

#!/bin/bash
# Synthetic Homebrew transport. Never downloads or changes an installed app.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ -n "${CAPTAINS_LOG_UPDATE_FIXTURE_LOG:-}" ]]; then
    printf '%s\n' "$*" >> "$CAPTAINS_LOG_UPDATE_FIXTURE_LOG"
fi
if [[ "${CAPTAINS_LOG_UPDATE_FIXTURE_FAIL:-}" == "$1" ]]; then
    printf 'Synthetic network failure\n' >&2
    exit 1
fi
case "$1" in
    info)
        if [[ -n "${CAPTAINS_LOG_UPDATE_FIXTURE_STATE:-}" && -f "$CAPTAINS_LOG_UPDATE_FIXTURE_STATE" ]]; then
            cat "$ROOT/current.json"
        else
            cat "$ROOT/available.json"
        fi
        ;;
    update) ;;
    upgrade)
        [[ "$*" == 'upgrade --cask --no-quit --require-sha vnglst/captainslog/captainslog' ]]
        touch "${CAPTAINS_LOG_UPDATE_FIXTURE_STATE:?Fixture state path required}"
        ;;
    *) exit 2 ;;
esac

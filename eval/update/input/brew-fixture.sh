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
    update)
        # Exercise the Git override that survives Homebrew's environment filter.
        # Resolve an actual repository remote without making a network request.
        transport_dir="$(mktemp -d)"
        trap 'rm -rf "$transport_dir"' EXIT
        /usr/bin/git init -q "$transport_dir"
        /usr/bin/git -C "$transport_dir" config 'url.git@github.com:.insteadOf' 'https://github.com/'
        https='https://github.com/vnglst/homebrew-captainslog.git'
        for remote in 'git@github.com:vnglst/homebrew-captainslog.git' \
                      'ssh://git@github.com/vnglst/homebrew-captainslog.git' "$https"; do
            /usr/bin/git -C "$transport_dir" config remote.origin.url "$remote"
            [[ "$(env -i HOME="$transport_dir" "${HOMEBREW_GIT_PATH:?Missing public tap Git override}" -C "$transport_dir" remote get-url origin)" == "$https" ]]
            [[ "$(/usr/bin/git -C "$transport_dir" config --get remote.origin.url)" == "$remote" ]]
        done
        # Other taps retain their original transport.
        /usr/bin/git -C "$transport_dir" config remote.origin.url 'git@github.com:other/private-tap.git'
        [[ "$("$HOMEBREW_GIT_PATH" -C "$transport_dir" remote get-url origin)" == 'git@github.com:other/private-tap.git' ]]
        ;;
    upgrade)
        [[ "$*" == 'upgrade --cask --no-quit --require-sha vnglst/captainslog/captainslog' ]]
        touch "${CAPTAINS_LOG_UPDATE_FIXTURE_STATE:?Fixture state path required}"
        ;;
    *) exit 2 ;;
esac

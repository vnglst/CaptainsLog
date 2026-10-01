#!/usr/bin/env bash
# Verify update commands against repository fixtures without upgrading any app.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tmp
run_dir="$(mktemp -d "$PWD/tmp/update-verification.XXXXXX")"
export CAPTAINS_LOG_CONFIG_PATH="$run_dir/config.json"
export CAPTAINS_LOG_UPDATE_FIXTURE_STATE="$run_dir/installed"
export CAPTAINS_LOG_UPDATE_FIXTURE_LOG="$run_dir/commands"
fixture="$PWD/eval/update/input/brew-fixture.sh"

python3 - "$run_dir" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
(root / 'data').mkdir()
(root / 'config.json').write_text(json.dumps({'schemaVersion': 1, 'dataDir': str(root / 'data')}))
PY
swift build --product cl
bin_dir="$(swift build --show-bin-path)"
cl="$bin_dir/cl"
"$cl" update --check --brew-path "$fixture" | tee "$run_dir/check.log"
[[ ! -e "$CAPTAINS_LOG_UPDATE_FIXTURE_STATE" ]]
rg -q 'Update available' "$run_dir/check.log"
"$cl" update --brew-path "$fixture" | tee "$run_dir/install.log"
[[ -f "$CAPTAINS_LOG_UPDATE_FIXTURE_STATE" ]]
"$cl" update --check --brew-path "$fixture" | tee "$run_dir/current.log"
rg -q 'up to date' "$run_dir/current.log"
[[ "$(rg -c '^upgrade ' "$CAPTAINS_LOG_UPDATE_FIXTURE_LOG")" == 1 ]]
rg -q '^upgrade --cask --no-quit --require-sha vnglst/captainslog/captainslog$' "$CAPTAINS_LOG_UPDATE_FIXTURE_LOG"
if CAPTAINS_LOG_UPDATE_FIXTURE_FAIL=update "$cl" update --check --brew-path "$fixture" > "$run_dir/failure.log" 2>&1; then
    printf 'Expected the synthetic network failure to exit nonzero.\n' >&2
    exit 1
fi
rg -q 'Synthetic network failure' "$run_dir/failure.log"
"$cl" config set automaticUpdates false
"$cl" config set automaticUpdateChecks false
python3 - "$CAPTAINS_LOG_CONFIG_PATH" <<'PY'
import json, sys
config = json.load(open(sys.argv[1]))
assert config['automaticUpdates'] is False and config['automaticUpdateChecks'] is False
PY
if "$cl" config set automaticUpdates invalid > "$run_dir/invalid-preference.log" 2>&1; then
    printf 'Expected an invalid Boolean preference to exit nonzero.\n' >&2
    exit 1
fi
"$cl" config set automaticUpdates unset
"$cl" config set automaticUpdateChecks unset
"$cl" config show > "$run_dir/config.log"
rg -q 'automaticUpdates: true' "$run_dir/config.log"
rg -q 'automaticUpdateChecks: true' "$run_dir/config.log"
printf 'Update CLI fixture checks passed. Logs: %s\n' "$run_dir"

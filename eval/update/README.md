# Update fixtures

These fixtures simulate Homebrew metadata and commands. They never replace an
installed app. `make tests` covers checks, installation, invalid metadata,
missing Homebrew, and command failures. The app-controller integration tests also
exercise the actual scheduled monitor iteration, preference persistence, model
setup/recording/processing gates (including queued work), restart success/failure,
and retry timing. Relaunch and termination are injected to keep tests isolated.

The fake `brew update` also invokes the updater's temporary Git executable under
a filtered environment. It verifies HTTPS routing for the public tap's SSH and
HTTPS URLs despite a broad HTTPS-to-SSH rewrite, without fetching repositories,
changing stored remotes, or changing transport for unrelated taps.

Run the reproducible CLI verification suite with `make tests-updates`.
It creates its own isolated config/data and preserves logs under `tmp/`.
Run controller tests with `make tests-unit`. Quit CaptainsLog after recording
and processing finish: the updater fixtures still inspect the real app process.

Or run the affected CLI manually:

```sh
UPDATE_SMOKE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/captainslog-update-XXXXXX")"
export CAPTAINS_LOG_CONFIG_PATH="$UPDATE_SMOKE_DIR/config.json"
export CAPTAINS_LOG_DATA_DIR="$UPDATE_SMOKE_DIR/data"
printf '{"schemaVersion":1,"dataDir":"%s"}\n' "$CAPTAINS_LOG_DATA_DIR" > "$CAPTAINS_LOG_CONFIG_PATH"
export CAPTAINS_LOG_UPDATE_FIXTURE_STATE="$UPDATE_SMOKE_DIR/installed"
export CAPTAINS_LOG_UPDATE_FIXTURE_LOG="$UPDATE_SMOKE_DIR/commands"
make cli ARGS="update --check --brew-path '$PWD/eval/update/input/brew-fixture.sh'"
make cli ARGS="update --brew-path '$PWD/eval/update/input/brew-fixture.sh'"
make cli ARGS="update --check --brew-path '$PWD/eval/update/input/brew-fixture.sh'"
```

Expect an available update, a successful simulated installation, then an
up-to-date result. The command log must contain exactly one upgrade with
`--no-quit --require-sha` and the fully qualified CaptainsLog cask. For a network
failure, set `CAPTAINS_LOG_UPDATE_FIXTURE_FAIL=update`; the CLI must exit nonzero
and include “Synthetic network failure.” Keep the temporary directory if you want
to inspect its logs. After the check, remove the environment overrides:

```sh
unset CAPTAINS_LOG_CONFIG_PATH CAPTAINS_LOG_DATA_DIR
unset CAPTAINS_LOG_UPDATE_FIXTURE_STATE CAPTAINS_LOG_UPDATE_FIXTURE_LOG CAPTAINS_LOG_UPDATE_FIXTURE_FAIL
unset UPDATE_SMOKE_DIR
```

A real upgrade from one published version to the next remains a release check.

# Update fixtures

These fixtures simulate Homebrew metadata and commands. They never replace an
installed app. `swift run run-tests` covers checks, installation, invalid metadata,
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
Run controller tests with `swift run run-tests --unit`.

Or run the affected CLI manually:

```sh
mkdir -p tmp/update-smoke
export CAPTAINS_LOG_UPDATE_FIXTURE_STATE="$PWD/tmp/update-smoke/installed"
export CAPTAINS_LOG_UPDATE_FIXTURE_LOG="$PWD/tmp/update-smoke/commands"
rm -f "$CAPTAINS_LOG_UPDATE_FIXTURE_STATE" "$CAPTAINS_LOG_UPDATE_FIXTURE_LOG"
swift run cl update --check --brew-path "$PWD/eval/update/input/brew-fixture.sh"
swift run cl update --brew-path "$PWD/eval/update/input/brew-fixture.sh"
swift run cl update --check --brew-path "$PWD/eval/update/input/brew-fixture.sh"
```

Expect an available update, a successful simulated installation, then an
up-to-date result. The command log must contain exactly one upgrade with
`--no-quit --require-sha` and the fully qualified CaptainsLog cask. For a network
failure, set `CAPTAINS_LOG_UPDATE_FIXTURE_FAIL=update`; the CLI must exit nonzero
and include “Synthetic network failure.” Remove the fixture variables afterward.

A real upgrade from one published version to the next remains a release check.

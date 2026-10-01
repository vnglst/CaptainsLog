# ADR-011: Update the installed app through Homebrew

**Status**: Accepted

## Decision

Use the existing `vnglst/captainslog/captainslog` cask for app updates. No new
release feed, signing keys, inference service, or runtime dependency is required.
The tagged release workflow continues to publish the archive and cask checksum.

The installed app checks on launch and every 24 hours while open. Automatic
installation is enabled by default and waits until recording, processing, and
model setup are finished. It prevents new recording and processing work during
installation, verifies the cask checksum through Homebrew, then starts the updated
app and terminates the old instance. Failures remain visible in Settings; failed
installations retry no more than once an hour.

Preferences are stored as `automaticUpdateChecks` and `automaticUpdates` in
`CaptainsLogConfig`. Absent values mean enabled for older config files. Turning
off automatic checks also prevents automatic installation. Settings provides
manual checks, installation, and restart controls. A fixed status area and an
overlaid sidebar indicator preserve surrounding layout.

The CLI exposes `cl update --check` and `cl update`. CLI installation requires the
GUI to be closed. Source runs, demos, and UI fixtures do not auto-update; the GUI
also verifies that the running bundle matches the cask's installed app path.

## Consequences

Updates require the supported Apple Silicon Homebrew installation. Homebrew
refreshes its metadata over the network; no recordings or note content are sent.
Existing ad-hoc signing and cask quarantine handling remain the release model.
A direct ZIP or source installation must be updated manually or installed through
Homebrew. A real old-to-new published upgrade and relaunch remains a release QA
check; synthetic fixtures validate the command flow without replacing the app.

## Verification record: 2026-10-01

The feature checks the supported Homebrew cask daily, waits for recording,
processing, and model setup to finish, installs with checksum verification, and
restarts the app. Both update preferences persist in the config file. Source
runs and fixture apps do not auto-update. No installed app was upgraded during
these checks.

### Completed checks

- `swift build`: passes without warnings after the final source changes.
- Lightweight suite (`run-tests --unit`): 138 passed, zero failed.
- Six updater tests cover installed/current metadata, malformed/uninstalled or
  unrelated casks, idle and preference rules, the hourly retry delay, older config
  compatibility, the simulated upgrade command, network failures, and missing
  Homebrew.
- CLI fixture check/install/check: reports 0.1.0 → 0.1.1, performs exactly one
  simulated upgrade using `--no-quit --require-sha` and the fully qualified cask,
  then reports up to date. Check-only never installs.
- CLI network failure exits nonzero and reports the synthetic failure.
- CLI preferences persist both `false` values; invalid Boolean values fail.
- `git diff --check`: passes.

Reproduction instructions and the synthetic Homebrew executable are in
[`eval/update`](../eval/update/README.md). Detailed local command output is in
`tmp/update-smoke/`; build and full-suite logs are under `/tmp/captainslog-update-*`.

### Remaining verification limits

`swift run run-tests` completed with 183 passes and seven failures. The existing,
unchanged transcription disk-space guard sees
`volumeAvailableCapacityForImportantUsage == 0` in this environment, although
`volumeAvailableCapacity` reports approximately 19 GB. Three transcription tests
and four pipeline/resume tests fail before their intended fake operations. The
model-backed `scripts/run-evals.sh --pipeline` command stops at the same guard,
before transcription or LLM processing. Its isolated fixture run is
`tmp/evals-2026-10-01_20-24-54_37835-37835/`.

The sequential filename smoke check attempted the first fixture,
`01_single_topic.md`, using Qwen 3.5 9B Q4_K_M. The process aborted with exit status
134 and produced no filename or diagnostic output. The empty output file was
removed. The remaining cases were not run after that runtime failure; no semantic
quality judgment is possible for this attempt. No filename semantic review was possible for that attempt.

The isolated native UI fixture was assembled through `scripts/test-ui.sh eval`
with the existing build. LaunchServices rejected its launch with
`kLSNoExecutableErr` (-10827), despite the executable being present as an arm64
Mach-O. Settings layout was therefore not visually verified here.

A real published old-to-new Homebrew upgrade, automatic restart, and visible
Settings layout still need release QA. Synthetic fixtures validate update command
flow and scheduling without replacing the user's installed app. Human review
remains the final judgment for model output when inference can run.

## Verification after the Settings redesign: 2026-10-01

The redesigned switch and checkbox retain the existing `setAutomaticChecks` and
`setAutomaticUpdates` bindings. Ten new controller/app-state integration cases
exercise the monitor iteration used in production, including a check/install
sequence through the repository's actual fixture subprocesses. Only relaunch and
termination are substituted in that sequence; no installed app is replaced.

Verification exposed a gap in the idle check: queued processing and reserved
processing tasks can exist before a progress callback updates the visible stage.
Automatic and manual installation now share `AppState.canInstallUpdate`, which
also checks the processing queue/task reservation. Recording (including pause),
all processing stages, and model setup prevent installation. A restart-in-flight
guard prevents repeated restart actions from launching multiple replacements.

Results:

- `swift build`: passed without warnings.
- `swift run run-tests --unit`: 148 passed, zero failed; all 16 update-related
  cases passed. Tests cover restored preferences, manual checks when automatic
  checks are off, idle transitions, no duplicate installation, daily checks,
  hourly failure retries, failed-install recovery, restart failure/manual retry,
  duplicate restart actions, and unsupported/mismatched app bundles.
- `bash scripts/test-updates.sh`: passed check-only, one simulated installation,
  current-version readback, network-error exit status, Boolean persistence,
  invalid-value rejection, and restoring default preferences. Its config/data and
  logs are isolated under `tmp/update-verification.0D6KIg/`.
- Full deterministic runner: 193 passed, seven failed (200 total). The same
  unchanged transcription disk-space guard reports zero available bytes and
  prevents three transcription and four pipeline/resume cases reaching their
  intended fake operations.
- Fixture pipeline rerun: blocked at that guard before inference. Isolated run:
  `tmp/evals-2026-10-01_21-01-49_50077-50077/`. No new model output was produced.
- Native `eval-settings` fixture: assembled, but LaunchServices again rejected
  launch with `kLSNoExecutableErr` (-10827). Live clicks, keyboard behavior, and
  native relaunch could not be verified.
- Real `cl update --check`, with isolated config/data, reached Homebrew and failed
  fetching the CaptainsLog tap: SSH reported “No user exists for uid 501.” A
  process-only Git HTTPS rewrite retry hit the same failure. Tap configuration
  was not changed, and no application was upgraded. The updater surfaced the
  command failure instead of reporting successful installation.

The automatic controller flow and preference persistence are verified with
fixtures. An actual published-version replacement and OS relaunch remain release
acceptance checks on a working Mac/Homebrew session. Logs for this recheck are
under `/tmp/captainslog-update-reverify-*`. Reproduce the fixture command checks
with [`scripts/test-updates.sh`](../scripts/test-updates.sh) and the controller
checks with `swift run run-tests --unit`.

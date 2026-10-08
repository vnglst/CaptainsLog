# Local development bundles

`swift run CaptainsLogApp` launches the presentation demo described in [README](../README.md). Use [test-ui.sh](../scripts/test-ui.sh) for isolated eval-backed UI checks. The app launcher is separate from the [active UI](SOURCE-MAP.md).

For a packaged source build, use `bash scripts/build-app.sh`. It builds both release executables, copies prompts/resources and native libraries, ad-hoc signs the bundle, and writes `dist/CaptainsLog.app` plus the versioned ZIP. It does not install or replace the Homebrew app. Requirements and release publication remain in [README](../README.md#build).

## Install and launch a development copy

Quit other CaptainsLog instances before launching a development bundle; copies share the bundle identifier. Copy to a separate user application path, retaining a previous copy outside that path for rollback:

```sh
mkdir -p "$HOME/Applications" tmp/dev-builds
# If an earlier development copy exists, archive it to a new, dated directory:
# ditto "$HOME/Applications/CaptainsLogDev.app" tmp/dev-builds/<previous-build>.app

ditto dist/CaptainsLog.app "$HOME/Applications/CaptainsLogDev.app"
```

For CLI/app checks, create an isolated config and invoke the executable directly so it inherits that environment. This bypasses default demo seeding and avoids personal data. The following starts an empty development copy, with update checks disabled; models can be set up separately or use the evaluation runner for fixture processing.

```sh
DEV_RUN_DIR="$(mktemp -d /tmp/captainslog-dev.XXXXXX)"
export CAPTAINS_LOG_CONFIG_PATH="$DEV_RUN_DIR/config.json"
export CAPTAINS_LOG_DATA_DIR="$DEV_RUN_DIR/data"
"$HOME/Applications/CaptainsLogDev.app/Contents/MacOS/cl" config set dataDir "$CAPTAINS_LOG_DATA_DIR"
"$HOME/Applications/CaptainsLogDev.app/Contents/MacOS/cl" config set automaticUpdateChecks false
"$HOME/Applications/CaptainsLogDev.app/Contents/MacOS/cl" config set automaticUpdates false
"$HOME/Applications/CaptainsLogDev.app/Contents/MacOS/CaptainsLog"
```

Do not use `open` or Finder for an isolated check: the launched process may not inherit this shell's config environment. Do not import personal recordings; copy only repository fixtures. A separately installed development copy does not change the Homebrew cask's CLI symlink; invoke its bundled `cl` by full path.

## Identify and roll back

`CFBundleShortVersionString` and `GitCommitHash` in `Contents/Info.plist` identify the declared version and checkout revision. An uncommitted source build can share both values with a different binary. Record dirty state at build time and executable checksums when comparing builds:

```sh
git rev-parse HEAD
git status --short
/usr/libexec/PlistBuddy -c 'Print :GitCommitHash' dist/CaptainsLog.app/Contents/Info.plist
shasum -a 256 dist/CaptainsLog.app/Contents/MacOS/CaptainsLog dist/CaptainsLog.app/Contents/MacOS/cl
codesign --verify --deep --strict dist/CaptainsLog.app
```

Save that output alongside the archived development bundle. Quit the development app, move the current development copy aside, then `ditto` the archived bundle back to `$HOME/Applications/CaptainsLogDev.app`. Verify its recorded checksum/signature and relaunch with isolated config. This restores the binaries/resources only; it does not revert data migrations. Keep each test's isolated data root with the corresponding build.

For ordinary use, quit the development copy and open the existing `/Applications/CaptainsLog.app`. Homebrew installation/upgrade and release publishing follow the public README; do not overwrite its managed app as part of this development workflow.

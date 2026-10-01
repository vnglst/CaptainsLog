# CaptainsLog

CaptainsLog turns voice memos into searchable log entries. Recording, transcription, and text processing run locally on Apple Silicon; no cloud APIs are used.

## Install

The Homebrew cask supports Apple Silicon Macs running macOS 26 or later. Homebrew adds the CaptainsLog tap automatically when you install. The app is ad-hoc signed and not notarized. The cask removes macOS quarantine from the app bundle, so install it only if you trust this project:

```sh
brew install --cask vnglst/captainslog/captainslog
```

The installed app checks for updates at launch and once every 24 hours while open.
Available updates install automatically once recording, processing, and model
setup finish, then the app restarts. Settings → Updates lets you disable automatic
checks or automatic installation, check manually, and install an available update.
After a manual install, use the Restart app button. Updates use the same
Homebrew cask and checksum verification as the initial install; checks refresh
Homebrew metadata over the network without sending recordings or notes.
Source builds and demo mode do not run automatic checks.

You can also check or update through the CLI (quit the app before installing):

```sh
cl update --check
cl update
cl config set automaticUpdates false
cl config set automaticUpdateChecks false
```

Or update directly with:

```sh
brew update
brew upgrade --cask captainslog
```

To uninstall CaptainsLog and move its downloaded models to the Trash while keeping your logs and configuration:

```sh
brew uninstall --cask --zap captainslog
```

Empty the Trash to reclaim the model storage. Models in folders you selected yourself are left untouched.

The first launch downloads the on-device models and needs an internet connection. The models use several gigabytes of storage. After download, recording and inference run locally.

## Build

Requirements: Apple Silicon, macOS 26 or later, Swift 6.2+, and `brew install llama.cpp` for source builds. Xcode IDE is not required.

```sh
swift build
./scripts/build-app.sh
```

The build script creates `dist/CaptainsLog.app` and a versioned ZIP archive. Open the app with:

```sh
open dist/CaptainsLog.app
```

For a safe development demo, run `swift run CaptainsLogApp`. It creates an isolated TNG-themed data copy under `tmp/demo-runtime/` from synthetic notes and locally synthesized audio in [`demo/`](./demo/). The demo copy persists between launches; move it aside to restore the original demo.

## Use

The CLI can record a memo and process it, or process an existing audio file:

```sh
swift run cl pipeline
swift run cl pipeline --input <audio.m4a>
swift run cl resume <stem>
swift run cl list
swift run cl search "project architecture"
```

The resumable pipeline records audio, transcribes it with WhisperKit/CoreML, cleans and categorizes the text, generates a filename, and adds searchable metadata. Intermediate files live under `.pipeline/`; completed entries are saved to `logs/`. Use `swift run cl --help` for other commands, including configuration and individual pipeline stages.

Transcription uses Whisper Large-v2. Cleanup, categorization, filenames, and metadata use Qwen 3.5 9B 4-bit through llama.cpp. Semantic search downloads the multilingual-e5-small embedding model on first use.

## Documentation

- [Changelog and release history](./CHANGELOG.md)
- [Testing gates, evaluation evidence, and remaining checks](./docs/ADR-007-framework-free-test-coverage.md)
- [Build and verification scripts](./scripts/README.md)
- [Troubleshooting](./docs/TROUBLESHOOTING.md)
- [Open product and release work](./docs/PLAN.md)
- [Publishing plan](./docs/PUBLISHING-PLAN.md)
- [Third-party notices](./THIRD-PARTY-NOTICES.md)
- [Evaluation fixtures and scripts](./docs/tng-eval/README.md)
- [Design references](./design/README.md)
- [Architecture decisions](./docs/)

## Testing

The test runner and CLI coverage script use Swift Package Manager and do not require the Xcode IDE:

```sh
swift run run-tests
bash scripts/test-coverage.sh
```

GitHub Actions runs the lightweight, model-free unit suite on pushes and pull requests to `main` (`swift run run-tests --unit`), plus changelog coverage and release-tooling checks. Run `swift run run-tests` locally for the full deterministic suite. Coverage instrumentation, CLI coverage, model evaluations, and UI checks remain opt-in so routine CI stays short.

For the sequential model-backed fixture pipeline, run `bash scripts/run-evals.sh --pipeline`. Run every stage evaluation with `bash scripts/run-evals.sh --suites`; validate saved outputs without inference using `bash scripts/run-evals.sh --validate-run <run-stamp>`. Review generated files against `eval/*/expected/` and the matching stage skill; dated results and semantic findings are recorded in [ADR-007](./docs/ADR-007-framework-free-test-coverage.md#dated-verification-evidence). For native macOS UI checks, use `bash scripts/test-ui.sh eval`; it builds a temporary app bundle and isolates config/data under a temporary directory. Prepared-machine model checks use `scripts/test-model-smoke.sh` with the four `CAPTAINSLOG_*_MODEL_*` environment variables set. Actual microphone capture is a separately confirmed, interactive check via `scripts/test-recorder-hardware.sh`. Neither smoke check runs in GitHub Actions. See [ADR-007](./docs/ADR-007-framework-free-test-coverage.md#test-gates-and-isolation) for fixture and hardware constraints.

## Changelog and releases

Update [CHANGELOG.md](./CHANGELOG.md) under `Unreleased` in the same commit as
any repository change, including documentation, fixtures, and tooling. Use
`Added`, `Changed`, `Fixed`, `Removed`, or `Security` as appropriate; describe
what actually changed. Review `git diff` and `git log` against the latest release
tag. CI checks for a changelog update in each push or pull request; human review
checks that the entries cover the changes. Generated cask-only release commits
are covered by the corresponding release's packaging entry.

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
for new commits, for example `fix(updater): repair tap fetches` or
`feat(search): add filters`. The default release command reads full commit
messages since the latest reachable `vMAJOR.MINOR.PATCH` tag, which must match
`VERSION`, and chooses the highest applicable bump:

- `fix` and `perf`: patch.
- `feat`: minor.
- A `!` after the type/scope, or a `BREAKING CHANGE:` / `BREAKING-CHANGE:` footer:
  major for `1.x` and later; minor during `0.x` development.
- Other types (`docs`, `chore`, `test`, `ci`, etc.): no automatic release unless
  marked as breaking. If no releasable commits exist, the command exits without
  changing files or creating a commit/tag.

Legacy messages are reported and ignored for version selection; their changes
remain in the changelog. New commit messages must follow the convention.
Dry runs use local tags and committed history without fetching. Actual release
preparation fetches tags first. Changelog entries still require human review.

From a clean `main` checkout with the local models installed, preview a release:

```sh
swift scripts/release.swift --dry-run
```

Create the release locally, or create and publish it in one command:

```sh
swift scripts/release.swift
# Or, after reviewing the changes and evaluation findings:
swift scripts/release.swift --publish
```

Use `auto` explicitly if desired, or override with `patch`, `minor`, `major`, or
an explicit version (for example, a maintenance-only release).
The command checks Git state and existing tags, fetches `origin/main`, runs the
release-tooling tests, `swift build`, `swift run run-tests`, and the full fixture
pipeline and stage suites sequentially with isolated config/data. Failed checks
stop before version/changelog edits, commits, or tags. Model evaluation scores
and artifacts still need semantic review under the stage skills; see [the
publication gates](./docs/PUBLISHING-PLAN.md) for remaining manual checks.

After checks pass, the command bumps `VERSION`, moves Unreleased entries into a
dated release section, adds the packaging entry, updates comparison links, and
creates a `chore(release): CaptainsLog <version>` commit and annotated tag.
Without `--publish`, inspect the
commit and then push both together using the command printed by the script.
If a push fails, the local commit and tag remain; retry that printed push instead
of running another version bump.

Pushing the tag triggers GitHub Actions to validate the matching dated changelog
entry, build the app/CLI archive, publish those notes and the archive, and update
the source cask and Homebrew tap. Reruns also refresh the release notes. Check the
workflow results and test the published install/upgrade before announcing the
release. `HOMEBREW_TAP_TOKEN` must be configured as described in
[ADR-010](./docs/ADR-010-tag-driven-homebrew-releases.md).

Release-tooling tests use Swift, Bash, and Git:

```sh
bash scripts/test-release-tooling.sh
swift scripts/release.swift notes 0.1.2
swift scripts/release.swift check <base-commit> <head-commit>
```

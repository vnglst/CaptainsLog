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

- [Testing gates, evaluation evidence, and remaining checks](./docs/ADR-007-framework-free-test-coverage.md)
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

GitHub Actions runs only the lightweight, model-free unit suite on pushes and pull requests to `main` (`swift run run-tests --unit`). Run `swift run run-tests` locally for the full deterministic suite. Coverage instrumentation, CLI coverage, model evaluations, and UI checks remain opt-in so routine CI stays short.

For the sequential model-backed fixture pipeline, run `bash scripts/run-evals.sh --pipeline`. Run every stage evaluation with `bash scripts/run-evals.sh --suites`; validate saved outputs without inference using `bash scripts/run-evals.sh --validate-run <run-stamp>`. Review generated files against `eval/*/expected/` and the matching stage skill; dated results and semantic findings are recorded in [ADR-007](./docs/ADR-007-framework-free-test-coverage.md#dated-verification-evidence). For native macOS UI checks, use `bash scripts/test-ui.sh eval`; it builds a temporary app bundle and isolates config/data under a temporary directory. Prepared-machine model checks use `scripts/test-model-smoke.sh` with the four `CAPTAINSLOG_*_MODEL_*` environment variables set. Actual microphone capture is a separately confirmed, interactive check via `scripts/test-recorder-hardware.sh`. Neither smoke check runs in GitHub Actions. See [ADR-007](./docs/ADR-007-framework-free-test-coverage.md#test-gates-and-isolation) for fixture and hardware constraints.

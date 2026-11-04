# CaptainsLog

CaptainsLog turns your spoken thoughts into clear, organized, searchable notes. Record your week, capture an idea, or practice a talk. It transcribes your recordings, cleans up the text, and sorts your notes into categories you choose—without uploading your recordings or notes.

It’s a free, open-source Mac app inspired by the captain’s logs in Star Trek.

Recording, transcription, and text processing run locally on Apple Silicon; no cloud APIs are used.

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

The first launch downloads the on-device models and needs an internet connection. The models use several gigabytes of storage. After download, recording and inference run locally. Settings → Models shows disk usage and lets you delete model files while the app is idle. Deleted models download automatically on the next transcription or smart search. For the CLI, quit the app and use `cl models` or `cl models --delete whisper` (also `qwen` or `embeddings`).

## Build

Requirements: Apple Silicon, macOS 26 or later, Swift 6.2+, Make (included with Apple Command Line Tools), and internet access for the initial SwiftPM dependency download. Native inference libraries require no Homebrew installation. Xcode IDE is not required.

```sh
make build
make packaging
```

The packaging command creates `dist/CaptainsLog.app` and a versioned ZIP archive. Open the app with:

```sh
open dist/CaptainsLog.app
```

The development and release configurations both use the checksum-verified upstream
`llama-b11723-xcframework.zip` (llama.cpp revision
`31288c9c66e59377f7788d920678a565bb89dd37`). SwiftPM verifies SHA-256
`c3911a2dba69e68e87e0306090cd3999a642f8caaf29a7587e2d5685bce1a9f8`
before resolving the matching llama/GGML headers and framework. The universal
macOS slice contains arm64 and x86_64 code; CaptainsLog builds arm64 with deployment
target macOS 26.0. Upstream built the framework for macOS 13.3 with SDK 26.4
(Apple clang 21.0.0, clang-2100.0.123.102; linker 1266.8), so it is compatible
with the app's higher minimum. Its Release
configuration enables Metal, embedded Metal shaders and Accelerate BLAS,
disables OpenMP and native-host tuning, and merges GGML into the framework.
No separate libomp or Homebrew runtime is loaded.

Reproducibility here means identical prebuilt native code and headers across clean
resolutions, local builds and releases. It does not promise identical app signatures,
ZIP timestamps or a byte-identical rebuild of upstream's compiler output. Run
`make tests-runtime` to independently download, verify and compare two
clean unsigned framework extractions. Packaging runs `scripts/check-runtime.swift`
to reject external runtime paths and verify the app/CLI deployment target.

Two upstream Swift packages are retained in `Vendor/` with only dependency
manifest patches, allowing the newest Swift Crypto and yyjson releases.
See [vendored package provenance](Vendor/README.md) before refreshing them.

To upgrade the runtime, select an immutable upstream release and source commit,
verify the release asset's SHA-256 independently, update the URL/checksum/revision
in `Package.swift` and this description, and refresh that revision's MIT and native helper license notices under
`Sources/NativeRuntime/`. Review upstream `build-xcframework.sh` at the
pinned commit for build flags and deployment requirements. Then run the runtime
check, clean debug and release builds, deterministic tests, packaging/signature
checks and sequential fixture evaluations before committing. Changing system
llama.cpp, GGML or libomp installations has no effect on the selected artifact.

For a safe development demo, run `make dev` (`make` and `make run` are aliases). It launches the cached debug app directly when sources and package manifests are unchanged, bypassing SwiftPM startup. If the app is missing or inputs changed (including added or removed source files), it incrementally builds only the app and its dependencies first. No packaging, tests or evaluations run. The first build needs dependency downloads and compilation. It creates an isolated TNG-themed data copy under `tmp/demo-runtime/` from synthetic notes and locally synthesized audio in [`demo/`](./demo/). The demo copy persists between launches; move it aside to restore the original demo.

## Use

The CLI can record a memo and process it, or process an existing audio file:

```sh
make cli ARGS="pipeline"
make cli ARGS="pipeline --input <audio.m4a>"
make cli ARGS="resume <stem>"
make cli ARGS="list"
# Quit the app, then delete generated outputs, keeping audio and settings:
make cli ARGS="delete-outputs --confirm"
# Process all pending recordings with current settings:
make cli ARGS="resume"
make cli ARGS='search "project architecture"'
```

M4A and QuickTime audio (`.mov`, `.qt` and `.qta`) files in the configured `audio/` folder are picked up by the app. Imported files keep their original extension. The CLI also accepts WAV and MP3 audio.

The resumable pipeline records audio, transcribes it with WhisperKit/CoreML, cleans and categorizes the text, generates a filename, and adds searchable metadata. All processing keeps the system awake,
including with the screen locked, while allowing the display to sleep. Normal idle
sleep resumes when processing finishes, fails or finishes stopping after a pause.
Keep the Mac connected to power with the lid open for an overnight run; lid closure
and deliberate system sleep can still suspend processing. Settings lets you delete
all intermediate results, finished logs and reprocessing backups while keeping
original audio and settings. Return to Logs to process all unprocessed recordings
with the current settings.

Quit cancels active work and finalizes any recording. If a native model call cannot
stop within two seconds, the app exits after the recording writer closes, preserving
original audio and saved checkpoints. The unfinished stage remains pending.

Pause cancels the active worker and clears queued requests. Resume, Process pending,
Reprocess and completed recordings share one serial queue; requests made while
native cancellation finishes show as queued and run afterwards. Resume detects the
latest saved stage when its turn starts. Reprocess immediately deletes derived outputs
and queues fresh processing, including when models must download. A later Pause or
Quit discards waiting processing but keeps the outputs deleted.

Intermediate files live under `.pipeline/`; completed entries are saved to `logs/`. Use `make cli ARGS=--help` for other commands, including configuration and individual pipeline stages.

Context and initial setup let you choose categories for future processing. Removing
one keeps its existing folders and logs. The category menu beside search filters
Logs and search results; all categories are initially selected. The CLI supports
the same configuration:

```sh
cl config set categories "personal,professional,research"
cl config set categories unset  # Restore built-in defaults
```

Context also contains personal context and name and term corrections for cleanup. Changes save automatically and apply to future processing.

Transcription uses Whisper Large-v2. Cleanup, categorization, filenames, and metadata use Qwen 3.5 9B 4-bit through llama.cpp. Semantic search downloads the multilingual-e5-small embedding model on first use.

## Documentation

- [Changelog and release history](./CHANGELOG.md)
- [Testing decision](./docs/0023-keep-framework-free-verification-evidence-outside-backlog-tasks.md)
- [Development commands](./scripts/README.md)
- [Troubleshooting](#troubleshooting)
- [Backlog tasks](./backlog/tasks/)
- [Release procedure](#changelog-and-releases)
- [Third-party notices](./THIRD-PARTY-NOTICES.md)
- [Active evaluation fixtures](./eval/)
- [Three TNG recording scripts](./eval/tng-reference/README.md)
- [Design references](./design/README.md)
- [Architecture decisions](#architecture-decisions)

## License

CaptainsLog’s original source code is licensed under the [MIT license](LICENSE).
Third-party software, model weights and example content retain their own
licenses and rights; see [Third-party notices](THIRD-PARTY-NOTICES.md). The release
app includes the project license, third-party notices and bundled component license
texts in its Resources folder.

## Architecture decisions

Numbered [architecture decision records](./docs/) document the project's design decisions.
The [repository instructions](./AGENTS.md#documentation) describe how records are maintained.

## Backlog

The [Backlog.md tasks](./backlog/tasks/) track planned work and verification.
Backlog ownership and workflow are documented in [AGENTS.md](./AGENTS.md#backlog).

## Testing

The test runner and CLI coverage script use Swift Package Manager and do not require the Xcode IDE:

```sh
make tests
make tests-coverage
```

Before running the full suite, coverage or updater checks,
quit CaptainsLog when recording and processing have finished. The updater fixtures
use fake Homebrew commands but still check for the real running app, so isolated
config/data alone does not prevent those failures. Run checks from the repository
root: tests resolve synthetic fixtures under `eval/` relative to that directory.

GitHub Actions runs only when a release tag (`v*`) is pushed; ordinary branch pushes and pull requests do not start workflows. The release workflow validates the tag and changelog, builds the release app and CLI, verifies packaging, and publishes the archive and casks. It does not run test suites or build debug products. Run the suite locally during development, or use `make tests-unit` for a lightweight, model-free check. Coverage instrumentation, CLI coverage, model evaluations, and UI checks remain opt-in.

Use `make help` to discover commands and `NAME=value` for options; for example,
`make build CONFIGURATION=release` or `make tests ARGS=--unit`. Make is the
development entry point; scripts in `scripts/` are its implementation helpers.

For the sequential model-backed fixture pipeline, run `make evals-pipeline`. Run every stage evaluation with `make evals-suites`; validate saved outputs without inference using `make evals ARGS="--validate-run <run-stamp>"`. Review generated files against `eval/*/expected/` and the matching stage skill. For native macOS UI checks, use `make ui`; it builds a temporary app bundle and isolates config/data under a temporary directory. Prepared-machine model checks use `make tests-model` with the four `CAPTAINSLOG_*_MODEL_*` environment variables set. Actual microphone capture is a separately confirmed, interactive check via `make tests-recorder`. Neither smoke check runs in GitHub Actions. Use isolated configuration/data, only repository eval fixtures, and no personal data. Demo material is for presentation. A transcript-seeded continuation cannot establish a successful full audio run.

## Fixture evaluations

Run `make evals-list` to discover cases without loading models.
Use `make evals STAGE=filename CASE="fixture stem"` for focused work,
`make evals-pipeline` for the full audio fixture pipeline and `make evals-suites`
for all stage suites. Select the Dutch TNG pipeline with
`make evals-pipeline`; its default is the reviewed Dutch TNG recording. Plain `make evals` runs pipeline then suites. Quote stems
containing spaces; categorization and enrichment also use `STAGE`. Additional
evaluator flags are passed with `ARGS="..."`.

Revalidate a saved bundle with `make evals ARGS="--validate-run RUN_DIR"`; legacy
timestamped outputs support `ARGS="--validate-categorize STAMP"` and
`ARGS="--validate-enrich STAMP"`. Use `ARGS="--baseline RUN_DIR"` for comparison evidence. `ARGS="--combined-metadata"` evaluates experimental combined generation with fixture seeds defaulting to42. `cl pipeline --combined-metadata` opts a fresh pipeline into the experiment; default processing keeps separate stages because semantic equivalence is not established. Individual stage commands retain their separate prompts. Missing models, malformed
outputs and existing run directories fail explicitly. `make tests-evals`
checks orchestration without inference.

Each run isolates config/data under a new temporary run directory, pins the selected
model files and snapshots fixtures. Model overrides use the `CAPTAINS_LOG_EVAL_`
QWEN_FOLDER, QWEN_FILE, QWEN_LABEL, WHISPER_FOLDER and WHISPER_MODEL variables;
`CAPTAINS_LOG_EVAL_RUN_DIR` selects a new run directory. Enrichment dates, times and
seeds come from its case manifest; the pipeline and other stages retain their
sampling defaults. Text cases reuse weights sequentially with fresh contexts and
samplers. Compile before inference; never edit a running evaluator or start another
model job concurrently. The [TNG reference folder](eval/tng-reference/README.md)
contains three personal log scripts aboard the Enterprise, each about ten
minutes long, in English, Dutch and German, with paired expected outputs.
The corrected, owner-reviewed Dutch recording is the only active transcription case.
Its preserved baseline measures transcription only; end-to-end evaluation and
verification of downstream references are deferred to TASK-82. Other recordings
and earlier review rounds are preserved under `eval/transcribe/history/`; English
and German TNG audio are still to be recorded by the owner.

For opt-in native startup and quit performance checks, close the installed app,
provide the prepared `CAPTAINSLOG_WHISPER_MODEL_FOLDER` and
`CAPTAINSLOG_QWEN_MODEL_FOLDER`, and run
`make tests-app-performance RUN_DIR=/absolute/new/output`. It uses only eval
fixtures and fresh isolated config/data, records real native decoding and process
termination, and does not use the microphone. See the
[native performance check](scripts/README.md#native-performance-regression-check)
for timing scopes, hardware-dependent limits, retained evidence and abort behavior.

Audio evaluation runs also prepare a local listening-review app. Reopen a saved run
without loading models:

```sh
make evals-review RUN_DIR=tmp/evals-RUN
# Optional: compare another saved run or a folder of per-recording .txt transcripts:
make evals-review RUN_DIR=tmp/evals-RUN COMPARISON_RUN=tmp/comparison-RUN
```

Open the printed localhost URL. The app pairs audio fragments with the selected
run's reference and raw transcripts, highlights differences, and saves your wording
and decisions in `review-app/review-state.json` inside that run. Export provides a
JSON copy. Mark corrupted or incorrect audio, record and preview a replacement,
then select the take to use. **Build corrected recording** exports one M4A with
approved replacements and an edit map for shifted timestamps. Original fixtures
stay intact; overlapping ranges must be adjusted before combining. Microphone
permission is requested only when you press Record. Regenerating the app preserves saved reviews; changed audio or reference
text requires verification again. Reviews do not overwrite fixture references.
Use `PORT=8778` for another local port or `ARGS=--prepare-only` to prepare files
without serving them. The app uses bundled Swift tooling and browser audio seeking;
Python, FFmpeg and additional model downloads are not required.

Transcription cases are pinned in `eval/transcribe/cases.json`. Every transcription
review includes aligned Word Error Rate (`wer.json`, `wer.md`); the run's
`transcription-scores.json` contains a word-weighted aggregate. WER counts
substitutions, deletions and insertions against verbatim spoken words. Unverified
scripts and legacy references produce explicitly provisional scores until checked
against the recording; do not copy Whisper output into its own reference.
The normalization and alignment policy lives in the transcription review skill.

Evaluation bundles include source and generated text, validation results, model/runtime
identity, hashes, settings and timings. Heuristic scores do not establish completeness
or grounding; see the [semantic review guidance](./AGENTS.md#semantic-review).

## Troubleshooting

Reproduce processing issues through the CLI using synthetic fixtures and isolated
config/data before debugging the UI. The transcriber runs spectrogram extraction on CPU and selects CPU/Neural Engine
for the Whisper encoder and decoder, excluding the CoreML Metal prediction path
that can abort with an MPSGraph tensor shape/stride assertion. Text inference uses in-process
libllama and all available GPU layers. Check versioned llama/GGML package includes
and actual bundled library paths for header or library failures. A missing llama-cli
executable does not diagnose this integration. Stop concurrent compilation/inference
before investigating memory issues; preserve the original failing synthetic case.

## Changelog and releases

[CHANGELOG.md](./CHANGELOG.md) records changes under `Unreleased` until a release is prepared.
Contribution rules are documented in [AGENTS.md](./AGENTS.md#documentation).

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

From a clean `main` checkout, preview a release:

```sh
make release ARGS=--dry-run
```

Create the release locally, or create and publish it in one command:

```sh
make release
# Or, after reviewing the changes:
make release ARGS=--publish
```

Use `BUMP=auto` explicitly if desired, or override with `BUMP=patch`, `BUMP=minor`,
`BUMP=major`, or an explicit `BUMP=1.2.3` version (for example, a maintenance-only release).
The command checks Git state and existing tags, fetches `origin/main`, and runs
lightweight version/changelog self-checks, then prepares the release commit and tag.
It does not compile the app, run tests, or load models; the app can remain open.
The tag workflow builds only the release app and CLI, checks bundled runtime
compatibility and signatures, and verifies the archive before publishing.
Run relevant development checks explicitly before releasing: `make tests`,
`make tests-release`, and `make tests-runtime` remain available. Run `make evals`
separately when evaluating model quality, and review its artifacts under the
stage skills. See [the backlog
tasks](./backlog/tasks/) for outstanding acceptance checks.

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
[ADR-024](./docs/0024-separate-release-publication-from-development-checks.md).

Release-tooling tests use Swift and Git:

```sh
make tests-release
make release-notes VERSION=0.1.2
make release-check BASE=<base-commit> HEAD=<head-commit>
```

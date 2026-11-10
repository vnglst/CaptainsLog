# Development and verification

Agent reference; read the relevant sections for the work at hand.
See [repository instructions](../AGENTS.md) for policy.

## Repository layout

- `Sources/`: production Swift targets; native preview states live alongside the UI in `Sources/CaptainsLog/Previews/`.
- `Tests/CaptainsLogTests/`: the framework-free deterministic test runner.
- `Packages/`: shared local Swift packages for fixture loading and development-tool support.
- `Resources/`: app icons, prompts and bundled native-runtime license notices.
- `eval/suites/`: stage cases, inputs, expected outputs and historical evaluation evidence.
- `eval/fixtures/`: shared demo context, the demo manifest and reference scripts.
- `eval/tools/` and `eval/skills/`: evaluation automation, listening review and semantic review workflows.
- `scripts/`: build, packaging, release and other development automation; start with [the command guide](../scripts/README.md).
- `docs/`: numbered architecture decisions. `backlog/` contains the owner-managed backlog.
- `design/`, `website/`, `Casks/` and `Vendor/`: design references, the public site, Homebrew distribution and vendored dependencies.

Swift targets and local packages use their module names. Evaluation suites and
supporting content use lowercase names. Generated builds, app bundles and runtime
copies stay in ignored `.build/`, `dist/` and `tmp/` directories.


## Development demo

For a safe development demo, run `make dev` (`make` and `make run` are aliases). It launches the cached debug app directly when sources and package manifests are unchanged, bypassing SwiftPM startup. If the app is missing or inputs changed (including added or removed source files), it incrementally builds only the app and its dependencies first. No packaging, tests or evaluations run. The first build needs dependency downloads and compilation. It creates an isolated data copy under `tmp/demo-runtime-eval/` from the same canonical audio and text fixtures used by evaluations and the native UI harness, selected in [`eval/fixtures/demo-library.json`](../eval/fixtures/demo-library.json). The demo copy persists between launches; move it aside to restore the original demo.

`make dev` seeds an isolated copy of the canonical evaluation fixtures under
`tmp/demo-runtime-eval/`, including completed logs, pending recordings, a fictional
Enterprise officer's context and spelling corrections. The manifest is
[`eval/fixtures/demo-library.json`](../eval/fixtures/demo-library.json). Saved edits
are retained; quit and move the runtime directory aside to reset the demo.
Microphones, model storage and updates reflect the running app.

`make ui` creates a fresh isolated copy and simulates UI states without downloading
models or discovering recordings. Its processing and recording controls still use
real inference and audio hardware. `make dev` uses the real processing pipeline.
An explicit `CAPTAINS_LOG_CONFIG_PATH` bypasses demo seeding for isolated checks.
Browsing a demo or preview does not verify inference.


## Development CLI

Run the CLI from the source checkout using Make. Installed app users can use `cl` directly; see [command-line use](../README.md#command-line-use).

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

For the sequential model-backed fixture pipeline, run `make evals-pipeline`. Run every stage evaluation with `make evals-suites`; validate saved outputs without inference using `make evals ARGS="--validate-run <run-stamp>"`. Review generated files against `eval/suites/*/expected/` and the matching stage skill. For native macOS UI checks, use `make ui`; it builds a temporary app bundle and isolates config/data under a temporary directory. Prepared-machine model checks use `make tests-model` with the four `CAPTAINSLOG_*_MODEL_*` environment variables set. Actual microphone capture is a separately confirmed, interactive check via `make tests-recorder`. Neither smoke check runs in GitHub Actions. Use isolated configuration/data, only repository eval fixtures, and no personal data. Demo material is for presentation. A transcript-seeded continuation cannot establish a successful full audio run.


## Troubleshooting

Reproduce processing issues through the CLI using synthetic fixtures and isolated
config/data before debugging the UI. The transcriber runs spectrogram extraction on CPU and selects CPU/Neural Engine
for the Whisper encoder and decoder, excluding the CoreML Metal prediction path
that can abort with an MPSGraph tensor shape/stride assertion. Text inference uses in-process
libllama and all available GPU layers. Check versioned llama/GGML package includes
and actual bundled library paths for header or library failures. A missing llama-cli
executable does not diagnose this integration. Stop concurrent compilation/inference
before investigating memory issues; preserve the original failing synthetic case.

## Further references

- [Technical overview and architecture diagrams](../website/technical.html)
- [Testing decision](../docs/0023-keep-framework-free-verification-evidence-outside-backlog-tasks.md)
- [Active evaluation fixtures](../eval/README.md)
- [Three TNG recording scripts](../eval/fixtures/tng-reference/README.md)
- [Design references](../design/README.md)
- [Website development and publishing](../website/README.md)

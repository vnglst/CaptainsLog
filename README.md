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
`llama-b11512-xcframework.zip` (llama.cpp revision
`a11f57ba93797579a5d1855ee216a31f10242676`). SwiftPM verifies SHA-256
`3f6a7d0fecbf49781445bba900dc0a4a7e76303482765f5912a4a959d5fa2c38`
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
make cli ARGS='search "project architecture"'
```

The resumable pipeline records audio, transcribes it with WhisperKit/CoreML, cleans and categorizes the text, generates a filename, and adds searchable metadata. Intermediate files live under `.pipeline/`; completed entries are saved to `logs/`. Use `make cli ARGS=--help` for other commands, including configuration and individual pipeline stages.

Transcription uses Whisper Large-v2. Cleanup, categorization, filenames, and metadata use Qwen 3.5 9B 4-bit through llama.cpp. Semantic search downloads the multilingual-e5-small embedding model on first use.

## Documentation

- [Changelog and release history](./CHANGELOG.md)
- [Testing decision](./docs/0007-framework-free-test-coverage.md)
- [Work and verification findings](./backlog/tasks/)
- [Development commands](./scripts/README.md)
- [Troubleshooting](#troubleshooting)
- [Backlog tasks](./backlog/tasks/)
- [Release procedure](#changelog-and-releases)
- [Third-party notices](./THIRD-PARTY-NOTICES.md)
- [Active evaluation fixtures](./eval/)
- [Inactive TNG reference corpus](./eval/tng-reference/README.md)
- [Design references](./design/README.md)
- [Architecture decision workflow](#architecture-decisions)

## License

CaptainsLog’s original source code is licensed under the [MIT license](LICENSE).
Third-party software, model weights and example content retain their own
licenses and rights; see [Third-party notices](THIRD-PARTY-NOTICES.md). The release
app includes the project license, third-party notices and bundled component license
texts in its Resources folder.

## Architecture decisions

ADRs record significant, hard-to-reverse architecture decisions. The records
are Markdown files in [`docs/`](./docs/); [Backlog.md](#backlog) tracks work to
make or carry out those decisions. Before changing architecture, read the
relevant ADRs. From the repository root, install the separate
[`adrs` CLI](https://joshrotenberg.com/adrs/) with `brew install adrs`, then use:

```sh
adrs list                       # Browse existing decisions
adrs search "inference"         # Find decisions by subject
adrs new --no-edit "Decision title"
adrs doctor                     # Check numbering and links
```

Read each file for its status; `adrs list -l` does not parse every legacy
status line correctly.

`adrs new` creates the next numbered file in `docs/` using a minimal MADR-style
template. Edit that file to state the decision, its status, and its known context
or rationale; remove empty template sections. Do not invent missing context or
alternatives.
Keep ADRs to 300 words or fewer; allow up to 500 only when essential rationale
needs more room. Include the decision, relevant context, and consequences.
Keep `docs/` limited to numbered ADRs; put implementation scope and dated
verification findings directly in self-contained Backlog tasks, without file links. Editorial shortening must preserve existing decisions, dates, and statuses. If a decision changes, create a new ADR and link the earlier record
from it, stating that the new decision supersedes it. Commit
the ADR with its related change, Backlog task, and changelog entry.

## Backlog

The [Backlog.md tasks](./backlog/tasks/) are Markdown files committed with the project. Install the separate CLI with `brew install backlog-md`. From the repository root:

You control backlog content, scope, requirements and task creation. Agents may
edit, rewrite, clarify or organize content you provide, but must never invent
backlog items, requirements or acceptance criteria. They must ask you for missing
input; backlog refinement does not authorize them to define scope or requirements.
Tasks and drafts may be created only when you explicitly ask, using your supplied
content. Discovered bugs, follow-up ideas, cleanup and suggested improvements
should be reported to you without adding backlog items. This rule takes precedence
over generic Backlog.md CLI guidance. Small, mechanical changes do not need a task.

- **To Do:** Agreed tasks that have not been selected for agent work.
- **Next:** Tasks you select for agents to pick up. Agents leave them here while implementing.
- **Verify:** Implementation and agent checks are finished; you still need to review them.
- **Complete:** You have verified the work and it is ready for release.

```sh
backlog board                         # Review work by status
backlog task list                     # List tasks
backlog task view TASK-1              # Read a task
backlog draft create "Possible idea"  # Capture an idea
backlog draft promote DRAFT-1         # Turn an agreed idea into a task
backlog task create "Task title"      # Or create a task directly
backlog task edit TASK-1 --status "Next"    # Select it for agent work
backlog task edit TASK-1 --append-notes "Finding or decision"
backlog task edit TASK-1 --status "Verify" --final-summary "What changed and how it was checked"
backlog task edit TASK-1 --status "Complete"  # After your review
```

Each task should explain the problem, why it matters, what should change, and
how completion will be checked in clear, complete sentences. It must make sense
on its own in the Backlog app, where linked repository files may not be visible.
Include essential scope, context, current findings and review limits in the task.
Do not link to other repository files or add file paths to task reference or
documentation fields. There is no fixed word limit.
Keep one task per coherent outcome, with research, implementation and verification
as phases or acceptance checks inside it. Split work only when it delivers
independently useful outcomes. Archive superseded tasks after preserving their
scope and findings in the consolidated task.
Condense outdated session notes while preserving the explanation, dependencies,
status and checked acceptance criteria.

Use the CLI for task updates. If review finds more work, move the task back to `Next` with a note. Commit the Markdown changes with the related code and a changelog entry. Keep essential procedures and findings in the task, and durable decisions in ADRs.

## Testing

The test runner and CLI coverage script use Swift Package Manager and do not require the Xcode IDE:

```sh
make tests
make tests-coverage
```

GitHub Actions runs only when a release tag (`v*`) is pushed; ordinary branch pushes and pull requests do not start workflows. The release workflow runs release-tooling checks and the full deterministic suite (`make tests`) before packaging. Run the suite locally during development, or use `make tests-unit` for a lightweight, model-free check. Coverage instrumentation, CLI coverage, model evaluations, and UI checks remain opt-in.

Use `make help` to discover commands and `NAME=value` for options; for example,
`make build CONFIGURATION=release` or `make tests ARGS=--unit`. Make is the
development entry point; scripts in `scripts/` are its implementation helpers.

For the sequential model-backed fixture pipeline, run `make evals-pipeline`. Run every stage evaluation with `make evals-suites`; validate saved outputs without inference using `make evals ARGS="--validate-run <run-stamp>"`. Review generated files against `eval/*/expected/` and the matching stage skill; record dated results, semantic findings and limitations directly in the related task. For native macOS UI checks, use `make ui`; it builds a temporary app bundle and isolates config/data under a temporary directory. Prepared-machine model checks use `make tests-model` with the four `CAPTAINSLOG_*_MODEL_*` environment variables set. Actual microphone capture is a separately confirmed, interactive check via `make tests-recorder`. Neither smoke check runs in GitHub Actions. Use isolated configuration/data, only repository eval fixtures, and no personal data. Demo material is for presentation. A transcript-seeded continuation cannot establish a successful full audio run.

## Fixture evaluations

Run `make evals-list` to discover cases without loading models.
Use `make evals STAGE=filename CASE="fixture stem"` for focused work,
`make evals-pipeline` for the full audio fixture pipeline and `make evals-suites`
for all stage suites. Plain `make evals` runs pipeline then suites. Quote stems
containing spaces; categorization and enrichment also use `STAGE`. Additional
evaluator flags are passed with `ARGS="..."`.

Revalidate a saved bundle with `make evals ARGS="--validate-run RUN_DIR"`; legacy
timestamped outputs support `ARGS="--validate-categorize STAMP"` and
`ARGS="--validate-enrich STAMP"`. Use `ARGS="--baseline RUN_DIR"` for comparison evidence. Missing models, malformed
outputs and existing run directories fail explicitly. `make tests-evals`
checks orchestration without inference.

Each run isolates config/data under a new temporary run directory, pins the selected
model files and snapshots fixtures. Model overrides use the `CAPTAINS_LOG_EVAL_`
QWEN_FOLDER, QWEN_FILE, QWEN_LABEL, WHISPER_FOLDER and WHISPER_MODEL variables;
`CAPTAINS_LOG_EVAL_RUN_DIR` selects a new run directory. Enrichment dates, times and
seeds come from its case manifest; the pipeline and other stages retain their
sampling defaults. Text cases reuse weights sequentially with fresh contexts and
samplers. Compile before inference; never edit a running evaluator or start another
model job concurrently. The retained TNG reference corpus is not an active suite.

### Semantic review

Read each selected case’s input, expected output, generated output and validation
in the printed review bundle. Fill its preserved report with concrete omissions,
changed meaning, added or hallucinated content, baseline improvements/regressions,
stage observations and remaining limits. Explain why each difference matters.
Metadata records model/runtime identity, source/prompt/fixture hashes, settings,
revision and timings; validation success cannot prove grounding or completeness.
Expected wording is a reference rather than the only valid wording. Baseline diffs
and heuristic scores help navigation but do not replace human review. Record durable
dated findings in the corresponding task; do not claim speed or token savings without
measurements and comparable timing scopes.

## Troubleshooting

Reproduce processing issues through the CLI using synthetic fixtures and isolated
config/data before debugging the UI. The transcriber currently selects CPU/GPU
compute; ANE advice may describe an older bundle. Text inference uses in-process
libllama and all available GPU layers. Check versioned llama/GGML package includes
and actual bundled library paths for header or library failures. A missing llama-cli
executable does not diagnose this integration. Stop concurrent compilation/inference
before investigating memory issues; preserve the original failing synthetic case.

The active UI and Settings are embedded in FieldNotesContentView; the launcher is
AppMain. Core stage implementations and the sequential inference gate live in
CaptainsLogCore, while command types live in cl. Framework-free tests are in the
run-tests executable. For isolated native UI inspection use the existing UI harness;
packaged development executables must be launched directly to inherit their isolated
configuration. Record the bundle revision, dirty state, signatures and binary checksums
when comparing builds. A rollback restores binaries/resources, not data migrations.

## Changelog and releases

Update [CHANGELOG.md](./CHANGELOG.md) under `Unreleased` in the same commit as
any repository change, including documentation, fixtures, and tooling. Use
`Added`, `Changed`, `Fixed`, `Removed`, or `Security` as appropriate; describe
what actually changed. Review `git diff` and `git log` against the latest release
tag. Use `make release-check BASE=<base-commit> HEAD=<head-commit>` locally
to check changelog coverage; human review checks that the entries cover the changes. Generated cask-only release commits
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
The command checks Git state and existing tags, fetches `origin/main`, runs the
release-tooling tests, `make build`, and `make tests` sequentially with isolated
config/data. Failed checks stop before version/changelog edits, commits, or tags.
Releases do not run model evaluations or other non-deterministic checks and do
not require local models. Run `make evals` separately when evaluating model
quality, and review its artifacts under the stage skills. See [the backlog
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
[ADR-010](./docs/0010-tag-driven-homebrew-releases.md).

Release-tooling tests use Swift and Git:

```sh
make tests-release
make release-notes VERSION=0.1.2
make release-check BASE=<base-commit> HEAD=<head-commit>
```

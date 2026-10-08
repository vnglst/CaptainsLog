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
- [Testing gates and isolation](./docs/testing.md)
- [Dated testing and evaluation evidence](./docs/testing-verification.md)
- [Build and verification scripts](./scripts/README.md)
- [Troubleshooting](./docs/TROUBLESHOOTING.md)
- [Backlog tasks](./backlog/tasks/)
- [Publication procedures and review record](./docs/PUBLISHING-PLAN.md)
- [Third-party notices](./THIRD-PARTY-NOTICES.md)
- [Evaluation fixtures and scripts](./docs/tng-eval/README.md)
- [Design references](./design/README.md)
- [Architecture decision workflow](#architecture-decisions)

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
needs more room. Include the decision, relevant context, and consequences. Link
to procedures, implementation details, and dated evaluation evidence rather than
embedding them. Editorial shortening must preserve existing decisions, dates, and statuses. If a decision changes, create a new ADR and link the earlier record
from it, stating that the new decision supersedes it. Commit
the ADR with its related change, Backlog task, and changelog entry.

## Backlog

The [Backlog.md tasks](./backlog/tasks/) are Markdown files committed with the project. Install the separate CLI with `brew install backlog-md`. From the repository root:

You control task creation. Agents may add tasks or drafts only at your request or
to track work you directly requested. Discovered bugs, follow-up ideas, cleanup,
and suggested improvements should be reported to you without automatically
adding backlog items. This rule takes precedence over generic Backlog.md CLI
guidance about creating tasks. Small, mechanical changes do not need a task.

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

Keep task prose within 150 words, excluding metadata and headings; prefer 100.
Use a short scope statement, testable acceptance checks, and only the current
plan/findings plus a brief final summary. Link detailed procedures and evidence
rather than copying them into tasks; condense outdated notes. Preserve scope,
dependencies, status, and checked criteria when shortening.

Use the CLI for task updates. If review finds more work, move the task back to `Next` with a note. Commit the Markdown changes with the related code and a changelog entry. Procedures and decisions remain in the linked docs and ADRs.

## Testing

The test runner and CLI coverage script use Swift Package Manager and do not require the Xcode IDE:

```sh
swift run run-tests
bash scripts/test-coverage.sh
```

GitHub Actions runs only when a release tag (`v*`) is pushed; ordinary branch pushes and pull requests do not start workflows. The release workflow runs release-tooling checks and the full deterministic suite (`swift run run-tests`) before packaging. Run the suite locally during development, or use `swift run run-tests --unit` for a lightweight, model-free check. Coverage instrumentation, CLI coverage, model evaluations, and UI checks remain opt-in.

For the sequential model-backed fixture pipeline, run `bash scripts/run-evals.sh --pipeline`. Run every stage evaluation with `bash scripts/run-evals.sh --suites`; validate saved outputs without inference using `bash scripts/run-evals.sh --validate-run <run-stamp>`. Review generated files against `eval/*/expected/` and the matching stage skill; dated results and semantic findings are recorded in [testing verification history](./docs/testing-verification.md#dated-verification-evidence). For native macOS UI checks, use `bash scripts/test-ui.sh eval`; it builds a temporary app bundle and isolates config/data under a temporary directory. Prepared-machine model checks use `scripts/test-model-smoke.sh` with the four `CAPTAINSLOG_*_MODEL_*` environment variables set. Actual microphone capture is a separately confirmed, interactive check via `scripts/test-recorder-hardware.sh`. Neither smoke check runs in GitHub Actions. See [testing gates and isolation](./docs/testing.md) for fixture and hardware constraints.

## Changelog and releases

Update [CHANGELOG.md](./CHANGELOG.md) under `Unreleased` in the same commit as
any repository change, including documentation, fixtures, and tooling. Use
`Added`, `Changed`, `Fixed`, `Removed`, or `Security` as appropriate; describe
what actually changed. Review `git diff` and `git log` against the latest release
tag. Use `swift scripts/release.swift check <base-commit> <head-commit>` locally
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
backlog tasks](./backlog/tasks/) for remaining manual checks and
[publication procedures](./docs/PUBLISHING-PLAN.md) for review details.

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

Release-tooling tests use Swift, Bash, and Git:

```sh
bash scripts/test-release-tooling.sh
swift scripts/release.swift notes 0.1.2
swift scripts/release.swift check <base-commit> <head-commit>
```

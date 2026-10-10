# Development commands

Run Make from the repository root. It drives the development workflows; the
scripts in this directory are necessary implementation helpers. Apple Command
Line Tools include Make, Swift and the other macOS build tools; Xcode IDE is not
required. `make help` lists available targets.

| Command | Purpose / options |
|---|---|
| `make dev` / `make` / `make run` | Launch the cached debug app directly with its persistent isolated demo copy, skipping SwiftPM when sources and package manifests are unchanged. Missing apps or changed inputs trigger an app-only incremental build first. No packaging, tests or evaluations run; the first build takes longer. |
| `make build` | Build Swift package products; `CONFIGURATION=release` selects release (default: debug). |
| `make cli ARGS='search "project architecture"'` | Run a CLI command. Normal CLI usage uses your configured data; checks must supply isolated config/data and eval fixtures. |
| `make tests` | Run the deterministic framework-free suite with temporary config/data. `ARGS=--unit` or `make tests-unit` selects model-free unit checks. |
| `make evals` | Run the full audio pipeline then all stage suites, sequentially. `MODE=pipeline` / `MODE=suites` selects one; `STAGE=filename CASE="fixture stem"` selects focused cases. |
| `make packaging` | Build the release app and CLI, bundle native libraries and notices, sign ad hoc, and create `dist/CaptainsLog-VERSION.zip`. |
| `make release` | Infer version from Conventional Commits and prepare a local release on clean main. `BUMP=patch`, `minor`, `major` or an explicit version overrides `auto`; `ARGS=--dry-run` previews and `ARGS=--publish` publishes. See the [release checklist](../README.md#changelog-and-releases). |

Additional flags use `ARGS="..."`, passed to the underlying command. Quote paths
and stems with spaces inside ARGS as shell arguments. Existing `CAPTAINS_LOG_EVAL_*`
model/run-directory environment overrides continue to work. Packaging always
builds release and development launch always uses debug, regardless of
`CONFIGURATION`. Release preparation runs only Git/version/changelog checks and
creates the release commit and tag. It does not build or run tests. The tag
workflow builds the release app and CLI, verifies packaging, and publishes the
archive and casks. Run development tests explicitly before releasing; model
evaluations remain a separate `make evals` command.

| Supporting command | Purpose / options |
|---|---|
| `make evals-list` | List synthetic fixtures without loading models; accepts `STAGE` / `CASE`. |
| `make evals-pipeline` / `make evals-suites` | Run the audio pipeline or all stage suites. |
| `make evals ARGS="--validate-run RUN_DIR"` | Validate saved outputs without inference; `--baseline RUN_DIR` assembles comparison evidence. |
| `make tests-coverage` | LLVM-instrumented deterministic and fixture CLI coverage; enforce production coverage floor. |
| `make tests-updates` | Exercise simulated Homebrew updates using fake Homebrew fixtures. |
| `make tests-release` | Model-free release/changelog fixtures and temporary local Git publication. |
| `make tests-runtime` | Verify the pinned native archive twice and compare clean unsigned runtime artifacts and matching headers. |
| `make tests-evals` | Model-free evaluation orchestration fixtures. |
| `make tests-enrich` | Build, then check enrichment validation and CLI seed boundaries without inference. |
| `make tests-model` | Opt-in installed-model smoke test; requires the four `CAPTAINSLOG_*_MODEL_*` variables in its helper. |
| `make tests-recorder` | Interactive microphone smoke check with explicit confirmation. |
| `make ui` | Launch temporary eval-backed native UI; optional state selector via `ARGS`. Use `eval-menu`, `eval-menu-recording`, `eval-menu-processing`, or `eval-menu-failed` to inspect the shared menu panel in a labeled synthetic preview window. |
| `make release-notes VERSION=0.1.2` | Extract release notes. |
| `make release-check BASE=<commit> HEAD=<commit>` | Validate changelog coverage (HEAD defaults to HEAD). |
| `make release-cask VERSION=0.1.2 SHA256=<hash>` | Update Homebrew cask metadata. |
| `make icons` | Regenerate the committed icon using the Swift renderer, `sips` and `iconutil`. |
| `make clean` | Clean Swift package build products. |

Make keeps targets sequential even with `-j`; separate invocations still must not
run model jobs concurrently. Evaluations use only repository `eval/` fixtures and
isolated config/data. The UI harness is for presentation inspection; its processing
and recording controls invoke real models or hardware. Checks bypass default demo
seeding. See the [testing workflow](../README.md#testing) and stage skills in
[`skills/`](../skills/) for quality gates and semantic review requirements.

## Implementation map

Start with [Makefile](../Makefile) for command invocation. Most `scripts/*.swift`
entrypoints delegate through [tooling.swift](tooling.swift) to the dispatch table
in [Main.swift](Sources/Tools/Main.swift); find the implementation below rather
than guessing a filename from a Make target.

| Workflow | Implementation |
|---|---|
| Packaging, framework bundling, runtime verification | [Native.swift](Sources/Tools/Native.swift) |
| UI harness, updater/model/recorder checks, pipeline artifact checks | [Checks.swift](Sources/Tools/Checks.swift) |
| Evaluation selection, generation and review bundles | [Evals.swift](Sources/Tools/Evals.swift) |
| Evaluation tooling fixtures and enrichment validation | [EvalChecks.swift](Sources/Tools/EvalChecks.swift), [EnrichValidation.swift](Sources/Tools/EnrichValidation.swift) |
| Coverage | [Coverage.swift](Sources/Tools/Coverage.swift) |
| Release preparation, notes, changelog checks and cask updates | [release.swift](release.swift); release fixtures: [ReleaseChecks.swift](Sources/Tools/ReleaseChecks.swift) |
| Temporary config/data, subprocesses and file helpers | [Common.swift](Sources/Tools/Common.swift); `isolated-check` dispatch: [Main.swift](Sources/Tools/Main.swift) |

Before full tests, coverage or updater checks, quit the app
when recording and processing have finished. Updater fixtures still inspect the
real app process. Run checks from the repository root so relative `eval/` fixture
paths resolve correctly. See [testing prerequisites](../README.md#testing).

All helper implementations are Swift. A separate pinned Swift package in this
directory compiles shared tooling; it is not a dependency of the app package.
The package uses Yams for YAML validation. The first helper invocation resolves
its pinned dependency and builds the tool; subsequent invocations reuse its cache.

Helpers stay in `scripts/`: packaging (`build-app.swift`), release (`release.swift`),
evaluation orchestration and validation (`run-evals.swift`, `evals.swift`,
`eval-pipeline.swift`), icons (`make-iconset.swift`,
`make-icon.swift`), and the `test-*` checks. `isolated-check.swift` gives checks
throwaway configuration/data and removes it afterward. Call Make for these
workflows instead of treating the helpers as a separate command interface.

Direct helper usage is `swift scripts/NAME.swift [arguments]` or the executable
`./scripts/NAME.swift`. Former `.sh` and `.rb` filenames remain executable
symlinks to Swift entrypoints for path compatibility; invoke them directly,
not through Bash or Ruby. Existing Make targets and arguments are unchanged.
For example, `swift scripts/run-evals.swift --stage filename --list` lists
fixtures without loading a model.

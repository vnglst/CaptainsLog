# Development commands

Run Make from the repository root. It drives the development workflows; the
scripts in this directory are necessary implementation helpers. Apple Command
Line Tools include Make, Swift and the other macOS build tools; Xcode IDE is not
required. `make help` lists available targets.

| Command | Purpose / options |
|---|---|
| `make` / `make run` | Start the app in debug development mode, with its persistent isolated demo copy. |
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
`CONFIGURATION`; release checks use debug defaults.

| Supporting command | Purpose / options |
|---|---|
| `make evals-list` | List synthetic fixtures without loading models; accepts `STAGE` / `CASE`. |
| `make evals-pipeline` / `make evals-suites` | Run the audio pipeline or all stage suites. |
| `make evals ARGS="--validate-run RUN_DIR"` | Validate saved outputs without inference; `--baseline RUN_DIR` assembles comparison evidence. |
| `make tests-coverage` | LLVM-instrumented deterministic and fixture CLI coverage; enforce production coverage floor. |
| `make tests-updates` | Exercise simulated Homebrew updates using fake Homebrew fixtures. |
| `make tests-release` | Model-free release/changelog fixtures and temporary local Git publication. |
| `make tests-evals` | Model-free evaluation orchestration fixtures. |
| `make tests-enrich` | Build, then check enrichment validation and CLI seed boundaries without inference. |
| `make tests-model` | Opt-in installed-model smoke test; requires the four `CAPTAINSLOG_*_MODEL_*` variables in its helper. |
| `make tests-recorder` | Interactive microphone smoke check with explicit confirmation. |
| `make ui` | Launch temporary eval-backed native UI; optional state selector via `ARGS`. |
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

Helpers stay in `scripts/`: packaging (`build-app.sh`), release (`release.swift`),
evaluation orchestration and validation (`run-evals.sh`, `evals.rb`,
`eval-pipeline.sh`), icons (`make-iconset.sh`,
`make-icon.swift`), and the `test-*` checks. `isolated-check.sh` gives checks
throwaway configuration/data and removes it afterward. Call Make for these
workflows instead of treating the helpers as a separate command interface.

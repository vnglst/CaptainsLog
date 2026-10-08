# Repository scripts

These scripts support source builds, release packaging, and checks that need more
than the framework-free `swift run run-tests` runner. They use command-line tools;
the Xcode IDE is not required. Run commands from the repository root.

| Script | Purpose / when to use |
|---|---|
| `release.swift` | Infer a version bump from Conventional Commits (or use an explicit override), prepare a dated changelog, release checks, commit and tag; also validate Git change coverage, extract notes, and update cask metadata; `--dry-run` previews and `--publish` pushes main/tag atomically. See the [release checklist](../README.md#changelog-and-releases). |
| `test-release-tooling.sh` | Model-free release/changelog tests using synthetic notes and temporary local Git repositories. |
| `build-app.sh` | Build the release app and CLI, bundle runtime libraries and notices, sign ad hoc, and create the versioned ZIP. Used by release CI. |
| `make-iconset.sh` | Regenerate the committed `Resources/AppIcon.icns` after changing the icon design. Requires macOS `sips` and `iconutil`. |
| `make-icon.swift` | AppKit icon renderer called by `make-iconset.sh`; also accepts a PNG output path for previews. |
| `test-coverage.sh` | Run deterministic tests and fixture CLI checks with LLVM instrumentation; enforce the production coverage floor. |
| `test-updates.sh` | Exercise update checks, simulated installation, failures, and config preferences against the fake Homebrew fixture. Keeps logs under `tmp/`; does not update the installed app. |
| `test-evals.rb` | Model-free regression checks for evaluation selection, malformed output rejection, evidence and failure propagation. Run with `ruby scripts/test-evals.rb`. |
| `run-evals.sh` | Single evaluation entry point: pipeline (`--pipeline`), all suites (`--suites`), or focused `--stage STAGE [--case STEM]`; `--list`, saved validation and optional baselines. See [workflow](../docs/EVALUATIONS.md). `evals.rb` and `eval-pipeline.sh` implement it internally. |
| `validate-eval-run.sh` | Compatibility wrapper for saved stage-output validation without inference. Use `run-evals.sh --validate-run <run-stamp>` or `--validate-categorize <run-stamp>`. |
| `test-ui.sh` | Launch a temporary macOS app with isolated eval-backed presentation state. Defaults to `eval`; accepts the state selectors listed in the script. Close the app before deleting its printed temporary root. |
| `test-model-smoke.sh` | Opt-in loading/warmup of installed Qwen and transcription of an eval fixture. Requires all four `CAPTAINSLOG_*_MODEL_*` environment variables listed in the script. |
| `test-recorder-hardware.sh` | Interactive microphone smoke check with explicit confirmation; records three seconds into temporary storage. |

Model evaluations and model smoke checks must run sequentially. Use repository
`eval/` fixtures and isolated config/data for checks. The UI harness is for
presentation inspection; processing and recording controls invoke real models or
hardware. See [ADR-007](../docs/0007-framework-free-test-coverage.md) for test
gates, limitations, and semantic review requirements, and the stage workflows in
[`skills/`](../skills/) for output review.

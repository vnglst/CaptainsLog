# Contributing to CaptainsLog

Start with [README.md](README.md) for what the app does and [AGENTS.md](AGENTS.md)
for repository rules. Small, focused changes are easiest to review.

## Build and run

You need **Apple Silicon, macOS 26+, Swift 6.2+ and Apple Command Line Tools**.
Xcode IDE and Homebrew inference libraries aren’t required. The first build needs
internet access for dependencies.

```sh
make dev         # Build and launch an isolated demo with synthetic fixtures
make build       # Build the app, CLI and test executables
make packaging   # Create dist/CaptainsLog.app and a versioned ZIP
```

The demo retains edits between launches in `tmp/demo-runtime-eval/`. Quit and move
that directory aside to reset it. Recording controls use your real microphone;
processing uses real models. Use `make ui` for simulated UI states.

Run `make help` for commands and options, or see the [command guide](scripts/README.md).

## Test your change

Run commands from the repository root. Quit CaptainsLog after recording and
processing finish before running the full tests: updater checks detect the real app.

```sh
make tests-unit       # Quick, model-free unit checks
make tests            # Full deterministic suite, including processing coordination
make evals-pipeline   # Real audio-to-note evaluation using a repository fixture
```

For dependency upgrades, new features or significant refactors, run `make build`,
`make tests` and `make evals-pipeline`. Run model jobs sequentially and review the
generated text for missing or invented content.

Use only repository `eval/` fixtures. For CLI or app checks, set
`CAPTAINS_LOG_CONFIG_PATH` to an isolated temporary config and data directory;
this also bypasses demo seeding. Keep personal recordings and notes out of checks.

## Submit a change

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/), such as
`fix(search): respect category filters`. Add a concise entry under **Unreleased**
in [CHANGELOG.md](CHANGELOG.md).

In your PR, explain the change, how to review it and which checks passed. Include
a short video for UI changes, or sample output for CLI changes, using synthetic data.

## Releases

From clean `main`, preview with `make release ARGS=--dry-run`. After reviewing the
changelog and completing relevant checks, `make release` prepares a local commit
and tag; `make release ARGS=--publish` also publishes.

Release preparation does not build or test. Pushing the tag triggers the release
build and publication workflow; ordinary pushes and PRs do not run CI.
Follow the [release checklist](agent-guides/releases.md) when publishing.

## Agent references

Read the relevant guide for detailed procedures:

- [Development, demos, testing and troubleshooting](agent-guides/development.md)
- [Native runtime provenance and upgrades](agent-guides/runtime.md)
- [Fixture evaluations and listening reviews](agent-guides/evaluations.md)
- [Release preparation and publication](agent-guides/releases.md)
- [App behavior and CLI details](agent-guides/app-behavior.md)

[Architecture decisions](docs), [backlog](backlog/tasks), [evaluation fixtures](eval/README.md)
and [source navigation](AGENTS.md#repository-navigation) provide further context.

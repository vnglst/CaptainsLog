# Repository Instructions

Read `README.md` for product requirements and [CONTRIBUTING.md](CONTRIBUTING.md) for build, testing and release instructions before working here. Use the [repository navigation map](#repository-navigation) to find source entry points and the [tool implementation map](scripts/README.md#implementation-map) for development helpers.

## Agent references

Read these when the work touches their subject; CONTRIBUTING.md is the human quick start.

| Work | Reference |
|---|---|
| Build dependencies or native runtime upgrades | [Runtime provenance and upgrade checks](agent-guides/runtime.md) |
| Demo setup, test selection or processing failures | [Development and verification](agent-guides/development.md) |
| Model evaluations, baselines or listening review | [Fixture evaluations](agent-guides/evaluations.md) and the relevant stage skill |
| Preparing or publishing a release | [Release checklist](agent-guides/releases.md) |
| App behavior, updates or CLI configuration | [App reference](agent-guides/app-behavior.md) |

## Repository navigation

For development commands, start with `make help` and [the command guide](scripts/README.md).
For code changes, use the entry points below.

| Area | Start here |
|---|---|
| App launch and demo setup | [AppMain.swift](Sources/CaptainsLogApp/AppMain.swift), [DemoMode.swift](Sources/CaptainsLogApp/DemoMode.swift) |
| Logs UI and Settings | [FieldNotesContentView.swift](Sources/CaptainsLog/FieldNotesContentView.swift); spelling editor: [FieldNotesCorrectionsEditor.swift](Sources/CaptainsLog/FieldNotesCorrectionsEditor.swift) |
| App processing and audio discovery | [ProcessingCoordinator.swift](Sources/CaptainsLog/ProcessingCoordinator.swift), [DirectoryWatcher.swift](Sources/CaptainsLog/DirectoryWatcher.swift), [Pipeline.swift](Sources/CaptainsLogCore/Pipeline.swift) |
| Pipeline stages and native inference | [CaptainsLogCore](Sources/CaptainsLogCore): `Transcriber.swift`, `Cleanup.swift`, `Categorize.swift`, `Filename.swift`, `Enrich.swift`, `LLM.swift` |
| Prompts and prompt loading | [Resources/prompts/](Resources/prompts), [PromptLoader.swift](Sources/CaptainsLogCore/PromptLoader.swift), [PromptResolver.swift](Sources/CaptainsLogCore/PromptResolver.swift) |
| Configuration and corrections | [Config.swift](Sources/CaptainsLogCore/Config.swift), [ConfigManager.swift](Sources/CaptainsLog/ConfigManager.swift), [CorrectionDocument.swift](Sources/CaptainsLog/CorrectionDocument.swift) |
| CLI commands and evaluation batches | [CL.swift](Sources/cl/CL.swift), [EvalBatch.swift](Sources/cl/EvalBatch.swift) |
| Updates | [AppUpdater.swift](Sources/CaptainsLogCore/AppUpdater.swift), [UpdateManager.swift](Sources/CaptainsLog/UpdateManager.swift) |
| Native UI previews | [DesignFixtures.swift](Sources/CaptainsLog/Previews/DesignFixtures.swift) |
| Tests and synthetic fixtures | [CaptainsLogTests/main.swift](Tests/CaptainsLogTests/main.swift), [eval/](eval), [stage review skills](eval/skills) |
| Build, packaging, runtime checks and releases | [Tool implementation map](scripts/README.md#implementation-map), [Package.swift](Package.swift), [release workflow](.github/workflows/release.yml) |

Use `rg --files Sources Tests Packages scripts eval/tools` to locate files before reading them. CLI command
types share `CL.swift`, tests share `Tests/CaptainsLogTests/main.swift`, and tooling entrypoint
names do not necessarily match their implementation filenames. Current commands
live in CONTRIBUTING.md and the command guide; native runtime details live in
[the runtime reference](agent-guides/runtime.md). ADRs preserve dated decisions
and may describe older implementation details.

## Backlog

- Keep one task per coherent outcome. Put research, implementation and verification phases inside it; split only independently useful outcomes. When consolidating, preserve scope and findings, redirect dependencies and archive superseded tasks without marking their implementation complete.
- ALL task content must come from the owner. Agents may organize or lightly edit owner-provided sentences while preserving the owner’s wording and keeping text very short, but must never originate task content, including descriptions, scope, requirements, acceptance criteria, dependencies, plans, implementation notes, findings, review notes or final summaries. Ask the owner for missing content. Implementation and backlog refinement do not authorize agents to add their own prose. Create tasks or drafts only when explicitly requested, using the owner's supplied content. Agents may check off existing items after verifying them and update workflow status as authorized below. Report evidence, bugs and suggestions in chat or PRs, without adding them to tasks. This rule overrides conflicting README, skill and Backlog.md CLI guidance. Small, mechanical changes may be completed without creating a task.
- `backlog/tasks/` is the single backlog. Use the Backlog.md CLI (`backlog task list`, `backlog task view`, `backlog task create`, `backlog task edit`) for task changes; the files remain ordinary Markdown in Git. Read `backlog instructions overview` for its CLI workflow. Install the CLI separately with `brew install backlog-md` if needed. Do not add it to the Swift package or use its optional web/MCP integration.
- The columns are `To Do` (unselected work), `Next` (owner-selected work agents may pick up), `Verify` (implementation finished, awaiting owner review), and `Complete` (owner-verified and ready for release). At the start of project work, list `Next` tasks and read the chosen task. Do not pull work from `To Do` on your own; a direct user request may move its task to `Next` first.
- Keep task text very short and use the owner’s sentences and wording. Do not expand it with additional explanation. Acceptance criteria must not repeat the description; omit them when the owner has not supplied distinct checks. Do not link to repository files or put file paths in reference/documentation fields, because those files are not visible in the Backlog app. Preserve owner-supplied scope, dependencies, status and checked criteria when condensing existing tasks.
- Keep a task in `Next` while implementing. After relevant checks, check off supported existing acceptance criteria and move it to `Verify`, without adding agent-authored plans, notes or summaries. Leave `Complete` for the owner's verification or an explicit user instruction. If the owner requests changes, return the task to `Next`; any review-note content must come from the owner. Keep authorized backlog changes with the related code and changelog in the same commit.
- When the owner requests a new backlog item, use a draft for an idea that is not yet agreed work and a `To Do` task for agreed work. Include only content supplied by the owner; ask for missing input. Explain the supplied content without linking to other files. Keep the active task focused; report newly discovered work without silently expanding scope or adding backlog items.

Backlog CLI reference:

```sh
backlog board                         # Review work by status
backlog task list                     # List tasks
backlog task view TASK-1              # Read a task
backlog draft create "Possible idea"  # Capture an idea not yet agreed as work
backlog draft promote DRAFT-1         # Promote an agreed idea to a task
backlog task create "Task title"      # Create an agreed task
backlog task edit TASK-1 --status "Next"    # Select it for implementation
backlog task edit TASK-1 --status "Verify"  # After checking existing criteria
backlog task edit TASK-1 --status "Complete"  # After your review
```

## Development

- Use Conventional Commits for every new commit: `type(scope): description`, with an optional scope. Use `feat` for features, `fix` for fixes, `perf` for performance improvements, and `!` or a `BREAKING CHANGE:` footer for breaking changes. Documentation, tests, CI, refactors, and maintenance use their matching types. Do not rewrite older history to retrofit the convention.
- Think through assumptions before changing code. Prefer the smallest change that solves the request; avoid unrelated refactors.
- Keep the CLI usable without Xcode. Use Swift and command-line tools for builds and tests.
- Test code changes with the affected CLI command and a repository fixture. Reproduce pipeline issues in the CLI before debugging through the UI.
- After dependency upgrades, new features, or significant refactors, run `make build`, `make tests`, and `make evals-pipeline` on a fixture. Evaluation suites are the quality gate; run them sequentially. For a quick LLM smoke check, run `make evals STAGE=filename`.
- Never run multiple inference tasks in parallel. WhisperKit and llama.cpp share limited on-device GPU memory. Load Qwen once per pipeline run and reuse it across stages.

## Efficient execution

- Read repository guidance once per session; revisit only changed or relevant sections. Use the navigation maps and bounded searches instead of dumping whole files, histories or logs. Redirect long command output to a log and return failures plus the final summary.
- Before running checks, confirm which suite exercises the changed path. `make tests-unit` excludes coordinator coverage; processing and queue regressions require `make tests`. Reproduce the reported stage and action sequence, add a failing regression, then fix it. A transcript-seeded continuation does not verify a Transcribing bug.
- Complete related edits before expensive verification. Reuse passing checks for unchanged inputs; repeat when code, dependencies, settings or fixtures affecting that check change. Preserve required quality gates and semantic review. Confirm dependency versions before starting expensive runtime evaluations.
- When parallel agents are authorized, give each a bounded outcome and request only its commit, changed files, checks, evidence paths and blockers. Designate one owner for builds and native inference. Keep independent worktree build directories; do not symlink or concurrently mutate SwiftPM scratch paths. Reuse a working build configuration within its checkout rather than repeatedly resolving or cleaning dependencies.
- Keep one compact execution checkpoint under ignored `tmp/`: revision/dirty state, commands and build configuration, active jobs, completed checks, evidence paths and next action. Resume from it after interruptions; verify relevant inputs before reusing evidence. Keep observations in the evidence files instead of repeatedly copying them into chat.
- Check UI access before starting a recording run. If the Mac is locked or access is denied, report the blocker once and continue independent work; retry after access changes. After an unexpected UI action, refresh state and exclude invalid runs before continuing.
- Distinguish built, tested, recorded and installed in completion reports. A successful package build does not establish that `/Applications/CaptainsLog.app` was replaced; verify the installed bundle against the tested artifact when installation is requested.

## Privacy

- Never read, copy, or use personal recordings or data from `processed/`, Obsidian, or CaptainsLog data folders for tests, evaluations, reproductions, or debugging.
- Use only repository fixtures under `eval/`, including `eval/suites/transcribe/audio/` for audio tests. Treat evaluation inputs as synthetic fixtures; do not replace them with personal recordings.
- Set `CAPTAINS_LOG_CONFIG_PATH` to an isolated temporary config and data directory for CLI/app checks. Bypass default demo seeding; hard-coded design examples are presentation material, not evaluation inputs.

## Mock, test, evaluation and demo data

- Create all mock, test, evaluation and demo content with a Star Trek: The Next Generation theme, grounded in real episodes about language and communication, such as Darmok. Write personal logs from an Enterprise engineer who was there during the Darmok encounter; keep invented crew-level details consistent with the episode.
- Preserve existing recordings and their matching scripts, transcripts and evaluation references. Update unrecorded scripts and their expected outputs together.

## Evaluations

Stage-specific evaluation workflows live in `eval/skills/<stage>-eval/SKILL.md` for transcription, cleanup, filename, and enrichment. Use the relevant workflow when evaluating output. Reports should describe concrete changes and semantic impact, including missing or added content and hallucinations; scores alone are not enough. Human review makes the final quality judgment.

- Report dated evaluation results, semantic findings and limitations in chat or PRs, without adding agent-authored content to tasks.

### Semantic review

Read each selected case’s input, expected output, generated output and validation
in the printed review bundle. Fill its preserved report with concrete omissions,
changed meaning, added or hallucinated content, baseline improvements/regressions,
stage observations and remaining limits. Explain why each difference matters.
Metadata records model/runtime identity, source/prompt/fixture hashes, settings,
revision and timings; validation success cannot prove grounding or completeness.
Expected wording is a reference rather than the only valid wording. Baseline diffs
and heuristic scores help navigation but do not replace human review. Report dated
findings in chat or PRs. Do not claim speed
or token savings without measurements and comparable timing scopes.

## Documentation

- Minimize PR review effort and text. State the change, give one quick review action or tip, and summarize checks and material limits. Keep detailed evidence in optional expandable PR sections, not agent-authored task notes. Proactively include a short video for UI changes, or a concise example, screenshot or sample output suited to other changes. Use synthetic fixtures and isolated data for media. Never imply an unperformed check or recording. Help the owner assess behavior without reconstructing it from code or logs.
- Keep `CHANGELOG.md` and release notes concise: describe meaningful changes under `Unreleased`, combining related work instead of listing every commit. Keep backlog updates, agent-policy and ADR bookkeeping, and planned work out of both. Backlog-only commits do not need a changelog entry; other changes still require coverage in the same commit. Review `git status`, `git diff`, and `git log` so nothing is missed. Backfill using release tags as boundaries; do not invent earlier history.
- Prepare releases with `make release BUMP=auto|patch|minor|major|version` (preview with `ARGS=--dry-run`, push with `ARGS=--publish`). By default it infers the highest bump from commits after the latest reachable release tag: fix/perf → patch, feat → minor, breaking → major (minor for 0.x); maintenance-only commits do not trigger a release. Manual overrides remain available. It updates `VERSION`, dates and moves Unreleased entries, updates Git comparison links, runs sequential release checks, and creates a commit and tag. Record archive/cask publication in each release; generated cask-only version/checksum commits are covered by that entry. Follow the [release checklist](agent-guides/releases.md#changelog-and-releases) and review evaluation semantics before publishing.
- Existing ADRs are immutable. Never edit, shorten, rename, delete or change the status or date of an existing record. Document changes in a new numbered ADR that links to the record it supersedes; leave the original untouched. ALL content for a new ADR must come from the owner, including decisions, context, rationale, alternatives and consequences. Agents may edit or rewrite owner-supplied wording for the new record but must never originate ADR content. Create an ADR, including a superseding record, only when the owner explicitly requests it and supplies its content; ask for anything missing. Read relevant ADRs before architectural changes. For an authorized new ADR, use `adrs` and keep it within 300 words (up to 500 for essential owner-supplied rationale). This rule overrides conflicting architecture-documentation guidance.
- Keep `docs/` exclusively for numbered ADRs, with no plans, reports, guides or subfolders. Use the CLI for authorized owner-supplied task content, status changes and checking existing items. Keep synthetic reference data under `eval/fixtures/`, separate from active suites when unused.
- Keep current commands and isolation rules in CONTRIBUTING.md, the linked agent guides and the existing script/skill instructions. Report evaluation evidence, native UI limits and legacy-code review in chat or PRs; do not add them to tasks or ADRs yourself. Do not add new evidence to ADR-007. Check downstream SwiftPM clients, previews, debug flags and resource dependencies before deleting apparently unused public symbols or vendored headers.

## Architecture decision tools

From the repository root, install the separate
[`adrs` CLI](https://joshrotenberg.com/adrs/) with `brew install adrs`, then use:

```sh
adrs list                       # Browse existing decisions
adrs search "inference"         # Find decisions by subject
adrs new --no-edit "Decision title"
adrs doctor                     # Check numbering and links
```

Read each file for its status; `adrs list -l` does not parse every legacy
status line correctly.

## Native UI investigation

The active UI and Settings are embedded in FieldNotesContentView; the launcher is
AppMain. Core stage implementations and the sequential inference gate live in
CaptainsLogCore, while command types live in cl. Framework-free tests are in the
run-tests executable. For isolated native UI inspection use the existing UI harness;
packaged development executables must be launched directly to inherit their isolated
configuration. Record the bundle revision, dirty state, signatures and binary checksums
when comparing builds. A rollback restores binaries/resources, not data migrations.

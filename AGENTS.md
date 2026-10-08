# Repository Instructions

Read `README.md` before working here. Follow its product requirements, build instructions, and design decisions.

## Backlog

- The owner controls task creation. Agents may create tasks or drafts only when the owner asks for them or to track work directly requested by the owner. Do not create tasks or drafts on your own for discovered bugs, follow-up ideas, cleanup, or suggested improvements; mention those findings to the owner and wait for a request. General Backlog.md CLI guidance to create tasks does not override this rule. Small, mechanical changes may be completed without creating a task.
- `backlog/tasks/` is the single backlog. Use the Backlog.md CLI (`backlog task list`, `backlog task view`, `backlog task create`, `backlog task edit`) for task changes; the files remain ordinary Markdown in Git. Read `backlog instructions overview` for its CLI workflow. Install the CLI separately with `brew install backlog-md` if needed. Do not add it to the Swift package or use its optional web/MCP integration.
- The columns are `To Do` (unselected work), `Next` (owner-selected work agents may pick up), `Verify` (implementation finished, awaiting owner review), and `Complete` (owner-verified and ready for release). At the start of project work, list `Next` tasks and read the chosen task. Do not pull work from `To Do` on your own; a direct user request may move its task to `Next` first.
- Keep a task in `Next` while implementing. Record the current plan and concise findings with `backlog task edit TASK-N --plan "..."` and `--append-notes "..."`. After relevant checks, check supported acceptance criteria, add `--final-summary "..."`, and move it to `Verify`. Leave `Complete` for the owner's verification or an explicit user instruction. If the owner requests changes, return the task to `Next` with review notes. Keep backlog changes with the related code and changelog in the same commit.
- When the owner requests a new backlog item, use a draft for an idea that is not yet agreed work and a `To Do` task for agreed work. Add acceptance criteria, dependencies and links only where they clarify scope or handoff. Keep the active task focused; report newly discovered work without silently expanding scope or adding backlog items. Preserve durable architecture decisions in ADRs and evaluation evidence in their existing documents.

## Development

- Use Conventional Commits for every new commit: `type(scope): description`, with an optional scope. Use `feat` for features, `fix` for fixes, `perf` for performance improvements, and `!` or a `BREAKING CHANGE:` footer for breaking changes. Documentation, tests, CI, refactors, and maintenance use their matching types. Do not rewrite older history to retrofit the convention.
- Think through assumptions before changing code. Prefer the smallest change that solves the request; avoid unrelated refactors.
- Keep the CLI usable without Xcode. Use Swift and command-line tools for builds and tests.
- Test code changes with the affected CLI command and a repository fixture. Reproduce pipeline issues in the CLI before debugging through the UI.
- After dependency upgrades, new features, or significant refactors, run `swift build`, `swift run run-tests`, and the full pipeline on a fixture. Evaluation suites are the quality gate; run them sequentially. For a quick LLM smoke check, run `filename-eval`.
- Never run multiple inference tasks in parallel. WhisperKit and llama.cpp share limited on-device GPU memory. Load Qwen once per pipeline run and reuse it across stages.

## Privacy

- Never read, copy, or use personal recordings or data from `processed/`, Obsidian, or CaptainsLog data folders for tests, evaluations, reproductions, or debugging.
- Use only repository fixtures under `eval/`, including `eval/transcribe/audio/` for audio tests. Treat evaluation inputs as synthetic fixtures; do not replace them with personal recordings.
- Set `CAPTAINS_LOG_CONFIG_PATH` to an isolated temporary config and data directory for CLI/app checks. Bypass default demo seeding; `demo/` and hard-coded design examples are presentation material, not evaluation inputs.

## Evaluations

Stage-specific evaluation workflows live in `skills/<stage>-eval/SKILL.md` for transcription, cleanup, filename, and enrichment. Use the relevant workflow when evaluating output. Reports should describe concrete changes and semantic impact, including missing or added content and hallucinations; scores alone are not enough. Human review makes the final quality judgment.

## Documentation

- Update `CHANGELOG.md` in the same commit as every change, including code, prompts, dependencies, fixtures, tests, documentation, and tooling. Describe concrete changes under `Unreleased`; keep planned work in the backlog. Review `git status`, `git diff`, and `git log` so nothing is missed. Backfill using release tags as boundaries; do not invent earlier history.
- Prepare releases with `swift scripts/release.swift [auto|patch|minor|major|version]` (preview with `--dry-run`, push with `--publish`). By default it infers the highest bump from commits after the latest reachable release tag: fix/perf → patch, feat → minor, breaking → major (minor for 0.x); maintenance-only commits do not trigger a release. Manual overrides remain available. It updates `VERSION`, dates and moves Unreleased entries, updates Git comparison links, runs sequential release checks, and creates a commit and tag. Record archive/cask publication in each release; generated cask-only version/checksum commits are covered by that entry. Follow the release checklist in `README.md` and review evaluation semantics before publishing.
- Follow the [architecture decision workflow](README.md#architecture-decisions): search and read relevant ADRs in `docs/` before architectural changes. Create a numbered ADR with `adrs` only for a significant, hard-to-reverse decision; remove empty template sections rather than inventing context or alternatives. Keep ADRs within 300 words (up to 500 only for essential rationale); link to procedures and dated evidence instead of embedding them. Editorial shortening must preserve the decision, date, and status. When a decision changes, create a new ADR that links to and supersedes the earlier record. Use Backlog.md for work tracking.
- Track unfinished work and completion status in `backlog/tasks/`. Separate detail files may hold procedures and acceptance criteria, but must link to the backlog rather than maintain independent task lists. Remove completed plans once their durable decisions and remaining acceptance checks are preserved, and update links to their replacement.
- Keep current testing gates and isolation rules in [the testing workflow](docs/testing.md), and append dated evaluation evidence, native UI limits, and legacy-code review to [verification history](docs/testing-verification.md). Keep ADR-007 focused on the test-runner decision. Check downstream SwiftPM clients, previews, debug flags and resource dependencies before deleting apparently unused public symbols or vendored headers.

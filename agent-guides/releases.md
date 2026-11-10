# Releases

Agent reference; read the relevant sections for the work at hand.
See [repository instructions](../AGENTS.md) for policy.

## Changelog and releases

[CHANGELOG.md](../CHANGELOG.md) records changes under `Unreleased` until a release is prepared.
Contribution rules are documented in [AGENTS.md](../AGENTS.md#documentation).

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
tasks](../backlog/tasks) for outstanding acceptance checks.

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
release. `HOMEBREW_TAP_TOKEN` must grant Contents read/write access to
`vnglst/homebrew-tap`. The release workflow publishes `Casks/captainslog.rb` there.
See [ADR-024](../docs/0024-separate-release-publication-from-development-checks.md)
for the release publication decision.

Release-tooling tests use Swift and Git:

```sh
make tests-release
make release-notes VERSION=0.1.2
make release-check BASE=<base-commit> HEAD=<head-commit>
```

# CaptainsLog: open work

Completed implementation history lives in the ADRs and Git history. This plan tracks remaining product and release work; testing evidence and acceptance gaps live in [ADR-007](ADR-007-framework-free-test-coverage.md).

## Logs interface

See [PLAN-004](PLAN-004-logs-implementation.md) for the current workspace and design references.

- [ ] Audio playback and seek controls for saved recordings.
- [ ] Collections/projects navigation after their data model and empty states are defined.
- [ ] Settings controls for categories and category setup in onboarding.
- [ ] Category filters in Logs.
- [ ] Copy the entire cleaned transcript from entry detail.
- [ ] Menu bar presence with start/stop recording controls.
- [ ] Complete native visual/interaction acceptance and clean-machine packaged-app checks.

## Evaluation fixtures and quality

- [ ] Record and populate the TNG evaluation corpus following [PLAN-002](PLAN-002-tng-eval-set.md); scripts and ground truth are prepared, but migration is still pending.
- [ ] Resolve meaning-changing transcription errors and rerun the transcription/full-pipeline evaluations.
- [ ] Complete the native, hardware, installed-model and search relevance checks listed in [ADR-007](ADR-007-framework-free-test-coverage.md#remaining-acceptance-work).

## Distribution and maintenance

The app/CLI bundle, public Homebrew tap and tag-driven release workflow are implemented. Keep release checks and unresolved publication reviews in [PUBLISHING-PLAN](PUBLISHING-PLAN.md).

- [ ] Landing page at `captainslog.koenvangilst.nl` with requirements and install steps.
- [ ] Clean-machine GUI/CLI install, first-launch model download, recording, processing and search checks, including the direct ZIP flow.
- [ ] Real published Homebrew upgrade and automatic relaunch QA; see [the update ADR](ADR-011-homebrew-auto-updates.md).
- [ ] Explore Developer ID signing and Mac App Store distribution.

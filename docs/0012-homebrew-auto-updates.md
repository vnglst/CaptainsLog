# ADR-012: Update the installed app through Homebrew

**Status**: Accepted

## Context

The installed app needs updates using the existing cask distribution, without
introducing another release feed, signing system, or runtime dependency.

## Decision

Use `vnglst/captainslog/captainslog` for updates. Check at launch and every 24
hours while open. Automatic installation defaults to enabled, waits until
recording, processing (including queued/reserved work), and model setup finish,
and prevents new work during installation. Homebrew verifies the cask checksum;
the app then launches its replacement and exits. Failures remain visible and
retry at most hourly; guard against duplicate restarts.

Persist check/install preferences in `CaptainsLogConfig`; absent values mean
enabled. Disabling checks also disables automatic installation. Settings offers
manual check, install, and restart controls with stable surrounding layout.
The CLI provides `cl update --check` and `cl update`, requiring the GUI to be
closed for installation.

Only the matching Homebrew-installed bundle auto-updates. Source runs, demos,
and UI fixtures do not.

Route this public tap's Git fetches through HTTPS using a temporary wrapper via
`HOMEBREW_GIT_PATH`: Homebrew filters environment-only Git rewrites. Preserve
other repositories' transport and persistent Git/SSH configuration; remove the
wrapper after each command.

## Consequences

Updates require supported Apple Silicon Homebrew and network metadata refresh.
No recordings or notes are sent. Ad-hoc signing and cask quarantine handling
remain unchanged. ZIP/source installations require manual updates or Homebrew
installation. Fixture checks cannot establish real published-upgrade and OS
relaunch behavior.

## Supporting documents

- [Fixture procedures](../eval/update/README.md)
- [Dated verification history](update-verification.md)
- [Open acceptance work](../backlog/tasks/)

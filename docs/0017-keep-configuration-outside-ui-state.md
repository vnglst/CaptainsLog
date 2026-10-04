# Keep configuration outside UI state

**Status**: Accepted

## Decision Outcome

Configuration belongs in `CaptainsLogConfig` and its config file, not UI state. Non-UI features must be usable and testable from the CLI.

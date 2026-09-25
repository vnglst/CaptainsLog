# ADR-011: Make Model Removal an Explicit Homebrew Zap

**Status**: Accepted  
**Date**: 2026-09-25

## Context

Downloaded language and speech models use several gigabytes. Users may want to reclaim that space when removing the app, but normal uninstall should preserve their app data. Some users may also keep models in custom locations.

## Decision

Use Homebrew’s opt-in `--zap` behavior to move only CaptainsLog-managed model directories under `~/Library/Application Support/CaptainsLog/models` and `~/Library/Caches/CaptainsLog/models` to the Trash. Leave logs, configuration, and models in user-selected external locations untouched. Document `brew uninstall --cask --zap captainslog` and that the user must empty the Trash to reclaim disk space.

## Consequences

- A normal cask uninstall preserves downloaded models and other user data.
- Users explicitly choose model cleanup with `--zap`.
- Managed model files are recoverable from the Trash until it is emptied.
- Custom model locations remain the user's responsibility.

## Verification

The public cask install, app launch, `cl ping`, and zap uninstall flow were exercised. The app and CLI were removed, managed model directories were moved to the Trash, and the Logs directory and configuration remained.

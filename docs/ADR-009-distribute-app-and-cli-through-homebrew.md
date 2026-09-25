# ADR-009: Distribute the GUI App and CLI Together Through Homebrew

**Status**: Accepted  
**Date**: 2026-09-25

## Context

CaptainsLog provides both a macOS GUI and the `cl` command-line interface. Users should be able to install either entry point in one step, without separately installing llama.cpp or runtime libraries. The source repository is named `CaptainsLog`, while Homebrew supports installing a cask from a tap with a qualified command.

## Decision

Package the GUI, `cl`, required resources, and llama.cpp runtime in one versioned app bundle archive. Publish a Homebrew cask in the source repository and mirror it to the separate `vnglst/homebrew-captainslog` tap. Document `brew install --cask vnglst/captainslog/captainslog` as the install command.

## Consequences

- One install provides the GUI app and a `cl` executable linked into the user's PATH.
- End users do not need Homebrew llama.cpp installed at runtime.
- The release archive and cask checksum must stay in sync.
- The separate tap allows the short qualified install command while preserving the source repository name.

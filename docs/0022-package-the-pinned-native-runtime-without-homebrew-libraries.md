# ADR-022: Package the pinned native runtime without Homebrew libraries

**Status**: Accepted
**Date**: 2026-10-10
**Supersedes**: [ADR-006](0006-bundle-llama-runtime-in-app.md)

## Context

The separate Homebrew llama, GGML and libomp dylib packaging in ADR-006 is obsolete.

## Decision

Use the checksum-pinned upstream llama XCFramework for development and release builds. Package its native runtime with the app; require no Homebrew inference libraries or separate libomp runtime. Packaging verifies bundled paths, deployment compatibility and signatures.

## Consequences

Runtime upgrades require an explicit artifact and checksum change. Current build and runtime verification commands live in the [README](../README.md#build).

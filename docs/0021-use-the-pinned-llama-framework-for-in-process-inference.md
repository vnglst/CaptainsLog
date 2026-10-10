# ADR-021: Use the pinned llama framework for in-process inference

**Status**: Accepted
**Date**: 2026-10-10
**Supersedes**: [ADR-005](0005-use-libllama-c-api-for-text-inference.md)

## Context

Homebrew headers and libraries described in ADR-005 no longer match the runtime integration.

## Decision

Retain in-process llama.cpp C API inference shared by the CLI and app, with serialized native state and prompt-controlled output. Resolve matching headers and native code through the checksum-pinned SwiftPM llama framework instead of a Homebrew system-library target. Local hybrid search continues to follow ADR-019.

## Consequences

Clean builds use the same native artifact. Follow the current runtime pin and upgrade procedure in the [README](../README.md#build).

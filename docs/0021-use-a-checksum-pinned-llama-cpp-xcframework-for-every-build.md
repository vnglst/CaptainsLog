# ADR-021: Use a checksum-pinned llama.cpp XCFramework for every build

**Status**: Accepted

**Date**: 2026-10-08

Supersedes the Homebrew dependency and separate-dylib packaging portions of
[ADR-005](0005-use-libllama-c-api-for-text-inference.md) and
[ADR-006](0006-bundle-llama-runtime-in-app.md).

## Context

Mutable Homebrew headers and runtime libraries let unrelated system upgrades
change or break builds from the same checkout. The owner requires the same pinned
native libraries for development and releases and permits verified prebuilt
artifacts.

## Decision

Use an upstream llama.cpp XCFramework as a SwiftPM binary target, pinned to an
immutable release URL and SHA-256 checksum. Its matching headers and merged
llama/GGML code are the only native inference dependency for every configuration.
The framework embeds Metal shaders, enables Accelerate and disables OpenMP;
there is no separately resolved libomp.

Package SwiftPM's resolved macOS framework in the app, retaining its relative
install name. Reject build-machine runtime paths instead of repairing Homebrew
references. Ship the pinned revision's MIT license.

## Consequences

SwiftPM requires network access on first resolution, then reuses verified cached
artifacts. The CLI remains buildable with command-line Swift tools. The app
retains macOS 26.0 as its minimum; the framework may support older systems.

Native reproducibility means identical checksum-verified prebuilt code and
headers after clean resolution. It does not imply byte-identical app signatures,
archives or upstream source rebuilds. Record artifact identity, native platform
metadata and upstream build flags with upgrade instructions. Verify repeated
clean extraction, packaging linkage/signatures and fixture inference on upgrades.

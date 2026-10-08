# ADR-007: Use Framework-Free Test Runner and LLVM Coverage

**Status**: Accepted
**Date**: 2026-07-10

## Context

CaptainsLog must build and test with Apple Command Line Tools, without requiring
Xcode. The available toolchain does not provide XCTest or Swift Testing, so
`swift test` cannot host the project's tests.

## Decision

Use `run-tests`, a framework-free executable that exits nonzero on failure.
Deterministic tests use temporary directories and injected boundaries rather
than audio hardware, network downloads, or model inference.

Use LLVM instrumentation through `scripts/test-coverage.sh`. Report all
production sources and enforce an 80% line-coverage floor over deterministic
production logic. App state, orchestration, CLI, filesystem, search, audio-level
calculations, and pipeline logic remain within that gate. Declarative SwiftUI
rendering and direct hardware/native-inference adapters remain visible in the
aggregate report but require separate integration checks.

The 80% floor is a project regression guardrail, not a quality score. Raise it
only after stable behavioral improvements; never exclude ordinary logic merely
to improve the percentage.

## Consequences

- Builds and deterministic tests need neither Xcode nor a testing dependency.
- The custom runner owns test discovery, reporting, and failure handling.
- Hardware, native UI, and installed-model checks remain separate concerns.
- Model evaluations require semantic human review; structural checks and
  coverage percentages cannot establish output quality.

## Verification boundary

Use `swift run run-tests` for deterministic behavior and `bash scripts/test-coverage.sh` for coverage. Fixture pipelines and stage evaluations run sequentially with isolated configuration and repository inputs. Demo data is presentation material. Record dated results and unresolved acceptance checks directly in the related backlog tasks; a structural pass does not replace semantic review.

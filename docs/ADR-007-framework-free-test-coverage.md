# ADR-007: Use Framework-Free Test Runner and LLVM Coverage

**Status**: Accepted  
**Date**: 2026-07-10

## Context

CaptainsLog must build and test with Apple Command Line Tools; a full Xcode installation is not required. The available toolchain does not provide XCTest or the Swift Testing module, so `swift test` cannot host the project’s tests.

## Decision

Keep `run-tests` as the framework-free test executable. It exits non-zero on failures and contains deterministic tests that use temporary directories instead of audio hardware or model inference.

Use `scripts/test-coverage.sh` to compile the runner and CLI with LLVM coverage instrumentation, execute deterministic CLI smoke/validation cases, and write a filtered JSON report to `.build/coverage/coverage.json`. The script enforces a production line-coverage floor.

Remaining coverage work is tracked in [PLAN-003](PLAN-003-test-coverage-gaps.md). That plan prioritizes extracting testable UI decisions, executing complete CLI workflows with fakes, isolating recorder hardware boundaries, and covering core parsing and recovery paths. Declarative SwiftUI rendering, real audio hardware, and native model inference remain separate integration concerns rather than requirements of the deterministic gate.

## Consequences

- Tests and coverage run without Xcode, XCTest, or a testing-package dependency.
- The report excludes third-party dependencies and test-runner code.
- Audio, model-download, and pipeline-inference boundaries are injected in tests, so the deterministic gate does not require hardware, network access, or model loading.
- The runner remains responsible for test discovery, reporting, and failure handling.
- Model-quality evaluations in `eval/` remain a separate release gate.
- Coverage improvements and future changes to the enforced floor follow [PLAN-003](PLAN-003-test-coverage-gaps.md); ordinary business logic must not be excluded merely to improve the percentage.

## Verification

```sh
swift run run-tests
bash scripts/test-coverage.sh
```

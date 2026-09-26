# ADR-007: Use Framework-Free Test Runner and LLVM Coverage

**Status**: Accepted  
**Date**: 2026-07-10

## Context

CaptainsLog must build and test with Apple Command Line Tools; a full Xcode installation is not required. The available toolchain does not provide XCTest or the Swift Testing module, so `swift test` cannot host the project’s tests.

## Decision

Keep `run-tests` as the framework-free test executable. It exits non-zero on failures and contains deterministic tests that use temporary directories instead of audio hardware or model inference.

Use `scripts/test-coverage.sh` to compile the runner and CLI with LLVM coverage instrumentation, execute deterministic CLI smoke/validation cases, and write the full-production JSON report to `.build/coverage/coverage.json`. The script reports total production coverage and enforces an 80% line-coverage floor over deterministic production logic.

The 80% floor is a project-chosen regression threshold, not a Swift, GitHub, or industry-mandated number. It sets a substantial minimum for the deterministic code that the lightweight, model-free suite can exercise, while keeping declarative UI and direct hardware/native-inference adapters visible in the aggregate report without making their platform prerequisites part of this gate. The percentage is a guardrail rather than a quality score; behavior assertions and the separate semantic evaluation review remain necessary. Raise the floor only after repeated stable coverage runs, not by excluding ordinary logic.

The completed deterministic coverage work is recorded in [PLAN-003](PLAN-003-test-coverage-gaps.md): UI decisions, CLI workflows, recorder lifecycle operations, and core recovery paths now have framework-free behavioral tests. Declarative SwiftUI rendering and design fixtures, real audio hardware, and direct native model-inference adapters remain separate integration concerns rather than requirements of the deterministic gate. Their files remain visible in the all-source report, while excluded from the 80% deterministic-production metric. App state, model orchestration, CLI and filesystem workflows, search, pure audio-level calculations, and pipeline logic remain inside the enforced scope.

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

# PLAN-003: Close Remaining Test Coverage Gaps

**Status**: Complete for the documented deterministic plan and integration gates. Opt-in microphone and installed-model smoke commands remain available for prepared machines.
**Baseline date**: 2026-07-10
**Baseline snapshot (historical; remeasure before comparing)**: 114 tests passing; 32.69% production line coverage

The implementation review on 2026-09-26 completed the planned deterministic CLI, core-recovery, UI-decision, recorder-adapter, evaluation, and coverage-ratchet work. Latest verification is 184 full-suite checks, 132 lightweight checks, and 82.16% deterministic-production line coverage against the 80% floor. Actual microphone capture and a standalone installed-model smoke remain opt-in integration checks; the model-backed fixture pipeline was run separately.

## Goal

Increase confidence in user-visible workflows and failure handling without making Xcode, audio hardware, network access, or downloaded models prerequisites for the deterministic test gate.

Coverage percentage is a signal, not the objective. New tests should assert behavior at boundaries and failure points; generated SwiftUI code and native inference should not be exercised merely to raise the number.

## Baseline gaps

| Area | Line coverage | Uncovered lines | Main gap |
|---|---:|---:|---|
| `CaptainsLog/ContentView.swift` | 0% | 2,240 | SwiftUI presentation and user actions |
| `CaptainsLog/FirstRunView.swift` | 0% | 496 | First-run setup flow |
| `CaptainsLogCore/LLM.swift` | 1.55% | 318 | Native model loading and inference |
| `cl/CL.swift` | 41.65% | 248 | Complete command workflows |
| `CaptainsLog/LCARSKit.swift` | 0% | 208 | Declarative UI components |
| `CaptainsLogCore/Recorder.swift` | 27.47% | 198 | AVFoundation and device behavior |
| `CaptainsLog/Theme.swift` | 0% | 137 | Declarative styling |
| `CaptainsLog/ModelManager.swift` | 31.66% | 136 | Real download and model lifecycle boundaries |
| `CaptainsLog/ProcessingCoordinator.swift` | 59.94% | 127 | Lifecycle and progress combinations |
| `CaptainsLog/AppState.swift` | 62.91% | 112 | App orchestration and user actions |
| `CaptainsLogCore/Pipeline.swift` | 80.88% | 100 | Less common recovery and filesystem failures |

The SwiftUI totals include compiler-generated and declarative body lines. Their raw uncovered-line counts therefore overstate their relative behavioral risk.

## Work plan

### 1. Extract and test UI behavior without rendering SwiftUI

- [x] Extract first-run visibility, folder selection outcomes, navigation state, and user-action decisions into small policy/state types.
- [x] Move entry-row, recording-dock, and queue action eligibility and status calculations out of SwiftUI view bodies.
- [x] Test initial, success, cancellation, retry, and error transitions through the framework-free runner.
- [x] Keep visual layout, styling, previews, and AppKit panel presentation outside the deterministic gate.

**Done when:** first-run and primary app actions have behavioral tests runnable with Command Line Tools, and views mainly bind to already-tested state.

### 2. Exercise complete CLI workflows with injected operations

- [x] Add command execution seams for filesystem-backed temp workflows, recorder, transcriber, LLM, and pipeline operations.
- [x] Cover successful `cleanup`, `filename`, `categorize`, `enrich`, `pipeline`, and `resume` execution using temporary directories and fakes.
- [x] Cover missing input, injected inference failures, partial pipeline state, and command failure outcomes. Invalid configuration coverage remains limited to supported config parsing and validation cases.
- [x] Retain parser/help smoke tests for every registered subcommand.

**Done when:** each command has at least one successful workflow test and its important validation or dependency failure is asserted.

### 3. Isolate recorder hardware boundaries

- [x] Put audio-engine creation, input-device discovery, tap installation, file writing, and session release behind injected operations.
- [x] Test start, pause, resume, stop, immediate stop, repeated commands, unavailable input, and write failures with fake engine/writer operations.
- [x] Add a manually invoked hardware smoke test for a real recording; do not include it in the deterministic gate. `scripts/test-recorder-hardware.sh` is opt-in and was not run during deterministic verification.

**Done when:** recorder lifecycle and error behavior are deterministic, while only the AVFoundation adapter requires real hardware.

### 4. Complete core parsing and recovery cases

- [x] Add malformed-output, cancellation, and filesystem tests for `Categorize`, `Filename`, `Cleanup`, and `Enrich`.
- [x] Add `Pipeline` tests for every resumable stage, absent intermediate files, stale output, cancellation, and failure cleanup.
- [x] Add transition/error tests across `ProcessingCoordinator`, `AppState`, `ConfigManager`, and `ModelManager`; native download and OS-owned behavior remain separate gates.

**Done when:** every deterministic error branch in core pipeline orchestration has an assertion and temporary files are verified after both success and failure.

### 5. Keep native integrations as separate gates

- [x] Continue evaluating model output through the task-specific suites under `eval/`. The latest report records transcription semantic quality as failed; artifact and other-stage checks do not override that result.
- [x] Add opt-in smoke checks for loading the configured LLM and transcription models on a prepared machine (`scripts/test-model-smoke.sh`); it was not run in this deterministic pass.
- [x] Document prerequisites and fail clearly when model folders or model files are missing without affecting deterministic tests.
- [x] Add native accessibility checks as a separate macOS gate, documented in `docs/TESTING-UI-REPORT.md` and `scripts/test-ui.sh`.

**Done when:** native model and hardware regressions have explicit, documented checks without making local deterministic coverage depend on large downloads or Xcode.

### 6. Ratchet the coverage gate

- [x] Record coverage after completed sections and review newly uncovered production branches.
- [x] Set the enforced deterministic-production line floor to 80%; latest run is 82.16%.
- [x] Report a separate deterministic-logic metric and document exclusions for declarative SwiftUI and direct native adapters in ADR-007; all sources remain visible in the aggregate report.
- [x] Keep ordinary business logic inside the enforced scope; exclusions are limited to presentation fixtures, declarative views, and native integrations.

**Done when:** the coverage floor prevents regression, is supported by stable behavioral tests, and its scope is documented in ADR-007.

## Verification

Run after every phase:

```sh
swift run run-tests
bash scripts/test-coverage.sh
```

The coverage command must continue to produce `.build/coverage/coverage.json`, pass its enforced floor, and require only Apple Command Line Tools.

## Completion criteria

This plan is complete when:

- all checkboxes above are complete;
- deterministic tests pass without Xcode, hardware, network access, or installed models;
- each CLI workflow and core pipeline stage has success and failure coverage;
- UI decision logic is tested independently of SwiftUI rendering;
- recorder lifecycle behavior is tested through an injected fake audio boundary;
- native inference, hardware, and any rendered-UI checks are documented as separate gates; and
- ADR-007 records the final coverage scope and enforced floor.

The deterministic plan is complete. `RecorderOperations` now injects device discovery, engine and writer creation; fake-engine tests cover tap installation, start, pause gating, stop/release, unavailable device selection, and write errors. The AVFoundation adapter and actual microphone capture remain a named hardware gate. Native dialog/Finder interactions and installed-model smoke checks likewise stay opt-in as documented in `TESTING-UI-REPORT.md` and the smoke scripts.

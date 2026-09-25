# PLAN-003: Close Remaining Test Coverage Gaps

**Status**: Planned  
**Baseline date**: 2026-07-10  
**Baseline**: 114 tests passing; 32.69% production line coverage

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

- [ ] Move first-run validation, folder selection outcomes, navigation state, and user-action decisions into small state or reducer types.
- [ ] Move `ContentView` action eligibility and presentation-state calculations out of view bodies where practical.
- [ ] Test initial, success, cancellation, retry, and error transitions through the framework-free runner.
- [ ] Keep visual layout, styling, previews, and AppKit panel presentation outside the deterministic gate.

**Done when:** first-run and primary app actions have behavioral tests runnable with Command Line Tools, and views mainly bind to already-tested state.

### 2. Exercise complete CLI workflows with injected operations

- [ ] Add a command execution seam for filesystem, recorder, transcriber, LLM, and pipeline operations.
- [ ] Cover successful `cleanup`, `filename`, `categorize`, `enrich`, `pipeline`, and `resume` execution using temporary directories and fakes.
- [ ] Cover missing input, invalid configuration, dependency failure, partial pipeline state, and non-zero exit behavior.
- [ ] Retain parser/help smoke tests for every registered subcommand.

**Done when:** each command has at least one successful workflow test and its important validation or dependency failure is asserted.

### 3. Isolate recorder hardware boundaries

- [ ] Put audio-engine creation, input-device discovery, tap installation, file writing, and session release behind injected operations.
- [ ] Test start, pause, resume, stop, immediate stop, repeated commands, unavailable input, and write failures with a fake engine.
- [ ] Add a manually invoked hardware smoke test for a real recording; do not include it in the deterministic gate.

**Done when:** recorder lifecycle and error behavior are deterministic, while only the AVFoundation adapter requires real hardware.

### 4. Complete core parsing and recovery cases

- [ ] Add malformed-output, cancellation, and filesystem tests for `Categorize`, `Filename`, `Cleanup`, and `Enrich`.
- [ ] Add `Pipeline` tests for every resumable stage, absent intermediate files, stale output, cancellation, and failure cleanup.
- [ ] Add remaining `ProcessingCoordinator`, `AppState`, `ConfigManager`, and `ModelManager` transition/error combinations.

**Done when:** every deterministic error branch in core pipeline orchestration has an assertion and temporary files are verified after both success and failure.

### 5. Keep native integrations as separate gates

- [ ] Continue evaluating model output through the task-specific suites under `eval/`.
- [ ] Add opt-in smoke checks for loading the configured LLM and transcription models on a prepared machine.
- [ ] Document prerequisites and ensure missing models skip or fail the opt-in integration command clearly without affecting deterministic tests.
- [ ] Consider rendered SwiftUI or accessibility tests only if a full-Xcode CI or release machine is introduced.

**Done when:** native model and hardware regressions have explicit, documented checks without making local deterministic coverage depend on large downloads or Xcode.

### 6. Ratchet the coverage gate

- [ ] Record coverage after each completed section and review newly uncovered production branches.
- [ ] Raise the enforced line floor only after the suite remains stable across clean runs.
- [ ] Prefer a separate deterministic-logic metric or explicit exclusions for declarative SwiftUI and native adapters before using the aggregate percentage as a release target.
- [ ] Never exclude ordinary business logic solely to improve the reported percentage.

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
- recorder lifecycle behavior is tested through a fake audio boundary;
- native inference, hardware, and any rendered-UI checks are documented as separate gates; and
- ADR-007 records the final coverage scope and enforced floor.

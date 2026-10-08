# Testing gates and isolation

Testing policy and commands are maintained here; dated results belong in
[verification history](testing-verification.md). The test-runner decision is
[ADR-007](0007-framework-free-test-coverage.md). Open acceptance work stays in
the [backlog](../backlog/tasks/).


GitHub Actions runs `swift run run-tests` only for release tags; branch pushes and pull requests do not run CI. The full runner also includes workflow, search-index, coordinator, and pipeline-orchestration groups. Tests cover config migration/recovery, prompt construction, parsing, onboarding persistence, Logs/detail/deletion, recording and queue policies, settings reload, search cancellation/retry, and CLI success/failure paths. Injected recorder operations cover device fallback, tap installation, RMS levels, pause gating, start/write failures, and resource release. Pipeline tests inspect source preservation, fresh audio imports, unsafe slugs, every resume stage, missing artifacts, cancellation, and retry recovery.

Set `CAPTAINS_LOG_CONFIG_PATH` to a temporary config with a temporary `dataDir`, seeded only from repository `eval/` fixtures. Tests must bypass the default demo runtime; hard-coded design examples and `demo/` are presentation material, not evaluation inputs. Never access personal recordings or notes.

| Gate | Command / evidence | Limits |
|---|---|---|
| Deterministic behavior | `swift run run-tests`; CI runs only for releases | Fakes assert state and files, not native inference or capture. |
| Coverage and CLI validation | `bash scripts/test-coverage.sh` | Help/arguments, config persistence, six list stages and prompt rendering; JSON at `.build/coverage/coverage.json`. |
| Fixture pipeline | `bash scripts/run-evals.sh --pipeline` | Stage artifacts, category/filename assertions, completed-resume immutability, search indexing/readback; semantic review remains separate. |
| Stage evaluations | `bash scripts/run-evals.sh --suites`; `--categorize` for the four category cases | Use the stage skills; run inference sequentially and review omissions, additions, hallucinations and ranking. |
| Saved-output validation | `bash scripts/run-evals.sh --validate-run <run-stamp>` | Checks structure without inference; cannot establish semantic quality. |
| Native UI | `bash scripts/test-ui.sh eval` or a fixture-state selector | Temporary app/config/data, presentation state injection; does not validate models or recording. |
| Installed models | `bash scripts/test-model-smoke.sh` | Prepared machine with the four `CAPTAINSLOG_*_MODEL_*` variables; opt-in, outside CI. |
| Microphone hardware | `bash scripts/test-recorder-hardware.sh` | Separately confirmed interactive capture; outside automated suites and CI. |

The UI harness prints its isolated paths and bundle identifier. Close the app before removing its temporary root. `CAPTAINSLOG_UI_SKIP_BUILD=1` reuses the debug build. Fixture startup skips watcher, microphone discovery, downloads and pipeline bootstrap, but controls remain real: do not activate processing/retry/reprocess or recording controls during presentation checks. Safe fixture search retry returns before embedding work.

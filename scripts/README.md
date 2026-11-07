# Development commands

Run Make from the repository root. It drives the development workflows; the
scripts in this directory are necessary implementation helpers. Apple Command
Line Tools include Make, Swift and the other macOS build tools; Xcode IDE is not
required. `make help` lists available targets.

| Command | Purpose / options |
|---|---|
| `make dev` / `make` / `make run` | Launch the cached debug app directly with its persistent isolated demo copy, skipping SwiftPM when sources and package manifests are unchanged. Missing apps or changed inputs trigger an app-only incremental build first. No packaging, tests or evaluations run; the first build takes longer. |
| `make build` | Build Swift package products; `CONFIGURATION=release` selects release (default: debug). |
| `make website` | Serve the static landing page at `http://127.0.0.1:8765` with the Swift tooling. Set `PORT` to use a different port. |
| `make cli ARGS='search "project architecture"'` | Run a CLI command. Normal CLI usage uses your configured data; checks must supply isolated config/data and eval fixtures. |
| `make tests` | Run the deterministic framework-free suite with temporary config/data. `ARGS=--unit` or `make tests-unit` selects model-free unit checks. |
| `make evals` | Run the full audio pipeline then all stage suites, sequentially. `MODE=pipeline` / `MODE=suites` selects one; `STAGE=filename CASE="fixture stem"` selects focused cases. |
| `make packaging` | Build the release app and CLI, bundle native libraries and notices, sign ad hoc, and create `dist/CaptainsLog-VERSION.zip`. |
| `make release` | Infer version from Conventional Commits and prepare a local release on clean main. `BUMP=patch`, `minor`, `major` or an explicit version overrides `auto`; `ARGS=--dry-run` previews and `ARGS=--publish` publishes. See the [release checklist](../README.md#changelog-and-releases). |

Use `make cli ARGS="delete-outputs --confirm"` with the app quit to delete all
intermediate results, finished logs and legacy backups while retaining audio and
settings. This does not start processing; `make cli ARGS="resume"` processes
pending recordings afterwards. Checks must use isolated config/data and eval fixtures.

Use `ARGS="--combined-metadata"` to evaluate category, filename and enrichment fixtures through experimental combined metadata generation, validating the complete metadata schema for every combined response and retaining raw/parsed responses in the semantic review bundles. Combined metadata fixtures default to seed42 while preserving explicit case seeds; standalone stages and production keep their existing defaults.

Additional flags use `ARGS="..."`, passed to the underlying command. Quote paths
and stems with spaces inside ARGS as shell arguments. Existing `CAPTAINS_LOG_EVAL_*`
model/run-directory environment overrides continue to work. Packaging always
builds release and development launch always uses debug, regardless of
`CONFIGURATION`. Release preparation runs only Git/version/changelog checks and
creates the release commit and tag. It does not build or run tests. The tag
workflow builds the release app and CLI, verifies packaging, and publishes the
archive and casks. Run development tests explicitly before releasing; model
evaluations remain a separate `make evals` command.

| Supporting command | Purpose / options |
|---|---|
| `make evals-review` | Reopen the last-used review session and passage in your browser, reusing a running server when possible. `RUN_DIR=...` selects another saved run. `COMPARISON_RUN=...` adds a saved eval run or a directory of per-recording `.txt` transcripts. `PORT=...` overrides the remembered port (8777 for a new session); `ARGS=--prepare-only` skips serving. Use `ARGS=--differences` with pinned transcript/timestamp comparison files to select actual discrepancies from both models. Use `ARGS=--serve-saved` to reopen completed reviews without regenerating files. `ARGS=--no-open` suppresses browser launch for headless use. No inference. |
| `make evals-list` | List synthetic fixtures without loading models; accepts `STAGE` / `CASE`. |
| `make evals-pipeline` / `make evals-suites` | Run the audio pipeline or all stage suites. The reviewed Dutch TNG recording is the default and only transcription pipeline input. |
| `make evals ARGS="--validate-run RUN_DIR"` | Validate saved outputs without inference; `--baseline RUN_DIR` assembles comparison evidence. |
| `make tests-coverage` | LLVM-instrumented deterministic and fixture CLI coverage; enforce production coverage floor. |
| `make tests-updates` | Exercise simulated Homebrew updates using fake Homebrew fixtures. |
| `make tests-release` | Model-free release/changelog fixtures and temporary local Git publication. |
| `make tests-runtime` | Verify the pinned native archive twice and compare clean unsigned runtime artifacts and matching headers. |
| `make tests-evals` | Model-free evaluation orchestration fixtures. |
| `make tests-enrich` | Build, then check enrichment validation and CLI seed boundaries without inference. |
| `make tests-model` | Opt-in installed-model smoke test; requires the four `CAPTAINSLOG_*_MODEL_*` variables in its helper. |
| `make tests-app-performance RUN_DIR=/absolute/new/output` | Opt-in native startup and quit-during-decoding regression check. Quit the app first; supply prepared `CAPTAINSLOG_WHISPER_MODEL_FOLDER` and `CAPTAINSLOG_QWEN_MODEL_FOLDER`. Debug-only, eval audio and isolated config/data; no microphone. |
| `make tests-search-shutdown RUN_DIR=/absolute/new/output` | Opt-in native cached-search/quit regression check using eval content, isolated config and prepared E5/Qwen/Whisper models. Keep all other native work stopped; `ARGS=--baseline` retains a failing exit for comparison. |
| Debug `run-tests --native-recording-busy` (invoke built binary directly) | Opt-in Core-only busy-admission check with real cached Whisper and eval audio; run from repository root with `CAPTAINS_LOG_CONFIG_PATH` under repository `tmp` or system temporary storage. Preserves CPU/model gates, creates its own isolated data, and requires the exclusive native slot. No GUI or microphone. |
| `make tests-recorder` | Interactive microphone smoke check with explicit confirmation. |
| `make ui` | Launch temporary eval-backed native UI; optional state selector via `ARGS`. Use `eval-menu`, `eval-menu-recording`, `eval-menu-processing`, or `eval-menu-failed` to inspect the shared menu panel in a labeled synthetic preview window. |
| `make release-notes VERSION=0.1.2` | Extract release notes. |
| `make release-check BASE=<commit> HEAD=<commit>` | Validate changelog coverage (HEAD defaults to HEAD). |
| `make release-cask VERSION=0.1.2 SHA256=<hash>` | Update Homebrew cask metadata. |
| `make icons` | Regenerate the committed icon using the Swift renderer, `sips` and `iconutil`. |
| `make clean` | Clean Swift package build products. |

Make keeps targets sequential even with `-j`; separate invocations still must not
run model jobs concurrently. Evaluations use only repository `eval/` fixtures and
isolated config/data. The UI harness is for presentation inspection; its processing
and recording controls invoke real models or hardware. Checks bypass default demo
seeding. See the [testing workflow](../README.md#testing) and stage skills in
[`eval/skills/`](../eval/skills/) for quality gates and semantic review requirements.

### Cached native search shutdown check

`make tests-search-shutdown RUN_DIR=/absolute/new/output` loads the checksum-pinned
E5 model, indexes/searches only copied eval content, leaves the real search engine
cached in the UI, and requests app quit. Supply prepared
`CAPTAINSLOG_WHISPER_MODEL_FOLDER` and `CAPTAINSLOG_QWEN_MODEL_FOLDER` for isolated
bootstrap; prepare E5 before running. No microphone or personal data is used, and
all other inference and app checks must be stopped first.

The helper verifies schema-valid isolated data/model paths through the CLI before
launching the app. It records source revision, executable/model/fixture SHA-256,
PID, logs, actual search-ready/quit/delegate markers and exit status. Success
requires real cached search, normal exit and no timeout. `ARGS=--baseline` records
a failing native exit for comparison; it still requires the actual search and
termination markers. A 180-second watchdog signals only the owned test process.
A simulated search fixture cannot establish this shutdown regression.

### Native performance regression check

`make tests-app-performance RUN_DIR=/absolute/new/output` builds the debug app and CLI,
then performs three separate process launches and one real Whisper decoding/quit check.
Use `ARGS=--quit-during-loading` for the separate Whisper initialization regression.
It requires Quit during the text-decoder load and process exit within three seconds;
a bounded exit must follow the audio-writer-close marker.
The two prepared model-folder environment variables are mandatory; model downloads
are not part of the timing. Set `CAPTAINSLOG_PERFORMANCE_QWEN=1` for a Qwen check
starting from the repository's expected transcript. Run all checks sequentially,
with the installed app closed and no other inference running.

Each launch creates fresh eval-backed data and a schema-valid isolated config. The
CLI must confirm the exact loaded data/model paths before the app starts; the app
also rejects invalid benchmark configs before constructing app state. Results retain
binary/model/fixture SHA-256 identities, logs, marker timestamps, process exit status and fixture outputs under `RUN_DIR`.
Startup measures process launch to completed entry/device bootstrap and model
readiness; it includes process startup rather than only first window rendering.
Closing measures the actual AppKit quit request to process exit after a native decode
callback. The native check requires decode, delegate entry, drain and reply markers,
normal exit, startup below five seconds and close below three seconds. Canceled Whisper
partial text must not be saved. A debug-marker absence or native failure fails the
check; an idle/simulated processing state cannot satisfy it.

`ARGS="--startup-only --startup-entries=1000"` runs three launches without inference,
restoring 1,000 completed entries generated only from repository transcription,
cleanup and enrichment fixtures. Each launch copies the same fixture bytes into
fresh isolated data; the count is retained in metadata. Use the same count and
binary build configuration for before/after comparisons. Set
`--startup-max-seconds=1.2` to enforce a tighter loaded-library regression limit;
`--startup-runs=7` increases repetitions.
Startup-only mode allows one second for normal quit, then stops only its owned
idle process if needed after readiness and records this
controlled stop separately; it provides no closing measurement. The default
combined check still requires normal AppKit shutdown during native processing.

`ARGS=--baseline` records timings without enforcing thresholds. A watchdog stops
only the owned test process after 180 seconds overall or 60 seconds following quit;
those runs are failures, not successful shutdown measurements. The opt-in
`CAPTAINSLOG_PERFORMANCE_FINISH_PIPELINE=1` Qwen comparison finishes the real text
pipeline instead of quitting at decode, retaining output for semantic review.
Both the CLI and native app use the same Core 128-token prompt chunk bound,
models, context parameters, prompts, sampling and pipeline checkpoints, following
[ADR-027](../docs/0027-cli-and-gui-processing-should-work-the-same-way-technically.md).
Performance markers and comparison completion hooks are disabled in release builds.
These checks depend on local hardware and cache state; compare matching builds,
fixtures and model files before making speed claims.

## Implementation map

Start with [Makefile](../Makefile) for command invocation. One
[tooling.swift](tooling.swift) dispatcher replaces the former per-command aliases.
It compiles and runs [Main.swift](Sources/Tools/Main.swift). Independent native
performance/search checks, release preparation and icon drawing remain standalone
because they have their own process lifecycle or lightweight invocation.

| Workflow | Implementation |
|---|---|
| Packaging, framework bundling, runtime verification | [Native.swift](Sources/Tools/Native.swift) |
| UI harness, updater/model/recorder checks | [Checks.swift](Sources/Tools/Checks.swift) |
| Evaluations, review app, scoring, validation and their tests | [evaluation tools](../eval/tools/Sources/EvaluationTools/), [review skills](../eval/skills/) |
| Landing page preview | [evaluation dispatcher](../eval/tools/Sources/EvaluationTools/Dispatch.swift), shared review HTTP server, [`website/`](../website/) |
| Coverage | [Coverage.swift](Sources/Tools/Coverage.swift) |
| Release preparation, notes, changelog checks and cask updates | [release.swift](release.swift); release fixtures: [ReleaseChecks.swift](Sources/Tools/ReleaseChecks.swift) |
| Temporary config/data, subprocesses and file helpers | [ToolSupport](Support/Sources/ToolSupport/Common.swift) |

Before full tests, coverage or updater checks, quit the app when recording and
processing have finished. Updater fixtures still inspect the real app process.
Run checks from the repository root so relative `eval/` fixture paths resolve.

The tooling executable depends on two local libraries: common filesystem/process
support under `scripts/Support/`, and evaluation logic/resources under `eval/tools/`.
Yams remains pinned in the evaluation package and the tooling lockfile. None is a
dependency of the app package. The CLI's evaluation command source lives in
`eval/CLI/`; its source link in `Sources/cl/` lets SwiftPM compile it with the CLI.

Use Make for workflows. For direct dispatch, run
`swift scripts/tooling.swift COMMAND [ARGS...]`; for example,
`swift scripts/tooling.swift evals --stage filename --list` lists fixtures without
loading a model. Browser review tests run with
`node --test eval/tools/tests/*.mjs`.

For an isolated native performance check on a cold CoreML specialization cache,
`CAPTAINSLOG_PERFORMANCE_PROCESS_TIMEOUT=300` extends only the overall processing
setup watchdog (default 180 seconds; accepted range 180–600). Metadata records
the selected value. Actual native decoding readiness, ordered shutdown markers
and the three-second processing quit limit remain required.

## User scenarios before a release

Run these scenarios against the candidate build, using only repository `eval/`
fixtures and fresh isolated configuration/data. Check UI access before starting;
a locked screen or denied access leaves interactive scenarios unverified. Quit
other app instances and run all model work sequentially. Preserve the build
revision, configuration, fixture names, screenshots/video, observed results and
failures under ignored `tmp/`. Mark a scenario passed only after its actions and
observable results have been checked; simulated UI states establish presentation
only.

| Scenario | Actions | Check |
|---|---|---|
| First launch | Start `make ui ARGS=onboarding`; walk through onboarding, choose categories and context, then open Logs. | Every control is reachable; setup completes; choices appear in Context and Settings. This harness skips actual model download. |
| Empty library | Start `make ui ARGS=eval-empty`; resize to a small supported window and a large window; open Context and Settings and return. | Empty-state content and recording controls remain readable and do not overlap; navigation remains usable. |
| Import through completed log | Launch the candidate executable directly with `CAPTAINS_LOG_CONFIG_PATH` pointing to fresh isolated config and data, bypassing demo seeding. Configure prepared models; copy `eval/transcribe/audio/tng-nl01-vrije-dag-enterprise-corrected.m4a` into its `audio/` directory. Follow transcription, cleanup, categorization and completion; open the log. | The original audio survives; the completed log is readable and searchable. Compare transcript, cleaned text and final output with the corresponding eval references for omissions, changed meaning and invented content. Preview fixtures cannot establish this result. |
| Pause and resume | During real fixture processing, Pause, then Resume; repeat while cancellation is still draining. | UI remains responsive; work resumes from saved progress; requests run serially; no duplicate or partial completed log appears. |
| Reprocess | Reprocess the completed fixture from the row action and from log detail; Pause a queued restart, then request it again. | Derived results clear immediately; original audio remains; all stages rerun; a later Pause discards waiting work without restoring deleted outputs. |
| Search and filters | Search for a distinctive phrase from the completed fixture, change category filters, try a missing phrase and clear search. Open a result. | Results respect filters and open the expected log; empty results are understandable; clearing search restores Logs. Use prepared embedding models for real search. |
| Context and settings | Change categories, personal context and a correction; change microphone selection; quit and reopen the same isolated build/config. | Choices persist. Future processing uses the chosen context; existing logs remain available. Do not record personal audio to test input selection. |
| Model availability | Inspect Models and its disk usage; inspect `eval-model-downloading` and `eval-model-error` presentation states. Test actual missing-model setup only in a separate disposable model directory. | Progress and failures are understandable and retry remains available. Never delete prepared/shared model caches; preview states do not verify downloads or recovery. |
| Recording controls | Inspect `eval-recording` and `eval-recording-paused`; for hardware capture use separately confirmed `make tests-recorder`. For processing use eval audio and the existing fixture recording engine. | Recording, pause and stop controls remain reachable; captured audio finalizes before processing. State previews do not verify hardware capture or transcription during capture. |
| Quit and reopen | Quit once idle and once during fixture transcription, then reopen the isolated candidate. Use `make tests-app-performance` for bounded native shutdown evidence. | Process exits without hanging; original audio and saved checkpoints survive; unfinished work remains pending. An idle quit does not verify native cancellation. |

Keep per-run observations in the evidence directory. Report unperformed actions
and fixture-only substitutes explicitly; do not turn a presentation preview into
a claim that real processing passed.

The listening app opens on a review overview by default. Its Overview button returns from any passage or recording. Running review servers register their local addresses in ignored `tmp/eval-review-sessions.json`, so the overview can link related rounds and read their saved progress. Restart the relevant review server if its local address is no longer available.

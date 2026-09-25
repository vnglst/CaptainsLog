# CaptainsLog Plan

## Direction

CaptainsLog is a local-only voice-memo pipeline for Apple Silicon. Record a voice memo, get back a cleaned-up log entry with metadata. All ML inference runs on-device via llama.cpp + WhisperKit — no cloud APIs.

Every pipeline stage is runnable from the terminal as `swift run cl <stage>` for independent smoke testing, and the SwiftUI app wraps the same pipeline in a one-click interface.

## Open items

### Demo files and safe development mode

- [x] Create a set of demo files for recording short videos of the app, and make development mode in the repository always use these repo-local demo files for testing and demos rather than pointing at the user's actual Obsidian folder. Debug app launches seed a writable TNG demo under `tmp/demo-runtime/`; explicit config-path overrides remain for isolated integration runs.

### Test Coverage Gaps ([PLAN-003](PLAN-003-test-coverage-gaps.md))

Extend the no-Xcode deterministic test gate around UI decision logic, complete CLI workflows, recorder lifecycle behavior, and remaining core recovery paths. Keep rendered SwiftUI, real hardware, and native model inference as separate integration gates.

- [ ] Extract and test UI behavior independently of SwiftUI rendering
- [ ] Exercise complete CLI workflows with injected operations
- [ ] Isolate and test recorder lifecycle behavior behind a fake audio boundary
- [ ] Complete core parsing, orchestration, and recovery cases
- [ ] Document opt-in native integration checks and ratchet the coverage floor
- [ ] Find a way to test the onboarding flow and other crucial flows end-to-end

See [PLAN-003](PLAN-003-test-coverage-gaps.md) for the measured baseline, implementation order, and completion criteria.

### UI/UX Improvements

#### Logs interface ([PLAN-004](PLAN-004-logs-implementation.md))

The app now uses the Logs workspace. Remaining work is audio playback, collections/projects, and the native visual and interaction acceptance pass. See the current status and design references in `PLAN-004` and `design/logs/`.

See [PLAN-004](PLAN-004-logs-implementation.md) for current functionality, remaining capabilities, and verification work.

- Historical LCARS-specific implementation notes are preserved in git history. They describe the retired interface and are not current requirements.
- [ ] Add git commit hash to the Settings page (currently only shown in the main UI header)
- [ ] Add a way to configure categories (how logs are categorized into folders); make this configurable both in Settings and as part of onboarding
- [ ] Add a copy button to copy the entire cleaned-up transcript for a log entry to the clipboard
- [ ] Add a macOS menu bar presence so CaptainsLog can be minimized to the menu bar, with controls to start and stop recording there

### Release v0.1.0 — Enable Public Distribution
Enable anyone with an Apple Silicon Mac to download and use CaptainsLog without building from source. Single download provides both GUI app and CLI — users choose their interface. Local ad-hoc packaging and the cask are prepared; publishing is pending repository cleanup.

See [PUBLISHING-PLAN.md](PUBLISHING-PLAN.md) for the required privacy/history review, rights review, release checks, and publication sequence.

- [x] Build a single app bundle containing the GUI, `cl`, resources, and llama.cpp runtime; generate a versioned ZIP and pin its SHA-256 in the Homebrew cask.
- [x] Document Homebrew installation and automatic quarantine removal at the top of `README.md`.

**Distribution channels:**
- [ ] Downloadable `.app` bundle from GitHub — planned; open the app from Finder, or run `CaptainsLog.app/Contents/MacOS/cl` for CLI
- [ ] Public Homebrew tap — the cask installs the app in Applications and `cl` in PATH; local installation was tested. Publishing is pending repository cleanup.
- [ ] Website landing page at `captainslog.koenvangilst.nl` — clear download, requirements, install steps

**User experience:**
- [ ] GUI users: Double-click app, drag to Applications, open the app from Finder; the Homebrew cask clears quarantine during installation
- [ ] CLI users: Same download, run `cl` from the bundle or PATH after Homebrew install
- [ ] First-launch flow: Choose data folder, download several GB of models, start recording

**Documentation:**
- [ ] Changelog tracking what's new in each release
- [ ] Installation guide and model download explanation

**Validation:**
- [ ] Fresh machine test setup — verify a non-developer can download, install, and run end-to-end, automate this
- [x] Local Homebrew install test — verify a temporary tap installs the app, clears quarantine, links `cl` to PATH, and both app and CLI start. A public release download remains pending.
- [ ] Release process — tag-driven automated builds, as little as possible on Github Actionsm, if possible locally and the uploading to GitHub
- [ ] Prepare a release using just GitHub (Releases + Actions, no external infra) plus instructions for how people can build CaptainsLog themselves from source

**Future distribution improvements:**
- [ ] Apple Developer account — Signed distribution removes Gatekeeper warnings
- [ ] Mac App Store — Reach users who only install from the App Store

### Completed work
- [x] Split `AppState` into smaller focused types: `RecordingState`, `ProcessingCoordinator`, `DirectoryWatcher`, `ConfigManager`, `ModelManager`
- [x] Add unit tests covering AppState components (64 tests)
- [x] **Bug:** Audio recording fails when processing is in progress — fixed guard + explicit AVAudioSession release after WhisperKit
- [x] Replace `NSString.appendingPathComponent` with URL-based path APIs throughout codebase
- [x] Extract reusable LCARS UI components into `Theme.swift`: `LCARSButton`, `LCARSSecondaryButton`, `LCARSDivider`, `LCARSCard`, semantic font/spacing/color tokens
- [x] Add `schemaVersion` field + `migrate(from:to:)` helpers to `Config.swift`
- [x] ~~Qwen3-ASR migration~~ — Reverted; Whisper Large-v2 produced fewer critical errors. See `eval/transcribe/reports/` for comparison.
- [x] New audio-based evaluation suite (`transcription-eval`, `cleanup-eval`, `filename-eval`, `enrich-eval`) with ground-truth comparison
- [x] Per-entry hover actions — pill fades out, action strip slides in (OPEN / PROCESS / DEL)
- [x] Pause and resume recording — `pauseRecording()` / `resumeRecording()` wired through `RecordingState` → `AppState` → `ContentView`
- [x] `recording_time` field in enriched YAML frontmatter, read from audio file creation date
- [x] Hover states on interactive elements (buttons, list items)
- [x] Remove model folder management from Settings UI — `SettingsView` deleted; paths managed via `cl config set`
- [x] Display version and commit hash in main UI (`appState.versionString` in header cell)

## Locked decisions

- macOS / Apple Silicon only.
- One Swift binary, SwiftUI Dock app, single window. No Python, no daemon, no IPC.
- Models: `openai_whisper-large-v2` (WhisperKit/CoreML) and **Qwen 3.5 9B 4-bit (GGUF via llama.cpp)**.
- Single `cl` executable with subcommands (Swift Argument Parser).
- UI scope: Record button + entries list with stage badges; auto-process on stop.
- Data location chosen via `NSOpenPanel` on first launch; persisted in `UserDefaults`.
- **Config lives in a file, not in UI state.** Every non-UI feature must be testable from the CLI. Config file: `~/Library/Application Support/CaptainsLog/config.json`, managed by `CaptainsLogConfig` in `Sources/CaptainsLogCore/Config.swift`. Inspect/mutate via `cl config show` / `cl config set <key> <value>`.
- **No wrappers.** Use llama.cpp and WhisperKit directly. Never Ollama or other hosted inference wrappers.
- **No post-processing.** Never add regex, string replace, or any transformation after LLM output. LLM behavior is controlled exclusively through prompts.
- **Use XML prompt structure.** In every LLM prompt, separate instructions, context, examples, and the actual input with explicit XML-style tags such as `<instructions>`, `<context>`, and `<transcript>` / `<log_entry>`. Keep prompts minimal, but make the role of each section unambiguous.
- **Pipeline steps don't mutate previous stages.** Each step writes to its own folder (`audio/`, `.pipeline/01-transcribed/`, `.pipeline/02-logs/`, `.pipeline/03-category/`, `.pipeline/04-rename/`, `logs/`).
- **Model loading is expensive (~15 s).** Load Qwen once and pass the container to cleanup, filename, and enrich stages. Never load inside a loop.
- **No layout shifts in the UI.** Elements must never move because siblings appear, disappear, or change size.
- Verification: `swift run cl <stage>` + `swift run run-tests` + skill evaluation suites (`transcription-eval`, `cleanup-eval`, `filename-eval`, `enrich-eval`).

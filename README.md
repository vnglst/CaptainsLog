# CaptainsLog

Local-only voice-memo pipeline for Apple Silicon. Record a voice memo, get back a cleaned-up log entry with metadata. Transcription runs on-device with WhisperKit/CoreML; text inference runs on-device with llama.cpp and Metal. No cloud APIs.

## Install with Homebrew

The Homebrew cask installs the GUI app and links the `cl` command in one install. It supports Apple Silicon Macs running macOS 26 or later. The app is ad-hoc signed and is not notarized because this project does not use a paid Apple Developer ID.

The source repository and release are private while the project is being cleaned up, so these install commands become available after publication:

```bash
brew tap vnglst/captainslog https://github.com/vnglst/CaptainsLog.git
brew install --cask vnglst/captainslog/captainslog
```

The cask places `CaptainsLog.app` in `/Applications` and adds `cl` to Homebrew's `bin` directory. After Homebrew verifies the archive checksum and installs it, the cask removes the quarantine attribute from this app bundle so both the GUI and `cl` start without a Developer ID or a first-launch approval step. This bypasses Gatekeeper quarantine checks for this bundle. Only install it from a tap you trust.

The first launch needs an internet connection to download the on-device models. They use several gigabytes of storage. Recording and inference then run locally.

To build the app and Homebrew archive yourself, install the build dependencies and run `./scripts/build-app.sh`. This produces `dist/CaptainsLog.app` and a versioned ZIP archive. The Homebrew cask checksum must match that archive before publishing a release.

```
audio/*.m4a  →  .pipeline/01-transcribed/*.md  →  .pipeline/02-logs/*.md  →  .pipeline/03-category/*.json  →  .pipeline/04-rename/*  →  logs/<category>/*.md
    (record)         (whisper)                     (qwen cleanup)           (qwen category)              (qwen slug)            (qwen metadata)
```

## Documentation

- [README.md](./README.md) — Project overview, build/usage instructions, and evaluation guide (this file).
- [docs/PLAN.md](./docs/PLAN.md) — Roadmap, open items, locked decisions, and completed work.
- [docs/PUBLISHING-PLAN.md](./docs/PUBLISHING-PLAN.md) — Privacy, content, rights, release, and Homebrew publication gates.
- [docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md) — Common issues and workarounds.
- [docs/ADR-001-text-model-optiq.md](./docs/ADR-001-text-model-optiq.md) — Text model quantization evaluation (superseded by the llama.cpp migration).
- [docs/ADR-003-qwen3-asr-reversion.md](./docs/ADR-003-qwen3-asr-reversion.md) — Why transcription reverted to Whisper Large-v2.
- [docs/ADR-004-qwen3-6-27b-memory-limit.md](./docs/ADR-004-qwen3-6-27b-memory-limit.md) — Why 27B models are rejected for 16 GB Macs.
- [docs/ADR-005-use-libllama-c-api-for-text-inference.md](./docs/ADR-005-use-libllama-c-api-for-text-inference.md) — Why text inference uses the libllama C API.
- [docs/ADR-006-bundle-llama-runtime-in-app.md](./docs/ADR-006-bundle-llama-runtime-in-app.md) — How llama.cpp runtime libraries are bundled in the app.
- [docs/ADR-007-framework-free-test-coverage.md](./docs/ADR-007-framework-free-test-coverage.md) — Why tests and coverage use a framework-free runner.
- [docs/PLAN-002-tng-eval-set.md](./docs/PLAN-002-tng-eval-set.md) — Design of the Star Trek TNG synthetic evaluation corpus.
- [docs/PLAN-004-logs-implementation.md](./docs/PLAN-004-logs-implementation.md) — Current Logs interface status, design references, and remaining work.
- [docs/PLAN-005-smart-search.md](./docs/PLAN-005-smart-search.md) — Architecture and implementation status for local hybrid search.
- [design/README.md](./design/README.md) — Guide to current and historical design references.
- [docs/tng-eval/README.md](./docs/tng-eval/README.md) — Scripts and ground truth for the TNG evaluation corpus.
- `.claude/skills/<stage>-eval/SKILL.md` — Skill-driven evaluation workflows for each pipeline stage (`transcription-eval`, `cleanup-eval`, `filename-eval`, `enrich-eval`).

## Requirements

- Apple Silicon Mac (M1+, 16 GB recommended)
- macOS 26 or later on Apple Silicon for the packaged app
- Swift 6.2+ and command line tools to build from source (no Xcode IDE required)
- `brew install llama.cpp` to build from source; the distributed app bundles its llama.cpp runtime

## Build

```bash
swift build
./scripts/build-app.sh      # builds dist/CaptainsLog.app with icon
```

### Safe development demo

`swift run CaptainsLogApp` (debug build) opens an isolated TNG-themed demo by default. It seeds seven completed notes and one short, pending voice memo from [`demo/`](./demo/) into the ignored `tmp/demo-runtime/data/` folder. Each note has matching, locally synthesized audio. The app keeps its data in that working copy; the configured personal data folder and first-run preference are untouched. Settings cannot change the data folder during demo mode. Search, entry detail, recording, and the pipeline use the normal app code against the demo copy. Processing the sample voice memo requires the local models, as in normal use.

The working copy persists across launches so edits and recordings can be used during a video session. To restore the original demo, quit the app and move `tmp/demo-runtime/` aside; the next debug launch recreates it. The committed notes are synthetic and contain no personal recordings. The `.m4a` samples were generated locally with macOS text-to-speech.

Debug integration runs that intentionally use another temporary data directory can set `CAPTAINS_LOG_CONFIG_PATH` to an isolated config file. Release builds continue to use the regular saved configuration.

## Usage

Launch the SwiftUI app (with proper icon and Dock integration):

```bash
open dist/CaptainsLog.app
```

> **Development note:** `swift run CaptainsLog` also launches the app, but appears as a generic terminal process in the Dock without the app icon.

Or use the CLI:

```bash
swift run cl pipeline                       # record → Ctrl+C → full pipeline
swift run cl pipeline --input <audio.m4a>   # process existing audio
swift run cl resume <stem>                  # resume a partial entry (auto-detects earliest missing step)
swift run cl list                           # list all entries with their current stage
swift run cl search "project architecture" # keyword-first, then semantic passage search
swift run cl search-index --rebuild         # rebuild the local search index
swift run cl record                         # record until Ctrl+C
swift run cl transcribe <audio.m4a>         # transcribe with Whisper
swift run cl cleanup --input <file.md>      # clean up transcript with Qwen
swift run cl categorize --input <file.md> --output <manifest.json>  # choose one destination category
swift run cl filename --input <file.md>     # generate a descriptive slug
swift run cl enrich --input <file.md>       # add YAML metadata frontmatter
swift run cl config show                    # print current config
swift run cl config set <key> <value>       # set a config value (keys: dataDir, whisperModel, qwenModelId, …)
swift run run-tests                         # run unit tests (no Xcode required)
bash scripts/test-coverage.sh               # run tests + CLI smoke coverage and enforce the coverage floor
```

The pipeline is **resumable**: if interrupted at any stage, `resume` detects the earliest incomplete step and re-runs from there. If intermediate files are missing, it falls back to the earliest affected stage rather than crashing.

## Models

- **Transcription:** whisper-large-v2 via WhisperKit (CoreML)
- **Cleanup, filenames, enrichment:** **Qwen 3.5 9B 4-bit** in GGUF format via llama.cpp (recommended: `bartowski/Qwen_Qwen3.5-9B-GGUF` `Q4_K_M`)
- **Smart search:** **multilingual-e5-small Q8_0**, an MIT-licensed 118M-parameter embedding model via llama.cpp; downloaded lazily on first search

Whisper and Qwen models are downloaded by the app when needed and cached locally. The Qwen model folder can be overridden with the CLI `qwenModelFolder` setting.

## Features

- **Recording:** captures mono AAC/M4A at 44.1 kHz; auto-named `YYYY-MM-DD-HHMM.m4a`
- **Transcription:** WhisperKit/CoreML, auto-detects language
- **Cleanup:** Qwen removes disfluencies and polishes the transcript into a log entry
- **Filename:** Qwen generates a descriptive kebab-case slug
- **Enrichment:** Qwen adds YAML frontmatter with date, categories, tags, persons, projects, summary
- **Pipeline:** chains all stages end-to-end; Qwen model loaded once and shared across stages
- **SwiftUI app:** Record button with idle/recording/processing states, audio level meter, device picker, entries list with per-file stage badges
- **Smart search:** BM25 keyword passages first, multilingual semantic passages second, with relevant snippets and highlighted terms
- **First-launch flow:** `NSOpenPanel` for data folder, in-app model download with progress bars
- **Settings:** personal context and preferred corrections fed into prompts; model readiness with CLI guidance for custom model paths
- **App bundle:** double-clickable `CaptainsLog.app`

## Pipeline Steps

Each step writes to its own folder and never modifies previous output. The pipeline is fully resumable: if interrupted, `cl resume <stem>` detects the earliest missing step and continues from there.

### Step 1 — Record (`audio/`)

The CLI records mono AAC/M4A at 44.1 kHz until you press Ctrl+C. The file is named `YYYY-MM-DD-HHMM.m4a` from the current time. Passing `--input` copies an existing audio file instead. The timestamp stem (`YYYY-MM-DD-HHMM`) is the primary key that links all subsequent files together.

### Step 2 — Transcribe (`.pipeline/01-transcribed/`)

[WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) runs `whisper-large-v2` on-device via CoreML. Language is auto-detected (or forced with `--language`). The raw transcript is written as `{stem}.md` — unedited, disfluencies and all.

### Step 3 — Cleanup (`.pipeline/02-logs/`)

Qwen receives the raw transcript and a system prompt (`prompts/cleanup.md`) that instructs it to remove speech disfluencies ("uh", "um", false starts, repetitions), fix spoken-grammar issues, and break the text into logical paragraphs — while preserving the speaker's language, word choices, and thought order. Two optional personal-context sections are injected from config: speaker background (so Qwen can disambiguate domain terms) and name/term corrections (for Whisper mis-transcriptions of proper nouns). The output is written as `.pipeline/02-logs/{stem}.md`. Qwen's `<thinking>` chain-of-thought is stripped before saving.

### Step 4 — Categorize (`.pipeline/03-category/`)

Qwen reads the complete cleaned memo and selects exactly one category: `personal`, `professional`, or `side_project`. It chooses the category that accounts for most of the memo, without extracting or rewriting any content. The choice is stored in `.pipeline/03-category/{stem}.json`.

Side-project content gets its own final folder instead of being folded into personal or professional output.

### Step 5 — Rename (`.pipeline/04-rename/`)

Qwen reads the full cleaned memo and generates a descriptive kebab-case filename in English, regardless of the entry's language: `YYYY-MM-DD-topic-one-topic-two.md`. The slug captures 2–4 distinctive topics (not generic words like "update"). Temperature is lowered to 0.3 and the output format is constrained by the prompt.

Canonical rename writes:
- `.pipeline/04-rename/{slug}.md` — the cleaned full memo under its new human-readable name.
- `.pipeline/04-rename/{stem}.slug.txt` — a sidecar marker that permanently links the timestamp stem to the canonical slug.


### Step 6 — Enrich (`logs/`)

Qwen reads each renamed document and extracts structured YAML metadata via `prompts/enrich.md`: `date`, `categories`, `tags`, `persons`, `projects`, `companies`, `entities`, and a 3–5 sentence `summary`. All metadata is in English even when the log is in another language.

The full enriched memo is written once to `logs/personal/`, `logs/professional/`, or `logs/side-project/`, according to its category.

```
logs/professional/2026-04-18-team-retro-holiday.md
───────────────────────────────────────────
---
date: "2026-04-18"
categories:
  - work
tags:
  - holiday
  - retro
  - team
persons:
  - Alice de Vries
projects:
  - FinanceHub
summary: "..."
---

[cleaned log text]
```

## SwiftUI Application

The app uses a Logs workspace for browsing and processing voice entries. It includes date-grouped entries, summaries and tags, keyword/semantic search, a selected-entry detail view, and a fixed recording dock with microphone selection and level metering. Processing and recovery controls include pause/resume, retry, reprocess, Finder reveal, and Trash-based deletion.

On first launch, choose a data folder and allow the app to download its local models. Settings manage storage, personal context, name corrections, audio input, and model readiness. Model identifiers and custom model paths are managed through the `cl config` commands.

**UI rule (non-negotiable): no layout shifts — ever.** Elements must never move because siblings appear, disappear, or change size. Use `.opacity(condition ? 1 : 0)` + `.allowsHitTesting(condition)` instead of `if condition { View() }` for any element whose presence would shift surrounding content. Fixed-size containers are preferred over variable-length content.

## Configuration

The config file lives at `~/Library/Application Support/CaptainsLog/config.json`:

- **Data directory** — customizable output location
- **Whisper model** — model selection for transcription
- **Qwen model ID** — LLM model selection (default: Qwen 3.5 9B 4-bit)
- **Qwen model folder** — custom model source path
- **Personal context** — speaker background for better disambiguation
- **Corrections** — name/term corrections for transcription errors

Managed via CLI: `cl config show` and `cl config set <key> <value>`.

**Architectural rule (non-negotiable): config lives in a file, not in UI state.** Every non-UI feature must be testable from the CLI. The config file is managed by `CaptainsLogConfig` in `Sources/CaptainsLogCore/Config.swift`.

## Evaluation

Skill-driven evaluation suites verify each pipeline stage by comparing generated output against ground truth. Evaluations are systematic, reproducible, and self-contained in the repo.

### Evaluation skills

Each stage has a `.claude/skills/<stage>-eval/SKILL.md` that defines the agent workflow:

- **transcription-eval** — compare Whisper output to ground truth transcriptions
- **cleanup-eval** — compare LLM-cleaned text to expected polished output
- **filename-eval** — validate generated filenames against expected filenames
- **enrich-eval** — compare generated YAML frontmatter to expected frontmatter

Run evaluations by invoking the appropriate skill. Generated outputs and reports are written to `eval/<stage>/generated/` and `eval/<stage>/reports/` respectively.

### Evaluation principles

- **Focus on concrete changes, not scoring.** Reports document what actually changed: which words, values, or structures differ; what was missing; what was added (including hallucinations); and a qualitative assessment of meaning preservation.
- **Content over cosmetic.** Prioritize errors by semantic impact:
  - **Critical:** Missing or added content that changes meaning.
  - **High:** Substitutions that alter semantics.
  - **Medium:** Named entities (usually recoverable from context).
  - **Low:** Formatting, style, accents.
- **Human-in-the-loop.** Skills generate structured comparison reports; the final quality judgment is made by the person (or agent) running the evaluation.

### Test fixtures

The `eval/` directory contains skill-driven evaluation suites for each pipeline stage:

```
eval/
├── transcribe/audio/     — Sample recordings for transcription testing
├── cleanup/input/        — Raw transcripts for cleanup testing
├── filename/input/       — Entry texts for filename generation testing
├── enrich/input/         — Entry texts for metadata extraction testing
```

Each stage also has `expected/` (ground truth) and `generated/` / `reports/` (runtime outputs, git-ignored).

**Privacy rule:** never substitute recordings from the user's Obsidian / CaptainsLog folders for these fixtures. Sensitive real recordings are off-limits for tests, evaluations, repros, or debugging. Use only the repo fixtures in `eval/`.

### Quick CLI tests

Run individual stages without invoking a full evaluation skill:

```bash
# Transcription
swift run cl transcribe eval/transcribe/audio/alle-mensen-zijn-sterfelijk.m4a --output ./tmp/test.md

# Full pipeline
swift run cl pipeline --input eval/transcribe/audio/world-war-z.m4a --data-dir ./tmp/test-run

# Individual stages (use eval/<stage>/input/ files)
swift run cl cleanup --input eval/cleanup/input/<case>.md --output ./tmp/out.md
swift run cl filename --input eval/filename/input/<case>.md --date 2025-01-15
swift run cl enrich --input eval/enrich/input/<case>.md --output ./tmp/out.md --date 2025-01-15
```

For pipeline and transcription verification, prefer the natural-speech fixture `eval/transcribe/audio/2025-01-14 side project.m4a` over book excerpts like `world-war-z.m4a`.

**Performance rule:** never run multiple inference tasks in parallel. All ML runs on-device via llama.cpp + WhisperKit on Apple Silicon. Running WhisperKit transcription plus multiple Qwen LLM inferences simultaneously causes GPU memory contention and freezes the machine. Run evaluation suites sequentially, or use the `pipeline` command, which loads Qwen once and chains cleanup → filename → enrich.

### End-to-end verification

After any dependency upgrade, new feature, or significant refactor, run:

```bash
swift build
swift run run-tests
swift run cl pipeline --input eval/transcribe/audio/2025-01-14\ side\ project.m4a --data-dir ./tmp/cl-test
```

Then run all evaluation suites to validate output quality:

```bash
# transcription-eval, cleanup-eval, filename-eval, enrich-eval
```

**Quick smoke test:** After build or dependency changes, run **`filename-eval`** alone to verify the LLM pipeline is functional without waiting for the full transcription and multi-stage suites. It is the fastest evaluation and confirms Qwen loading, prompt rendering, and output formatting are all working.

Skipping evaluation suites is not allowed: they are the final quality gate for output quality.

## Development & Testing Guidelines

These rules apply to everyone working on the codebase.

### Testing

- **Always test your own work.** Run the affected `cl` subcommand against a real input and verify output before reporting done. Never ask someone else to test something untested.
- **Reproduce in CLI before guessing.** If a SwiftUI bug touches core pipeline logic, reproduce it with `cl` first — don't debug through the UI when the pipeline is CLI-testable.
- **No Xcode dependency.** Everything must work from the command line. Never depend on the Xcode IDE for building, running, or testing. Use `swift build`, `swift run run-tests`, and `scripts/test-coverage.sh`.
- **Verify with pipeline after changes.** After any dependency upgrade, new feature, or significant change, run the full pipeline to verify everything still works.

### Inference and model usage

- **No wrappers.** Use llama.cpp and WhisperKit directly. Never use Ollama or other hosted inference wrappers.
- **Model loading is expensive (~15 s).** Load Qwen once and pass the container to cleanup, filename, and enrich stages. Never load inside a loop.
- **Never run multiple inference tasks in parallel.** All ML runs on-device via llama.cpp + WhisperKit on Apple Silicon. Running WhisperKit transcription plus multiple Qwen LLM inferences simultaneously causes GPU memory contention and freezes the machine.

### Prompt and pipeline behavior

- **No post-processing.** Never add regex, string replace, or any transformation after LLM output. LLM behavior is controlled exclusively through prompts.
- **Use XML prompt structure.** In every LLM prompt, separate instructions, context, examples, and the actual input with explicit XML-style tags such as `<instructions>`, `<context>`, and `<transcript>` / `<log_entry>`. Keep prompts minimal, but make the role of each section unambiguous.
- **Pipeline steps don't mutate previous stages.** Each step writes to its own folder (`audio/`, `.pipeline/01-transcribed/`, `.pipeline/02-logs/`, `.pipeline/03-category/`, `.pipeline/04-rename/`, `logs/`).

### Privacy

- **Never use Obsidian recordings for testing.** Actual recordings from the user's Obsidian / CaptainsLog folders are sensitive and must never be opened, transcribed, copied, or used for tests, evaluations, repros, or debugging.
- **Use only repo fixtures for audio tests.** For pipeline and transcription verification, use recordings from `eval/transcribe/audio/` only.
- The `processed/` directory and the user's Obsidian / CaptainsLog folders contain personal data. Never read from them for testing or evaluation — use `eval/` test cases instead.

### Working principles

- **Think before coding.** State assumptions explicitly. If multiple interpretations exist, surface them — don't pick silently. If something is unclear, stop and ask.
- **Simplicity first.** Minimum code that solves the problem. No speculative features, no abstractions for single-use code, no error handling for impossible scenarios. If 200 lines could be 50, rewrite.
- **Surgical changes.** Every changed line should trace to the request. Don't "improve" adjacent code, refactor what isn't broken, or delete pre-existing dead code unless asked. Remove only the orphans your own changes created.
- **Goal-driven execution.** Turn tasks into verifiable goals: "fix the bug" → "write a failing test, then make it pass". For multi-step work, state a brief plan with a verify-step per item.
- **Close the feedback loop first.** Before solving, build a way to observe. Prefer a small CLI or repro script over relying on someone else to re-run things. If your only feedback is "the user will tell me," stop and build the loop.
- **Plan in small pieces.** One question at a time, not big upfront dumps.

## Privacy

- **No cloud APIs** — all ML runs on-device via llama.cpp
- **Apple Silicon optimized** — Metal shaders for GPU acceleration
- **Private data stays local** — recordings and transcripts never leave the device

## FAQ

**Q: You're using Chinese models (Qwen) for this. How do I know that's safe? Will it send my private memos to China?**

**A:**
1. **Models run entirely on-device** — Qwen runs locally via llama.cpp on your Mac's Apple Silicon GPU. No data ever leaves your device during processing.

2. **Model weights are just data** — The `.gguf` format (used by llama.cpp) is a data-only format. It stores tensor weights as raw numbers, not executable code. The weights cannot "phone home," execute commands, or do anything other than be multiplied in matrix operations.

3. **No network connection during inference** — When you process a voice memo, the app makes zero network requests. Everything happens locally on your Mac.

The "Chinese model" aspect is a red herring. Whether the weights came from Alibaba, OpenAI, or Mistral — once loaded on your Mac, they're just numbers being crunched locally by llama.cpp. The real privacy risk would be if the app sent your data to cloud APIs (which it doesn't).

## Notes

- Qwen takes ~15 s to load — it is loaded once per pipeline run and passed through cleanup → filename → enrich.
- `NSApp.setActivationPolicy(.regular)` must be called in `App.init`; without it the SwiftUI window can't take focus when launched as a `.app` bundle.

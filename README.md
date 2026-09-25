# CaptainsLog

CaptainsLog turns voice memos into searchable log entries. Recording, transcription, and text processing run locally on Apple Silicon; no cloud APIs are used.

## Install

The Homebrew cask supports Apple Silicon Macs running macOS 26 or later. The app is ad-hoc signed and not notarized. The cask removes macOS quarantine from the app bundle, so install it only from a tap you trust. The source repository and release are private while the project is being prepared for publication; these commands will work after publication:

```sh
brew tap vnglst/captainslog https://github.com/vnglst/CaptainsLog.git
brew install --cask vnglst/captainslog/captainslog
```

The first launch downloads the on-device models and needs an internet connection. The models use several gigabytes of storage. After download, recording and inference run locally.

## Build

Requirements: Apple Silicon, macOS 26 or later, Swift 6.2+, and `brew install llama.cpp` for source builds. Xcode IDE is not required.

```sh
swift build
./scripts/build-app.sh
```

The build script creates `dist/CaptainsLog.app` and a versioned ZIP archive. Open the app with:

```sh
open dist/CaptainsLog.app
```

For a safe development demo, run `swift run CaptainsLogApp`. It creates an isolated TNG-themed data copy under `tmp/demo-runtime/` from synthetic notes and locally synthesized audio in [`demo/`](./demo/). The demo copy persists between launches; move it aside to restore the original demo.

## Use

The CLI can record a memo and process it, or process an existing audio file:

```sh
swift run cl pipeline
swift run cl pipeline --input <audio.m4a>
swift run cl resume <stem>
swift run cl list
swift run cl search "project architecture"
```

The resumable pipeline records audio, transcribes it with WhisperKit/CoreML, cleans and categorizes the text, generates a filename, and adds searchable metadata. Intermediate files live under `.pipeline/`; completed entries are saved to `logs/`. Use `swift run cl --help` for other commands, including configuration and individual pipeline stages.

Transcription uses Whisper Large-v2. Cleanup, categorization, filenames, and metadata use Qwen 3.5 9B 4-bit through llama.cpp. Semantic search downloads the multilingual-e5-small embedding model on first use.

## Documentation

- [Troubleshooting](./docs/TROUBLESHOOTING.md)
- [Project plan](./docs/PLAN.md)
- [Publishing plan](./docs/PUBLISHING-PLAN.md)
- [Evaluation fixtures and scripts](./docs/tng-eval/README.md)
- [Design references](./design/README.md)
- [Architecture decisions](./docs/)

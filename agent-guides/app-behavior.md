# App behavior and CLI reference

Agent reference; read the relevant sections for the work at hand.
See [repository instructions](../AGENTS.md) for policy.

## Updates, removal and model setup

The installed app checks for updates at launch and once every 24 hours while open.
Available updates install automatically once recording, processing, and model
setup finish, then the app restarts. Settings → Updates lets you disable automatic
checks or automatic installation, check manually, and install an available update.
After a manual install, use the Restart app button. Updates use the same
Homebrew cask and checksum verification as the initial install; checks refresh
Homebrew metadata over the network without sending recordings or notes.

You can also check or update through the CLI (quit the app before installing):

```sh
cl update --check
cl update
cl config set automaticUpdates false
cl config set automaticUpdateChecks false
```

Or update directly with:

```sh
brew update
brew upgrade --cask captainslog
```

To uninstall CaptainsLog and move its downloaded models to the Trash while keeping your logs and configuration:

```sh
brew uninstall --cask --zap captainslog
```

Empty the Trash to reclaim the model storage. Models in folders you selected yourself are left untouched.

The first launch downloads the on-device models and needs an internet connection. The models use several gigabytes of storage. After download, recording and inference run locally. Settings → Models shows disk usage; `cl models` shows the same information in the CLI. Missing speech and text models download automatically at startup, with progress shown immediately. Smart search downloads its model on first use.

## Recording and processing

### Import recordings

M4A and QuickTime audio (`.mov`, `.qt` and `.qta`) files in the configured `audio/` folder are picked up by the app. Imported files keep their original extension. The CLI also accepts WAV and MP3 audio.

### Context and categories

Context contains personal background and a correction list for names and terms. Qwen uses that list to correct misrecognized words and help make the final text more accurate. Changes save automatically and apply to future processing.

Context and initial setup let you choose categories for future processing. Removing one keeps its existing folders and logs. The category menu beside search filters Logs and search results; all categories are initially selected.

### Pause, resume and reprocess

Pause stops processing and clears waiting requests. Resume continues from saved progress. Requests made while processing is still stopping wait until it is ready.

Reprocess deletes the generated results for a recording and starts again with your current settings. The original audio is kept. Pausing or quitting after requesting Reprocess does not restore the deleted results.

Quit stops processing and finishes saving any recording. Unfinished work remains available to resume later.

Processing keeps your Mac awake, including with the screen locked, while allowing the display to sleep. Keep the Mac connected to power with the lid open for an overnight run; lid closure and deliberate system sleep can still suspend processing. Normal idle sleep resumes after processing stops.

### Your files and models

Completed notes are plain Markdown files in `logs/` within your chosen data folder. Intermediate results are kept separately in `.pipeline/`.

Settings lets you delete all intermediate results, finished logs and reprocessing backups while keeping original audio and settings. Return to Logs to process all unprocessed recordings with the current settings.

Transcription uses Whisper Large-v2. Qwen 3.5 9B 4-bit cleans up and organizes the notes. Smart search uses multilingual-e5-small, downloaded on first use.

## Processing implementation

The resumable pipeline records audio, transcribes it with WhisperKit/CoreML, cleans and categorizes the text, generates a filename, and adds searchable metadata.

Quit cancels active work and finalizes any recording. If a native model call cannot
stop within two seconds, the app exits after the recording writer closes, preserving
original audio and saved checkpoints. The unfinished stage remains pending.

Pause cancels the active worker and clears queued requests. Resume, Process pending,
Reprocess and completed recordings share one serial queue; requests made while
native cancellation finishes show as queued and run afterwards. Resume detects the
latest saved stage when its turn starts. Reprocess immediately deletes derived outputs
and queues fresh processing, including when models must download. A later Pause or
Quit discards waiting processing but keeps the outputs deleted.

Transcription uses Whisper Large-v2. Cleanup, categorization, filenames, and metadata use Qwen 3.5 9B 4-bit through llama.cpp. Semantic search downloads the multilingual-e5-small embedding model on first use.

Source builds and demo mode do not run automatic update checks.

## CLI configuration

Choose categories through the CLI with:

```sh
cl config set categories "personal,professional,research"
cl config set categories unset  # Restore built-in defaults
```

Use `cl --help` for other commands, including configuration and individual processing stages.

## Bundled licenses

The release app includes the project license, third-party notices and bundled
component license texts in its Resources folder.

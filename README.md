# CaptainsLog

CaptainsLog turns your spoken thoughts into clear, organized, searchable notes. Record your week, capture an idea, or practice a talk. It transcribes your recordings, cleans up the text, and sorts your notes into categories you choose—without uploading your recordings or notes.

It’s a free, open-source Mac app inspired by the captain’s logs in Star Trek.

Recording, transcription, and text processing run locally on Apple Silicon; no cloud APIs are used.

## Install

The Homebrew cask supports Apple Silicon Macs running macOS 26 or later. Homebrew adds the CaptainsLog tap automatically when you install. The app is ad-hoc signed and not notarized. The cask removes macOS quarantine from the app bundle, so install it only if you trust this project:

```sh
brew install --cask vnglst/tap/captainslog
```

The full pipeline was tested on an M4 MacBook Air with 16 GB of unified memory.
Use that configuration as the recommended minimum for the default local
models.

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

## Use

1. Open CaptainsLog and choose where to save your recordings and notes, along with the categories you want to use.
2. Start a recording using the record button. You can pause and resume while recording.
3. Stop recording when you are done. CaptainsLog transcribes the audio, cleans up the text, sorts the note into a category, and adds a title, summary and tags.
4. Open a completed note to read it, play the original audio or copy the cleaned transcription. Search Logs to find notes by words or meaning.

Review important names, facts and wording before relying on a generated note. Your original audio is kept alongside the processed text.

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

## Command-line use

The Homebrew installation includes `cl`, which works independently of the Mac app:

```sh
cl pipeline                         # Record and process a memo
cl pipeline --input recording.m4a    # Process an existing audio file
cl resume <stem>                    # Continue one unfinished recording
cl list
cl search "project architecture"
# Quit the app, then delete generated outputs, keeping audio and settings:
cl delete-outputs --confirm
# Process all pending recordings with current settings:
cl resume
```

Choose categories through the CLI with:

```sh
cl config set categories "personal,professional,research"
cl config set categories unset  # Restore built-in defaults
```

Use `cl --help` for other commands, including configuration and individual processing stages.

## More information

- [Changelog and release history](CHANGELOG.md)
- [Technical overview](https://captainslog.koenvangilst.nl/technical.html)
- [Report a problem or suggest an improvement](https://github.com/vnglst/CaptainsLog/issues)
- [Contributor guide: build from source, demos, testing and releases](CONTRIBUTING.md)

## License

CaptainsLog’s original source code is licensed under the [MIT license](LICENSE).
Third-party software, model weights and example content retain their own
licenses and rights; see [Third-party notices](THIRD-PARTY-NOTICES.md). The release
app includes the project license, third-party notices and bundled component license
texts in its Resources folder.

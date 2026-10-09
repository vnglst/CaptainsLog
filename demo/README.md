# TNG demo data

These are synthetic voice-memo entries in the TNG setting used for product demonstrations. Evaluation scripts use separate fixtures under `eval/`. They are short enough to browse during a product video and varied enough to exercise dates, categories, summaries, tags, detail reading, and search.

`entries/` contains canonical enriched Markdown for seven finished notes. The debug app seeds the other pipeline artifacts in its ignored working copy so the normal entry discovery reports them as completed. `audio/` contains matching synthesized audio for those notes and two short pending memos, generated from the adjacent script using macOS `say` and `afconvert`. The pending memo can be resumed through the real pipeline when the local models are available.

Run `make dev` from the repository. The app prepares `tmp/demo-runtime/data/` and a separate config there. Changes made in the app affect the working copy. Quit the app and move `tmp/demo-runtime/` aside to reset it.

`audio/2026-09-24-1750.qta` is a short synthesized QuickTime audio example. Its adjacent text file contains the spoken words. It was generated with macOS `say` and encoded as AAC in a QuickTime container using FFmpeg. The debug app copies it alongside the M4A files as a pending memo.

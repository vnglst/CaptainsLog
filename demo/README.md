# TNG demo data

These are synthetic voice-memo entries in the TNG setting used by the evaluation scripts. They are short enough to browse during a product video and varied enough to exercise dates, categories, summaries, tags, detail reading, and search.

`entries/` contains canonical enriched Markdown for seven finished notes. The debug app seeds the other pipeline artifacts in its ignored working copy so the normal entry discovery reports them as completed. `audio/` contains matching synthesized audio for those notes and one short pending memo, generated from the adjacent script using macOS `say` and `afconvert`. The pending memo can be resumed through the real pipeline when the local models are available.

Run `swift run CaptainsLogApp` from the repository. The app prepares `tmp/demo-runtime/data/` and a separate config there. Changes made in the app affect the working copy. Quit the app and move `tmp/demo-runtime/` aside to reset it.

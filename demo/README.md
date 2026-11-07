# Development demo

The demo and native UI harness use the same library in
[`eval/demo-library.json`](../eval/demo-library.json). It references the canonical
evaluation audio, transcripts, cleaned text and enriched metadata under `eval/`;
there are no separate demo recordings or notes.

The same manifest seeds Context with a fictional Enterprise engineering officer's
profile and TNG name and technical-term corrections from `eval/demo-context/`.
Categories retain the app's personal, professional and side-project defaults;
microphones, model storage and update availability reflect the running app.
Missing context files are added to existing demo copies; saved edits are retained.

Run `make dev`. The debug app copies those fixtures into
`tmp/demo-runtime-eval/data/` with a separate config. Completed examples include the
Dutch Enterprise log and work-week review; the remaining recordings and a
transcript are pending. Changes affect only this working copy. Quit and move
`tmp/demo-runtime-eval/` aside to reset it. The previous `tmp/demo-runtime/` copy is
left untouched.

`make ui` uses a fresh temporary copy of the same library and can show simulated
UI states without downloading models or discovering recordings. `make dev` uses
the real processing pipeline and prepared local models. Explicit
`CAPTAINS_LOG_CONFIG_PATH` bypasses demo seeding for isolated checks. Demo browsing
and simulated UI states do not establish successful inference.

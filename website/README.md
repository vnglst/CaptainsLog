# CaptainsLog website

A static landing page styled after the Logs design system and the ImageGen concept in `design/`. The content presents CaptainsLog as a spoken journal for life, work, and side projects, with on-device processing and searchable Markdown logs.

Open `index.html` directly, or preview from the repository root:

```sh
python3 -m http.server 8765 --directory website
```

Deploy the contents of `website/` to a static host. There is no build step, package dependency, external font, analytics, or inference API. HTML, CSS, and JavaScript live in `index.html`.

## Add your app recording

The walkthrough has a fixed 16:9 placeholder and makes no request for missing media. In the `walkthrough` object near the bottom of `index.html`, set:

```js
const walkthrough = {
  src: 'assets/app-walkthrough.mp4',
  poster: 'assets/app-walkthrough.jpg',
  captions: 'assets/app-walkthrough.vtt',
  description: 'CaptainsLog: recording a voice log, processing it locally, and searching completed entries.'
};
```

Place those files in `assets/`. A poster and captions are optional (`null` omits either); captions are recommended for accessibility. The video and descriptive caption automatically replace the placeholder. Adjust the description to what the recording actually shows. Use a static host with HTTP byte-range support for video seeking.

The owner will create the recordings. The earlier synthetic sample audio and illustrative walkthrough have been removed. No recordings ship with the page until the owner adds the final files.

The hero is a selectable HTML illustration, explicitly labeled as such. It uses verbatim synthetic fixture text from `eval/categorize/input/{side-project-voice-app,professional-release-planning,personal-weekend}.md`, split into paragraphs. Titles, tags, and relative dates are illustrative. It is not captured native UI or measured model output. No app audio playback is advertised: it is tracked in the [backlog](../backlog/tasks/), with workspace context in [Logs interface details](../docs/PLAN-004-logs-implementation.md).

## Content sources

- `README.md`: supported platform, install command, first-launch downloads, processing stages, CLI, and current models.
- `design/logs/DESIGN-SYSTEM.md`: charcoal surfaces, off-white type, amber recording controls, understated native styling, and voice-first personal logs.
- `prompts/cleanup.md` and `prompts/enrich.md`: readable log entries and metadata; the captain’s-log inspiration is described in the repository examples.
- `docs/0005-use-libllama-c-api-for-text-inference.md`: shared local app/CLI inference and hybrid keyword/semantic search. Search returns entries and excerpts, not generated answers. Markdown logs are canonical; the index is disposable.
- `docs/0006-bundle-llama-runtime-in-app.md` and `docs/0009-distribute-app-and-cli-through-homebrew.md`: app and CLI installation together; no separate inference service needed.
- `docs/0008-self-signed-macos-distribution.md`: signing, notarization, and quarantine trust notice alongside install instructions.
- `docs/0012-homebrew-auto-updates.md`: network behavior and configurable update checks.
- `docs/testing-verification.md`: review limits of generated text; retained source audio/stage outputs support comparison.
- `docs/0013-isolated-tng-demo-data.md`: the “Logs” journal concept and distinction between demo presentation and actual app captures.

The website does not promise knowledge graphs, automatic Obsidian synchronization, native saved-audio playback, or collections. Obsidian is mentioned only as an example of a tool that reads Markdown. Review current docs before changing product claims. ImageGen output is a design reference; verified HTML copy is authoritative.

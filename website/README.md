# CaptainsLog website

A static landing page styled after the Logs design system and the ImageGen concept in `design/`. The content presents CaptainsLog as a spoken journal for life, work, and side projects, with on-device processing and searchable Markdown logs.

Open `index.html` directly, or preview from the repository root:

```sh
make website
```

The preview uses the repository’s Swift tooling. Open <http://127.0.0.1:8765> and press Ctrl+C in the terminal when you’re done. To use another port, run `make website PORT=8766`.

Deploy the contents of `website/` to a static host. There is no build step, package dependency, external font, or inference API. HTML, CSS, and JavaScript live in `index.html`.

Website visits use the same self-hosted Plausible script and `koenvangilst.nl` dashboard as the main site. Filter by hostname `captainslog.koenvangilst.nl` to see app website traffic. The script ignores localhost previews. This tracking applies only to the website; the Mac app has no analytics.

## Add your app recording

The hero walkthrough has a 16:9 placeholder and makes no request for missing media. In the `walkthrough` object near the bottom of `index.html`, set:

```js
const walkthrough = {
  src: 'assets/app-walkthrough.mp4',
  poster: 'assets/app-walkthrough.jpg',
  captions: 'assets/app-walkthrough.vtt',
  description: 'CaptainsLog: recording a voice log, processing it locally, and searching completed entries.'
};
```

Place those files in `assets/`. A poster and captions are optional (`null` omits either); captions are recommended for accessibility. The video and descriptive caption automatically replace the placeholder. Adjust the description to what the recording actually shows. Use a static host with HTTP byte-range support for video seeking.

## Content sources

- `README.md`: supported platform, install command, first-launch downloads, processing stages, CLI, and current models.
- `design/logs/DESIGN-SYSTEM.md`: charcoal surfaces, off-white type, amber recording controls, understated native styling, and voice-first personal logs.
- `prompts/cleanup.md` and `prompts/enrich.md`: readable log entries and metadata; the captain’s-log inspiration is described in the repository examples.
- `docs/0005-use-libllama-c-api-for-text-inference.md`: shared local app/CLI inference and hybrid keyword/semantic search. Search returns entries and excerpts, not generated answers. Markdown logs are canonical; the index is disposable.
- `docs/0006-bundle-llama-runtime-in-app.md` and `docs/0009-distribute-app-and-cli-through-homebrew.md`: app and CLI installation together; no separate inference service needed.
- `docs/0008-self-signed-macos-distribution.md`: signing, notarization, and quarantine trust notice alongside install instructions.
- `docs/0012-homebrew-auto-updates.md`: network behavior and configurable update checks.
- `README.md` semantic-review guidance: review limits of generated text; retained source audio/stage outputs support comparison.
- `docs/0013-isolated-tng-demo-data.md`: the “Logs” journal concept and distinction between demo presentation and actual app captures.

The website does not promise knowledge graphs, automatic Obsidian synchronization, native saved-audio playback, or collections. Obsidian is mentioned only as an example of a tool that reads Markdown. Review current docs before changing product claims. ImageGen output is a design reference; verified HTML copy is authoritative.

# CaptainsLog website

A static website styled after the Logs design system and the ImageGen concept in `design/`. The content presents CaptainsLog as a spoken journal for life, work, and side projects, with on-device processing and searchable Markdown logs.

Open `index.html` directly, or preview from the repository root:

```sh
make website
```

The preview uses the repository’s Swift tooling. Open <http://127.0.0.1:8765> and press Ctrl+C in the terminal when you’re done. To use another port, run `make website PORT=8766`.

Deploy the contents of `website/` to a static host. There is no build step, package dependency, external font, or inference API. The main page is `index.html`; `technical.html` explains the architecture, pipeline checkpoints, processing ownership and search with inline SVG diagrams. Both pages contain their own styles and need no diagram rendering dependency.

## Publishing

The public website at <https://captainslog.koenvangilst.nl/> runs on shared static hosting managed in `vnglst/static-sites`. Its Dockerfile selects a specific CaptainsLog commit and copies `website/` into the shared Nginx image. A push to the hosting repository’s `main` triggers deployment through Coolify on Hetzner.

After pushing website changes here, the selected source commit must also advance in `static-sites`. A scheduled updater checks configured source repositories every five minutes; repositories outside its list need a manual pin update or inclusion in that updater. A source push alone does not confirm publication. Verify the live page and its assets after deployment.

Infrastructure configuration and the operational procedure live in the sibling `coolify-agent` repository: [static hosting runbook](https://github.com/vnglst/coolify-agent/blob/main/features/static-sites.md).

Website visits use the same self-hosted Plausible script and `koenvangilst.nl` dashboard as the main site. Filter by hostname `captainslog.koenvangilst.nl` to see app website traffic. The script ignores localhost previews. This tracking applies only to the website; the Mac app has no analytics.

## App walkthrough

The hero embeds the demo video hosted at <https://files.koenvangilst.nl/u/hV5EMz.mp4> with native playback controls and inline playback on mobile. It is a silent recording using demo data. The player preserves the recording’s proportions and fits the viewport width and height without cropping the app. Proportional corner clipping follows the captured macOS window and hides the blue desktop corners at every player size.

To replace the recording, update the video source, fallback link, dimensions and descriptive caption in `index.html`, and refresh `assets/app-walkthrough.jpg`. Adjust the CSS aspect ratio if the new recording has different proportions. The video host must support HTTP byte ranges for seeking. There is no autoplay; only metadata loads before playback.

## Content sources

- `README.md`: supported platform, install command, first-launch downloads, processing stages, CLI, and current models.
- `design/DESIGN-SYSTEM.md`: charcoal surfaces, off-white type, amber recording controls, understated native styling, and voice-first personal logs.
- `Resources/prompts/cleanup.md` and `Resources/prompts/enrich.md`: readable log entries and metadata; the captain’s-log inspiration is described in the repository examples.
- `docs/0005-use-libllama-c-api-for-text-inference.md`: shared local app/CLI inference and hybrid keyword/semantic search. Search returns entries and excerpts, not generated answers. Markdown logs are canonical; the index is disposable.
- `docs/0006-bundle-llama-runtime-in-app.md` and `docs/0009-distribute-app-and-cli-through-homebrew.md`: app and CLI installation together; no separate inference service needed.
- `docs/0008-self-signed-macos-distribution.md`: signing, notarization, and quarantine trust notice alongside install instructions.
- `docs/0012-homebrew-auto-updates.md`: network behavior and configurable update checks.
- `README.md` semantic-review guidance: review limits of generated text; retained source audio/stage outputs support comparison.
- `docs/0013-isolated-tng-demo-data.md`: the “Logs” journal concept and distinction between demo presentation and actual app captures.

The website does not promise knowledge graphs, automatic Obsidian synchronization, native saved-audio playback, or collections. Obsidian is mentioned only as an example of a tool that reads Markdown. Review current docs before changing product claims. ImageGen output is a design reference; verified HTML copy is authoritative.

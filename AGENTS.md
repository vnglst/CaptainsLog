# Repository Instructions

Read `README.md` before working here. Follow its product requirements, build instructions, and design decisions.

## Development

- Think through assumptions before changing code. Prefer the smallest change that solves the request; avoid unrelated refactors.
- Keep the CLI usable without Xcode. Use Swift and command-line tools for builds and tests.
- Test code changes with the affected CLI command and a repository fixture. Reproduce pipeline issues in the CLI before debugging through the UI.
- After dependency upgrades, new features, or significant refactors, run `swift build`, `swift run run-tests`, and the full pipeline on a fixture. Evaluation suites are the quality gate; run them sequentially. For a quick LLM smoke check, run `filename-eval`.
- Never run multiple inference tasks in parallel. WhisperKit and llama.cpp share limited on-device GPU memory. Load Qwen once per pipeline run and reuse it across stages.

## Product and architecture requirements

- All inference runs on-device through WhisperKit/CoreML and llama.cpp. Do not introduce cloud APIs, Ollama, or other inference wrappers.
- Prompts control model behavior. Do not post-process LLM output with regex, replacements, or other transformations. Structure prompts with clear XML-style tags such as `<instructions>`, `<context>`, and `<transcript>`.
- Pipeline stages write to their own directories and never mutate earlier-stage output.
- Configuration belongs in `CaptainsLogConfig` and its config file, not UI state. Non-UI features must be usable and testable from the CLI.
- SwiftUI must not shift surrounding layout when views appear or disappear. For conditional elements that would move siblings, keep their space with `.opacity(condition ? 1 : 0)` and `.allowsHitTesting(condition)`; prefer fixed-size containers.

## Privacy

- Never read, copy, or use personal recordings or data from `processed/`, Obsidian, or CaptainsLog data folders for tests, evaluations, reproductions, or debugging.
- Use only repository fixtures under `eval/`, including `eval/transcribe/audio/` for audio tests. Treat evaluation inputs as synthetic fixtures; do not replace them with personal recordings.

## Evaluations

Stage-specific evaluation workflows live in `skills/<stage>-eval/SKILL.md` for transcription, cleanup, filename, and enrichment. Use the relevant workflow when evaluating output. Reports should describe concrete changes and semantic impact, including missing or added content and hallucinations; scores alone are not enough. Human review makes the final quality judgment.

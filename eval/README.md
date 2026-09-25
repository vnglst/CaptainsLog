# Evaluation Test Cases

Skill-driven evaluation suites for verifying each pipeline stage.

## Structure

Each stage follows the same folder layout:

```
eval/<stage>/
├── input/          — Test inputs (audio, raw transcripts, etc.)
├── expected/       — Ground truth expected outputs
├── generated/      — Model outputs (ignored by git)
└── reports/        — Agent-written evaluation reports (ignored by git)
```

## Stages

- **transcribe/** — Audio fixtures and expected transcriptions
- **cleanup/** — Raw transcripts and expected polished text
- **filename/** — Entry texts and expected filenames
- **enrich/** — Entry texts and expected YAML frontmatter

The `2025-01-14 side project` recording flows through all four stages as a cross-stage integration test.

## Usage

Evaluations are run by invoking the corresponding skill (see `.claude/skills/<stage>-eval/SKILL.md`).

Quick CLI tests:

```bash
# Transcription
swift run cl transcribe eval/transcribe/audio/alle-mensen-zijn-sterfelijk.m4a --output ./tmp/test.md

# Full pipeline
swift run cl pipeline --input eval/transcribe/audio/world-war-z.m4a --data-dir ./tmp/test-run

# Individual stages (use eval/<stage>/input/ files)
swift run cl cleanup --input eval/cleanup/input/<case>.md --output ./tmp/out.md
swift run cl filename --input eval/filename/input/<case>.md --date 2025-01-15
swift run cl enrich --input eval/enrich/input/<case>.md --output ./tmp/out.md --date 2025-01-15
```

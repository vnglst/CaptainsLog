# CLI End-to-End and Evaluation Report

**Date:** 2026-09-26  
**Host:** Apple Silicon macOS; Swift Package Manager / Command Line Tools  
**Quality status:** Evaluation review found meaning-changing transcription issues. This report records evidence; it does not claim human quality approval.

## Isolation and commands

All runs used only synthetic inputs under `eval/`. The full pipeline used an isolated config and data directory under `tmp/`, with the existing local `openai_whisper-large-v2` and Qwen 3.5 9B Q4_K_M model files referenced by that config. No contents of `processed/`, Obsidian, or personal CaptainsLog data were accessed.

The initial end-to-end run was:

```sh
CAPTAINS_LOG_CONFIG_PATH="$RUN_DIR/config.json" \
  .build/out/Products/Debug/cl pipeline \
  --input "eval/transcribe/audio/2025-01-14 side project.m4a" \
  --data-dir "$RUN_DIR/data"
```

It reached all pipeline stages and wrote audio, transcript, cleaned text, category manifest, filename, and enriched entry. The category was `side_project`; the generated slug was `2025-01-14-side-project-star-trek-voice-log`.

The skill suites were generated sequentially with:

```sh
bash scripts/run-evals.sh --suites
```

Run stamp: `2026-09-26_08-14-47_73402`. Generated artifacts and per-case reports are in ignored `eval/*/generated/` and `eval/*/reports/` folders. Their exact file names begin with that stamp. `scripts/validate-eval-run.sh <stamp>` validates saved results without running models.

## End-to-end behavior

- `cl pipeline` copied the fixture and created all expected stage directories and files.
- `cl resume --data-dir <isolated-data>` returned `No pending entries to resume.` A before/after SHA-256 manifest showed all 8 files unchanged.
- `cl search-index` indexed the enriched entry into 2 chunks. Searching `Star Trek captain log side project` returned the generated entry path as the first result.
- The first two pipeline runs categorized the fixture as `side_project`, generated the expected Star Trek/side-project slug, and wrote every stage artifact. Both kept the transcription error “science project” in the cleaned body. The first run omitted expected `side-projects` and `audio` tags and added `audio-processing` and `cloud-storage`; its summary omitted the iCloud synchronization detail. The second run's tag set matched expected and its summary mentioned a shared iCloud folder. This difference between repeated runs shows model output varies, so stage snapshots and semantic review matter alongside CLI pass/fail checks.
- A third run (`2026-09-26_12-19-20_11647`) also passed artifact, resume-immutability, and search-readback assertions. It produced `side_project` and the expected `2025-01-14-side-project-star-trek-voice-log` slug. The transcription still changed “side project” to “science project” and “site project,” and “Liefst een lokaal model” to “Een liefdelokaal model”; cleanup repaired the latter phrase to “Liefst een lokaal model.” Enrichment included expected `side-projects` and `audio` tags, omitted expected `artificial-intelligence`, and added grounded `apple`. It retained expected `automation`, `whisper`, `large-language-model`, and `star-trek` tags. The summary retained the iCloud synchronization and output-folder goals.
- A fourth run (`2026-09-26_12-29-32_13167`) passed the same assertions, with the same category and expected filename. It repeated the `vollendje`, “science project,” “site project,” and “liefdelokaal” transcription errors; cleanup changed `liefdelokaal` to “Liefst een lokaal model” but kept “science project.” This run matched the expected enrichment tag set. Its summary described iCloud-synced transcripts and processed text but omitted the expected original-audio detail.
- A fifth run (`2026-09-26_17-06-38_91326`) passed all stage-artifact, completed-resume immutability, category, filename, and search-readback assertions. It again produced `side_project` and the expected `2025-01-14-side-project-star-trek-voice-log` slug. Transcription changed “foldertje” to “vollendje,” “side project” to “science project” and “site project,” and “Liefst een lokaal model” to “Een liefdelokaal model.” Cleanup improved the prose and changed the latter to “Liever een lokaal model,” but retained “science project.” Enrichment included the iCloud synchronization goal in its summary; its tags used `side-project` and `audio-processing` where expected output uses `side-projects` and `audio`. The derived recording time was again `18:58` rather than fixture time `12:00`; as noted below, pipeline recording time comes from file metadata and varies by run.
- All four pipeline runs recorded `18:58`, while the skill fixture expects `12:00`. The direct enrich evaluation supplies a fixed time; pipeline mode derives the time from copied-file creation metadata, so this value is environment-dependent and should not be treated as a stable metadata comparison.

## Transcription review

All four `eval/transcribe/audio/` cases were generated and read against their expected files. The Swift comparison helper was used as a heuristic and manually checked; its alignment of the hyphenated `side-project` compound was not reliable.

| Fixture | Concrete semantic changes |
|---|---|
| `2025-01-14 side project` | `foldertje` became `vollendje`; “Liefst een lokaal model” became “Een liefdelokaal model”; `side-project` became “science project” and later “site project.” “Science project” changes the topic and propagated into cleanup and the pipeline summary. |
| `alle-mensen-zijn-sterfelijk` | “Florences hand in de hare” became “hand in de haren”; the dismissive “Pff” was dropped; “niets van haar aantrekken” became an awkward “niet van haar moeten aantrekken.” |
| `durins-volk` | “Durin de Onsterfelijke” was merged into “durende onsterfelijke,” losing the character's identity; “liederen” became “Lideren.” Proper-name spelling-only differences were omitted. |
| `world-war-z` | “Harley-Davidsons killed more young Chinese” became “Harley-Davidson skilled more young Chinese”; “New” was dropped from “older New Dachang”; the output added “the name to name” and a trailing `[BLANK_AUDIO]` marker. |

The detailed word reports are saved under `eval/transcribe/reports/` (ignored). These errors mean the transcription evaluation is a quality-gate failure, not a pass.

## Cleanup review

All three cleanup cases were read section by section against their inputs and expected results.

- `book-reference` exactly matches expected output. It removes the spoken repetition while preserving the book, author, and conference.
- `captains-log-nlm-llm` organizes the long passage and removes “I think I'm thinking,” but drops “I'm not really sure how,” keeps `NLM` rather than the expected `LLM`, and retains a curiosity sentence that expected cleanup omits. The acronyms are input-grounded; this is not a hallucination.
- `2025-01-14 side project` adds useful paragraph breaks and repairs malformed “liefdelokaal” to “Liefst een lokaal.” It drops the explicit “this is one of my side projects” framing, shortens the spoken Star Date example, and leaves awkward Dutch word order in “kwijtraak ik de draad.” It preserves the upstream “science project” recognition error rather than inventing it.

Detailed reports are in `eval/cleanup/reports/` (ignored).

## Categorization review

The standalone suite `bash scripts/run-evals.sh --categorize` ran four synthetic memos sequentially with the configured local Qwen 3.5 9B Q4_K_M model. Run stamp: `2026-09-26_12-43-30_17566`. Each JSON manifest had the matching `sourceStem`, and all labels matched the paired expected category: `mixed-work-dominant` → `professional`, `personal-weekend` → `personal`, `professional-release-planning` → `professional`, and `side-project-voice-app` → `side_project`. The mixed memo is a deliberate dominant-topic case; the other three give direct examples for each supported label. The validator reported 4 nonempty manifests and 0 structural/label mismatches. These are synthetic, clear cases; four correct outputs do not establish robustness on a broad or genuinely ambiguous corpus.

Generated manifests are in `eval/categorize/generated/` (ignored); validator diagnostics are in `tmp/eval-validation-2026-09-26_12-43-30_17566/validation.txt`.

## Filename review

All 8 cases passed date-prefix, kebab-case, `.md`, and 3–8-word checks. Topic grounding was checked against each input; no slug introduced an unrelated topic.

- Four filenames exactly match expected: `01_single_topic`, `02_multiple_topics`, `04_short_entry`, and `2025-01-14 side project`.
- `03_personal_reflection` changes “management vs staff engineer track” to “management path staff engineer track,” losing the explicit choice/contrast.
- `06_technical_deep_dive` gives a grounded, concise “sqs-sns-migration-circuit-breakers” slug, but omits the message-queue consumer/refactoring context.
- `07_duplicate_words` selects grounded details about compost, fence, and pond, but loses the overall planning/improvement framing.
- `05_long_mixed_entry` exactly matches expected.

The format helper passed validation for all 8. Per-case semantic reports are in `eval/filename/reports/` (ignored).

## Enrichment review

The first three cases have valid YAML and were checked against expected fields and source text.

- `01_work_week`: all categories, tags, people, projects, companies, and entities match. The summary adds grounded GenAI partnership and transcription-pipeline detail.
- `02_personal_only`: category, people, and summary match. It misses the expected `beach` and `food` tags and adds grounded but broader `dining`.
- `03_mixed_topics`: all expected fields and summary match.
- `2025-01-14 side project`: the initial suite artifact was 0 bytes after the CLI invocation printed its usual save message. A sequential rerun of this one case with the same isolated config, input, date, and recording time wrote 3,491 bytes of valid YAML plus the entry body. That rerun's output was saved as the canonical generated artifact and reviewed: all expected metadata lists match, while the summary omits the iCloud synchronization goal. The zero-byte first artifact coincided with editing the runner during its execution; the exact cause was not isolated, so the report treats it as a runner orchestration failure.

After the sequential rerun, the saved-output validation pass found 19 nonempty outputs out of 19, with valid enrichment frontmatter and no structural validation failures. Per-case reports are in `eval/enrich/reports/` (ignored).

## Runner and coverage notes

`scripts/run-evals.sh` is a sequential, local-model runner. `--pipeline` exercises pipeline creation, category and artifact assertions, completed-resume immutability, search indexing, and search readback. The latest full-pipeline run, `2026-09-26_17-06-38_91326`, passed those assertions; its semantic differences are recorded above. Earlier full-pipeline runs include `tmp/evals-2026-09-26_12-19-20_11647-11647/` and `tmp/evals-2026-09-26_12-29-32_13167-13167/`. `--categorize` runs the standalone four-case suite; its run at `2026-09-26_12-43-30_17566` passed all expected label and manifest checks. `--suites` and `--all` also include those categorization cases, so full saved-output validation now checks 23 outputs (the previous 19 stage outputs plus four categories). The first `--suites` shell was edited while it was executing and ended with `25-01-15: command not found` after generating its outputs. The cross-stage enrichment artifact was initially empty. It was rerun successfully with:

```sh
CAPTAINS_LOG_CONFIG_PATH="$PWD/tmp/evals-2026-09-26_08-14-47_73402-73402/config.json" \
  .build/out/Products/Debug/cl enrich \
  --input "eval/enrich/input/2025-01-14 side project.md" \
  --output "$PWD/tmp/evals-2026-09-26_08-14-47_73402-73402/retry-enrich-2025-01-14-side-project.md" \
  --date 2025-01-15 --recording-time 12:00
```

That command wrote 3,491 bytes of valid YAML plus the source entry. The rerun was copied to `eval/enrich/generated/2026-09-26_08-14-47_73402_Qwen3.5-9B-Q4_K_M_2025-01-14 side project.md` as the canonical stage artifact. The initial 0-byte result coincided with editing the runner during execution; the exact cause was not isolated. The suite artifacts were reviewed and then validated with `bash scripts/run-evals.sh --validate-run 2026-09-26_08-14-47_73402`; all 19 outputs passed structural checks after the rerun.

The broader CLI and visible-app coverage plan is in [`TESTING-PLAN.md`](./TESTING-PLAN.md). Evidence-backed legacy/dead-code candidates are tracked in [`DEAD-CODE-REPORT.md`](./DEAD-CODE-REPORT.md); no code was removed as part of this review.

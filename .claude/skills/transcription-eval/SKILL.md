---
name: transcription-eval
description: Assess transcription quality for CaptainsLog by comparing Whisper-generated output against ground truth. The agent reads both files and documents word-level differences manually.
---

# Transcription Evaluation Skill

Evaluate Whisper transcription accuracy by manually comparing generated output to expected ground truth.

## Core Principle

**You (the agent) must read both files and compare them.** The comparison script is only a helper tool. Verify its output by reading the actual text.

## Workflow

Evaluate **all** test cases in `eval/transcribe/audio/`.

### 1. Determine the Model Name

Before generating, research what transcription model is actually used by the codebase. Use the resolved model name as the filename prefix for generated transcriptions.

### 2. Generate Transcription

Check if transcriptions already exist in `eval/transcribe/generated/` with the model name as prefix (e.g. `<model>_<test-case>.md`). Only run transcription for test cases where the generated file is missing:

```bash
MODEL=<resolved model name from step 1>
swift run cl transcribe eval/transcribe/audio/<test-case>.m4a \
  --output eval/transcribe/generated/${MODEL}_<test-case>.md
```

### 3. Read Both Files

Read the expected and generated (transcription) files yourself. **Use the original, uncleaned generated transcript** — not a cleaned-up or post-processed version. If a cleaned version exists alongside the raw output, always compare against the raw output:

```bash
MODEL=<resolved model name from step 1>
cat eval/transcribe/expected/<test-case>.md
cat eval/transcribe/generated/${MODEL}_<test-case>.md
```

### 4. Compare Word-by-Word

**Words that are different** (expected → got):
- Document substitutions that change meaning
- Example: "killed" → "skilled" (meaning change) — INCLUDE

**Words that are missing** (in expected, not in generated):
- List content words that were dropped

**Words that are added** (in generated, not in expected):
- List extra content words inserted

**IMPORTANT:** The comparison script can miss things (e.g., word merging). Don't trust it blindly. Read the text yourself.

### 5. Run Script as Heuristic

You may run the script to get a starting point, but verify every difference manually:

```bash
MODEL=<resolved model name from step 1>
swift .claude/skills/transcription-eval/scripts/compare.swift \
  --expected eval/transcribe/expected/<test-case>.md \
  --generated eval/transcribe/generated/${MODEL}_<test-case>.md \
  --output ./tmp/comparison.md
```

Then read `./tmp/comparison.md` and verify each entry against the actual text.

### 6. Write the Report

Create the report with the structure below.

## Report Structure

Create `eval/transcribe/reports/<YYYY-MM-DD_HH-MM-SS>_<test-case>.md`:

```bash
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
REPORT_PATH="eval/transcribe/reports/${TIMESTAMP}_<model-name>_<test-case>.md"
```

```markdown
# Transcription Report: <test-case>

**Model**: <actual model name>  
**Date**: YYYY-MM-DD

## Word Differences

| # | Expected | Got |
|---|----------|-----|
| 1 | [first different word] | [what it became] |
| 2 | [second different word] | [what it became] |
| 3 | [third different word] | [what it became] |
| ... | ... | ... |

## Missing Words

- [word 1]
- [word 2]
- [word 3]

## Added Words

- [word 1]
- [word 2]
- [word 3]

## Notes

- [specific meaning-changing errors]
- [any observations about alignment, merging, hallucinations, etc.]
```

## Strict Rules

**DO NOT:**
- Write "Key findings" sections
- Summarize ("mostly accent issues", "fictional names struggle")
- Categorize errors
- Trust the script blindly — always verify by reading
- Report capitalization, punctuation, or proper name spelling differences

**DO:**
- List content word differences (meaning changes)
- List missing content words
- List added content words
- Read the actual text files yourself


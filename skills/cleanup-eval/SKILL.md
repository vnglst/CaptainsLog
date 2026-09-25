---
name: cleanup-eval
description: Assess cleanup quality for CaptainsLog by comparing LLM-cleaned output against expected polished text. The agent reads both files piece by piece and documents structural and semantic differences.
---

# Cleanup Evaluation Skill

Evaluate LLM cleanup quality by manually comparing generated output to expected ground truth, section by section.

## Core Principle

**You (the agent) must read both files and compare them piece by piece.** A word-level comparison script does not work for cleanup because sentence structure, paragraph breaks, and phrasing can change drastically. The evaluation is qualitative and section-based.

## Workflow

Evaluate **all** test cases in `eval/cleanup/input/`.

### 1. Determine the Model Name

Before generating, research what cleanup model is actually used by the codebase. Use the resolved model name as the filename prefix for generated cleanups.

### 2. Generate Cleanup

Generate a new cleanup for each iteration. Use a timestamp in the filename so old versions are preserved:

```bash
MODEL=<resolved model name from step 1>
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
swift run cl cleanup eval/cleanup/input/<test-case>.md \
  --output eval/cleanup/generated/${TIMESTAMP}_${MODEL}_<test-case>.md
```

### 3. Read Both Files

Read the expected and generated files yourself. Compare them section by section:

```bash
MODEL=<resolved model name from step 1>
cat eval/cleanup/expected/<test-case>.md
cat eval/cleanup/generated/${MODEL}_<test-case>.md
```

### 4. Compare Piece by Piece

For each logical section (typically each paragraph), compare expected vs generated side by side.

**Paragraph structure:**
- Were logical paragraph breaks added at topic transitions?
- Is each paragraph a coherent unit?
- Did the model produce a wall of text with no breaks?

**Readability rewriting:**
- Were run-on connectors removed? ("En", "Dus", "Want", "Maar" at sentence/paragraph starts)
- Were awkward spoken phrasings smoothed out?
- Were false starts and repetitions removed?
- Were sentences merged or split appropriately?
- Was self-referential recording commentary removed?

**Meaning preservation:**
- Did any substitutions change the meaning?
- Were factual details, names, numbers preserved?
- Did the model hallucinate or add content not in the raw transcript?
- Did the model drop content from the raw transcript?

**Tone and voice:**
- Was the speaker's informal tone preserved?
- Were contractions and personal phrasing kept?
- Were diminutives and colloquialisms flattened or removed?

### 5. Write the Report

Create the report with the structure below.

## Report Structure

Create `eval/cleanup/reports/<YYYY-MM-DD_HH-MM-SS>_<test-case>.md`:

```bash
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
REPORT_PATH="eval/cleanup/reports/${TIMESTAMP}_<model-name>_${TEST_CASE}.md"
```

```markdown
# Cleanup Report: <test-case>

**Model**: <actual model name>  
**Date**: YYYY-MM-DD

## Paragraph Structure

Brief assessment of whether paragraph breaks were added correctly and whether the text is chunked into logical units.

## Section-by-Section Comparison

For each section, quote both expected and generated (or summarize if long) and describe what differs.

### <Section name>

**Expected**:  
<quote or summary>

**Got**:  
<quote or summary>

- <difference 1>
- <difference 2>

### <Next section name>

...

## Summary

Brief synthesis of the most important failures or successes. Highlight critical meaning changes, structural failures, or prompt violations.
```

## Strict Rules

**DO NOT:**
- Use or create word-level comparison scripts
- Write "Key findings" sections
- Summarize with generic patterns ("mostly good", "some issues")
- Categorize errors into abstract taxonomies
- Report minor punctuation or capitalization differences in isolation
- Report hyphenation or spelling variations unless they change meaning

**DO:**
- Compare piece by piece, section by section
- Document paragraph structure explicitly
- Call out when run-on connectors were preserved instead of removed
- Document meaning-changing substitutions
- Document content that was dropped or hallucinated
- Read the actual text files yourself

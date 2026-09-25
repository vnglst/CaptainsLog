---
name: filename-eval
description: Assess filename generation quality for CaptainsLog by comparing LLM-generated filenames against expected filenames. The agent reads both files and validates format, length, topic relevance, and hallucination manually.
---

# Filename Evaluation Skill

Evaluate LLM filename generation by comparing generated output to expected ground truth.

## Core Principle

**You (the agent) must read both files and compare them.** The comparison script validates format and length but cannot judge topic relevance or hallucination. Verify those by reading the input content.

## Workflow

Evaluate **all** test cases in `eval/filename/input/`.

**Important:** The LLM runs locally on-device and model loading is expensive (~15s). **Never run multiple `swift run cl` commands in parallel.** Generate outputs one test case at a time, or use a simple sequential loop.

### 1. Determine the Model Name

Before generating, research what cleanup model is actually used by the codebase (filename uses the same model as cleanup). Use the resolved model name as the filename prefix for generated outputs.

### 2. Generate Filename

Generate a new filename for each iteration. Use a timestamp in the filename so old versions are preserved:

```bash
MODEL=<resolved model name from step 1>
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
swift run cl filename eval/filename/input/<test-case>.md \
  --date 2025-01-15 \
  > eval/filename/generated/${TIMESTAMP}_${MODEL}_<test-case>.md
```

### 3. Read Both Files

Read the expected filename and the generated filename yourself:

```bash
MODEL=<resolved model name from step 1>
cat eval/filename/expected/<test-case>.md
cat eval/filename/generated/${TIMESTAMP}_${MODEL}_<test-case>.md
```

Also read the input content to verify topic relevance and check for hallucinations:

```bash
cat eval/filename/input/<test-case>.md
```

### 4. Run Script as Heuristic

Run the script to get a starting point for format and length checks:

```bash
MODEL=<resolved model name from step 1>
swift skills/filename-eval/scripts/compare.swift \
  --expected eval/filename/expected/<test-case>.md \
  --generated eval/filename/generated/${TIMESTAMP}_${MODEL}_<test-case>.md
```

Then verify the results manually.

### 5. Evaluate Dimensions

For each test case, assess:

**Format:**
- Valid date prefix (YYYY-MM-DD-)
- Kebab-case slug
- `.md` extension

**Length:**
- Slug is 3–8 words
- Not too short (loses specificity)
- Not too long (becomes unwieldy)

**Topic relevance:**
- Does the slug capture the main topic(s) of the content?
- Would you know what the entry is about from the filename alone?

**No hallucination:**
- Are all words in the slug grounded in the content?
- Did the model invent topics not mentioned?

### 6. Write the Report

Create the report with the structure below.

## Report Structure

Create `eval/filename/reports/<YYYY-MM-DD_HH-MM-SS>_<model-name>_<test-case>.md`:

```bash
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
REPORT_PATH="eval/filename/reports/${TIMESTAMP}_<model-name>_${TEST_CASE}.md"
```

```markdown
# Filename Report: <test-case>

**Model**: <actual model name>  
**Date**: YYYY-MM-DD

## Generated vs Expected

**Expected**: `<expected-filename>`
**Generated**: `<generated-filename>`

## Dimension Checks

### Format
- [ ] Date prefix valid
- [ ] Kebab-case slug
- [ ] `.md` extension

### Length
- Generated slug: N words
- Expected slug: N words
- [ ] Within 3–8 word range

### Topic Relevance
- [ ] Captures main topic(s)
- [ ] Specific enough to identify content

### No Hallucination
- [ ] All words grounded in content
- [ ] No invented topics

## Differences

- <specific difference 1>
- <specific difference 2>

## Summary

Brief synthesis of the most important failures or successes. Highlight format violations, hallucinations, or topic misses.
```

## Strict Rules

**DO NOT:**
- Write "Key findings" sections
- Summarize with generic patterns ("mostly good", "some issues")
- Categorize errors into abstract taxonomies
- Trust the script blindly — always verify by reading

**DO:**
- Read the input content to verify topic relevance
- Check every word in the slug against the input
- Document format violations explicitly
- Document hallucinated or missing topics

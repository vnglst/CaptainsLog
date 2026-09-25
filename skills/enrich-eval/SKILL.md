---
name: enrich-eval
description: Assess enrich (YAML frontmatter generation) quality for CaptainsLog by comparing LLM-generated frontmatter against expected frontmatter. The agent reads both files and validates categories, tags, persons, projects, companies, entities, summary, and hallucination manually.
---

# Enrich Evaluation Skill

Evaluate LLM YAML frontmatter generation by comparing generated output to expected ground truth, field by field.

## Core Principle

**You (the agent) must read both files and compare them piece by piece.** The comparison script identifies missing/extra list items and string differences but cannot judge semantic quality (e.g. whether a summary is accurate or a tag is truly grounded). Verify those by reading the input content.

## Workflow

Evaluate **all** test cases in `eval/enrich/input/`.

**Important:** The LLM runs locally on-device and model loading is expensive (~15s). **Never run multiple `swift run cl` commands in parallel.** Generate outputs one test case at a time, or use a simple sequential loop.

### 1. Determine the Model Name

Before generating, research what cleanup model is actually used by the codebase (enrich uses the same model as cleanup). Use the resolved model name as the filename prefix for generated outputs.

### 2. Generate Enrich Output

Generate a new enrichment for each iteration. Use a timestamp in the filename so old versions are preserved:

```bash
MODEL=<resolved model name from step 1>
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
swift run cl enrich eval/enrich/input/<test-case>.md \
  --output eval/enrich/generated/${TIMESTAMP}_${MODEL}_<test-case>.md \
  --date 2025-01-15 \
  --recording-time 12:00
```

### 3. Read Both Files

Read the expected frontmatter and the generated frontmatter yourself:

```bash
MODEL=<resolved model name from step 1>
cat eval/enrich/expected/<test-case>.md
cat eval/enrich/generated/${TIMESTAMP}_${MODEL}_<test-case>.md
```

Also read the input content to verify semantic accuracy and check for hallucinations:

```bash
cat eval/enrich/input/<test-case>.md
```

### 4. Validate YAML Syntax

Before comparing content, verify the generated output is valid YAML:

```bash
ruby -ryaml -e '
generated = File.read("eval/enrich/generated/${TIMESTAMP}_${MODEL}_<test-case>.md")
parts = generated.split("---", 3)
YAML.safe_load(parts[1]) if parts.length >= 3
' || echo "ERROR: Generated YAML is invalid"
```

If the YAML is invalid, document the parsing error in the report and stop evaluating this test case — valid YAML is a hard requirement.

### 5. Run Script as Heuristic

Run the script to get a starting point for list and string comparisons:

```bash
MODEL=<resolved model name from step 1>
swift skills/enrich-eval/scripts/compare.swift \
  --expected eval/enrich/expected/<test-case>.md \
  --generated eval/enrich/generated/${TIMESTAMP}_${MODEL}_<test-case>.md
```

Then verify the results manually. Pay special attention to the summary field and whether tags are grounded in the content.

### 6. Evaluate Dimensions

For each test case, assess each frontmatter field:

**Categories:**
- Are the categories accurate (work, personal, side-project, health, finance)?
- Are all relevant categories present?

**Tags:**
- Are tags specific topics mentioned in the content?
- Are there missing important tags?
- Are there hallucinated tags not in the content?

**Persons:**
- Are all people mentioned by name included?
- Are there false positives (names not in the content)?

**Projects:**
- Are project names referenced in the content captured?
- No invented projects?

**Companies:**
- Are organizations mentioned in the content included?
- No invented companies?

**Entities:**
- Are events, technologies, and other named entities captured?
- No hallucinated entities?

**Summary:**
- Is it an accurate 2–3 sentence summary?
- Does it capture the main points without hallucination?
- Is the tone consistent with the entry?

**No hallucination:**
- Is every item in every list grounded in the input content?
- Did the model invent anything?

### 7. Write the Report

Create the report with the structure below.

## Report Structure

Create `eval/enrich/reports/<YYYY-MM-DD_HH-MM-SS>_<model-name>_<test-case>.md`:

```bash
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
REPORT_PATH="eval/enrich/reports/${TIMESTAMP}_<model-name>_${TEST_CASE}.md"
```

```markdown
# Enrich Report: <test-case>

**Model**: <actual model name>  
**Date**: YYYY-MM-DD

## Field-by-Field Comparison

### Categories

**Expected**:
- item 1
- item 2

**Generated**:
- item 1
- item 3

- <difference 1>
- <difference 2>

### Tags

**Expected**:
- item 1
- item 2

**Generated**:
- item 1
- item 3

- <difference 1>
- <difference 2>

### Persons

... (same pattern)

### Projects

...

### Companies

...

### Entities

...

### Summary

**Expected**: <quote or summary>
**Generated**: <quote or summary>

- <difference 1>
- <difference 2>

## Summary

Brief synthesis of the most important failures or successes. Highlight critical hallucinations, missing key metadata, or summary failures.
```

## Strict Rules

**DO NOT:**
- Write "Key findings" sections
- Summarize with generic patterns ("mostly good", "some issues")
- Categorize errors into abstract taxonomies
- Trust the script blindly — always verify by reading
- Report minor formatting differences in isolation

**DO:**
- Read the input content to verify every list item
- Check the summary against the input for accuracy
- Document hallucinated items explicitly
- Document missing items explicitly
- Call out when the summary misrepresents the content

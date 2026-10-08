---
name: filename-eval
description: Assess filename generation quality for CaptainsLog by comparing LLM-generated filenames against expected filenames. The agent reads both files and validates format, length, topic relevance, and hallucination manually.
---

# Filename review

Run fixtures through [scripts/run-evals.sh](../../scripts/run-evals.sh); see [the shared workflow](../../docs/EVALUATIONS.md) for stage/case selection, saved runs, metadata and baselines. The runner owns isolation and output names. Review the selected cases from its printed `review.md`; required release runs still include all suites and the full pipeline.

## Stage review

Read the input and both filenames. Mechanical validation checks the supplied date, lowercase kebab case, `.md` extension and 3–8 slug words.

- Check whether the slug captures the main topics and is specific enough to identify the entry.
- Verify every slug word is grounded in the input; identify invented or missing topics.
- Explain lost distinctions, such as management versus staff engineering, rather than treating exact expected-word matches as the goal.

Optional `scripts/compare.swift` in this skill is a format/word-overlap heuristic. It does not establish topic quality; use the assembled evidence for review.

## Reporting

Use each case's generated `report.md` and the [shared concise report format](../../docs/EVALUATIONS.md#semantic-report). Read every selected case, record concrete differences and semantic impact, and identify regressions or improvements when a baseline is available. Avoid generic judgments such as “mostly good.” Mechanical checks and heuristic scores never replace semantic review or the owner's final judgment.

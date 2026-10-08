---
name: enrich-eval
description: Assess enrich (YAML frontmatter generation) quality for CaptainsLog by comparing LLM-generated frontmatter against expected frontmatter. The agent reads both files and validates categories, tags, persons, projects, companies, entities, summary, and hallucination manually.
---

# Enrichment review

Run fixtures through [scripts/run-evals.sh](../../scripts/run-evals.sh); see [the shared workflow](../../docs/EVALUATIONS.md) for stage/case selection, saved runs, metadata and baselines. The runner owns isolation and output names. Review the selected cases from its printed `review.md`; required release runs still include all suites and the full pipeline.

## Stage review

Read the source entry and expected/generated frontmatter field by field. If mechanical YAML/schema/body checks fail, record the failure before semantic assessment.

- Check supplied date/time and the language of the entry.
- For categories, tags, persons, projects, companies and entities, name concrete missing or added items and verify every addition against the input.
- Read the summary against the full input: identify omitted details, misleading emphasis, altered meaning and invented facts. Check whether 2–3 sentences capture the main points.
- Distinguish a grounded alternative tag from a hallucination. Expected wording is a reference, not the sole valid phrasing.

Optional `scripts/compare.swift` in this skill lists field differences. It cannot judge grounding or summary accuracy. Do not report formatting differences alone.

## Reporting

Use each case's generated `report.md` and the [shared concise report format](../../docs/EVALUATIONS.md#semantic-report). Read every selected case, record concrete differences and semantic impact, and identify regressions or improvements when a baseline is available. Avoid generic judgments such as “mostly good.” Mechanical checks and heuristic scores never replace semantic review or the owner's final judgment.

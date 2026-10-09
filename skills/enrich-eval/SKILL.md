---
name: enrich-eval
description: Assess enrich (YAML frontmatter generation) quality for CaptainsLog by comparing LLM-generated frontmatter against expected frontmatter. The agent reads both files and validates categories, tags, persons, projects, companies, entities, summary, and hallucination manually.
---

# Enrichment review

Run fixtures through `make evals STAGE=enrich`; see [the shared workflow](../../README.md#fixture-evaluations) for stage/case selection, saved runs, metadata and baselines. The runner owns isolation and output names. Review the selected cases from its printed `review.md`; model evaluations run separately from release preparation. For dependency upgrades, new features or significant refactors, follow the build, test and sequential fixture pipeline checks in [AGENTS.md](../../AGENTS.md#development).

## Stage review

Read the source entry and expected/generated frontmatter field by field. If mechanical YAML/schema/body checks fail, record the failure before semantic assessment.

- Check supplied date/time and the language of the entry.
- For categories, tags, persons, projects, companies and entities, name concrete missing or added items and verify every addition against the input.
- Read the summary against the full input: identify omitted details, misleading emphasis, altered meaning and invented facts. Check whether 2–3 sentences capture the main points.
- Distinguish a grounded alternative tag from a hallucination. Expected wording is a reference, not the sole valid phrasing.

Optional `scripts/compare.swift` in this skill lists field differences. It cannot judge grounding or summary accuracy. Do not report formatting differences alone.

## Reporting

Use each case's generated `report.md` and the [shared concise report format](../../README.md#semantic-review). Read every selected case, record concrete differences and semantic impact, and identify regressions or improvements when a baseline is available. Avoid generic judgments such as “mostly good.” Mechanical checks and heuristic scores never replace semantic review or the owner's final judgment.

## Reproducible regression checks

Enrichment suites use the supplied date, recording time and seed from `eval/enrich/cases.json`, snapshot that manifest, and retain per-case diagnostics. `make evals STAGE=enrich` selects this suite; `make evals ARGS="--validate-enrich STAMP"` validates older outputs. Fixed seeds support repeatability only with the recorded runtime; application defaults remain random. Model-free checks enforce fixture fingerprints, bounded metadata, unique names, 3–8 tags and exact source bodies before generation.

Synthetic fixtures must be written from scratch in an unrelated domain with invented names, events and scenarios. Do not retain names, terminology, outlines, spelling variants, token positions or length targets from private material. Replacing names alone is insufficient. Changing a regression fixture invalidates its earlier native evidence: rerun baseline and fixed checks before claiming a result. See [fixture provenance and native reproduction](../../eval/enrich/README.md).

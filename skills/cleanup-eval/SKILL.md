---
name: cleanup-eval
description: Assess cleanup quality for CaptainsLog by comparing LLM-cleaned output against expected polished text. The agent reads both files piece by piece and documents structural and semantic differences.
---

# Cleanup review

Run fixtures through `make evals STAGE=cleanup`; see [the shared workflow](../../README.md#fixture-evaluations) for stage/case selection, saved runs, metadata and baselines. The runner owns isolation and output names. Review the selected cases from its printed `review.md`; model evaluations run separately from release preparation. For dependency upgrades, new features or significant refactors, follow the build, test and sequential fixture pipeline checks in [AGENTS.md](../../AGENTS.md#development).

## Stage review

Read the input, expected text and generated text section by section. Do not use word-level scores to judge rewriting.

- Describe paragraph breaks and coherent topic transitions, including walls of text.
- Check false starts, repetition, run-on connectors and self-referential recording commentary.
- Identify concrete omissions, meaning-changing substitutions, and invented facts against the input. Expected text can itself differ from the input; call that out.
- Check names, numbers, uncertainty, informal voice, diminutives and colloquialisms.
- Report punctuation, spelling or hyphenation only when they change meaning.

In the shared report, give a short section-by-section account of actual differences and their consequences. Quote only the phrases needed to locate them.

## Reporting

Use each case's generated `report.md` and the [shared concise report format](../../README.md#semantic-review). Read every selected case, record concrete differences and semantic impact, and identify regressions or improvements when a baseline is available. Avoid generic judgments such as “mostly good.” Mechanical checks and heuristic scores never replace semantic review or the owner's final judgment.

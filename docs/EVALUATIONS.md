# Fixture evaluations

[`scripts/run-evals.sh`](../scripts/run-evals.sh) owns execution, isolated configuration, selection and artifact naming. Run from the repository root with Swift, Ruby (standard library), and installed local models. Do not read personal app configuration, speaker context, notes or recordings. Inputs come only from `eval/`; inference runs sequentially. Finish compiling before inference and do not edit a running evaluator.

```sh
# Discover the active suite or exact case stems without models/builds.
bash scripts/run-evals.sh --list
bash scripts/run-evals.sh --stage filename --list

# Focused iteration; quote stems with spaces and omit their extension.
bash scripts/run-evals.sh --stage filename --case 04_short_entry
bash scripts/run-evals.sh --stage cleanup --case '2025-01-14 side project'
bash scripts/run-evals.sh --stage enrich

# Required full gates remain separate and sequential.
bash scripts/run-evals.sh --pipeline
bash scripts/run-evals.sh --suites
# --all (the default) runs pipeline then suites.

# Revalidate saved artifacts without builds, downloads or inference.
bash scripts/run-evals.sh --validate-run tmp/evals-<stamp>
# Compare selected cases to another new-format saved run.
bash scripts/run-evals.sh --stage filename --baseline tmp/evals-<baseline-stamp>

# Deterministic selection/validator/evidence regression checks.
ruby scripts/test-evals.rb
```

`--categorize` and `--enrich` remain compatibility aliases for their respective `--stage` selections. Legacy complete timestamped suites can still be checked with `--validate-run <stamp>` or stage-only `--validate-categorize <stamp>` / `--validate-enrich <stamp>`. Their model labels must match the environment overrides used to generate them. New runs use an explicit manifest, so later validation does not guess labels, cases or output paths. Legacy runs lack captured configuration and fixture snapshots; they cannot establish full reproducibility.

## Isolation and models

Each invocation creates a new `tmp/evals-<stamp>` with config/data and no demo seeding or personal speaker context. `CAPTAINS_LOG_EVAL_RUN_DIR` may select a new directory; an existing directory is rejected to preserve runs. Only the models needed for the selected work are required. Model files are read from their installed locations; Qwen's exact file is pinned through a symlink in the isolated run. Models are never removed or modified.

Overrides are `CAPTAINS_LOG_EVAL_QWEN_FOLDER`, `CAPTAINS_LOG_EVAL_QWEN_FILE`, `CAPTAINS_LOG_EVAL_QWEN_LABEL` (display/output label only), `CAPTAINS_LOG_EVAL_WHISPER_FOLDER` and `CAPTAINS_LOG_EVAL_WHISPER_MODEL`. Defaults match the source build's Qwen 3.5 9B Q4_K_M and Whisper Large-v2 caches. The runner fails for missing files rather than falling back to personal config. Never launch another inference task concurrently.

Text suite cases share one loaded Qwen model, including across stages. The batch calls the same stage functions as standalone commands and preserves their generation settings. `LLM.runInference` creates and frees a fresh context and sampler for each call, so previous case text and repetition history are not reused. The pipeline separately loads Qwen once for its stages; Whisper and text processing remain sequential.

## Evidence and mechanical checks

The printed run directory contains:

- `manifest.json`: selected stages/cases and exact fixture/output paths, including pipeline artifacts.
- `metadata.json`: actual model paths, sizes and SHA-256 (Whisper file hashes), prompt/fixture/source hashes, Git revision and dirty status, compiled CLI hash, Swift version, linked runtime identities/hashes, generation defaults and elapsed time/status. Dates/times live in per-case manifests; pipeline times derive from the isolated audio’s creation time. Pipeline search readback also records the embedding model identity. Enrichment suites use and snapshot the date/time/seed settings in `eval/enrich/cases.json`; other stages and the pipeline retain their random sampling defaults. Runs support semantic comparisons, not guaranteed byte-for-byte model reproduction.
- `fixtures/`: suite input/expected snapshots; pipeline intermediates remain in its isolated `data/`.
- `review.md`: per-case index linking input, expected and generated content, validation and optional baseline diff. Audio fixtures are linked and copied, rather than rendered as text.
- Per-case `report.md`: semantic review template, preserved on revalidation. Revalidation refreshes evidence and diagnostics, not authored reports.
- Build, batch, transcription, per-case enrichment diagnostics and pipeline logs; `validation.json` reports case/failure counts and validator hash. It reflects the latest revalidation; `metadata.json` retains the original execution status.

Canonical suite outputs retain the timestamp/model/case naming under ignored `eval/<stage>/generated/`. The bundle copies them for inspection. Baseline diffs help locate changes; they are not cleanup scores. Missing matching baseline cases are stated explicitly. Invalid/missing output fails the command and remains available for diagnosis. The validator checks plain-text leakage/control bytes, full filename structure, category manifests against their expected labels, strict enrichment YAML keys/list item types/nonempty values, supplied date/time, category values, bounded metadata, unique names, 3–8 tags, expected language, fixture fingerprints and exact source-body preservation. It does not prove factual grounding or completeness.

## Semantic report

Use the stage-specific guidance in [transcription](../skills/transcription-eval/SKILL.md), [cleanup](../skills/cleanup-eval/SKILL.md), [filename](../skills/filename-eval/SKILL.md), and [enrichment](../skills/enrich-eval/SKILL.md). For categorization, compare the selected destination to the full input and expected label, explaining competing topics and any routing error.

Fill each generated `report.md` concisely:

- Omissions / changed meaning: exact missing detail or changed phrase and its consequence; “none observed” only after reading.
- Added or hallucinated content: exact addition and whether grounded in the input.
- Improvements / regressions: concrete changes versus the named baseline, or state no baseline.
- Stage-specific observations: paragraph structure, content word changes, slug relevance, metadata fields or destination as appropriate.
- Judgment and limits: acceptable or failed for the reviewed purpose, mechanical failures, remaining uncertainty and owner review.

Reference the run's metadata rather than copying long model/config details into every report. Promote durable dated evidence and timing measurements into [testing verification history](testing-verification.md#dated-verification-evidence). Do not claim token/time savings from fewer commands alone: measure elapsed time, report run scope and cache state, and distinguish observed timings from estimates. Human review remains the quality gate.

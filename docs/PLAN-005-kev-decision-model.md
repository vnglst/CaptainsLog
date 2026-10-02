# Kev decision-model details

Open items and completion status are tracked in the [main backlog](PLAN.md#kev-decision-model). The steps below are implementation guidance and acceptance criteria.

## Goal

Evaluate Kev as an optional local decision model for categorization and, separately, checking whether generated summaries are supported by their source. Adopt it only if repository fixtures show a useful improvement within the current Mac's memory and latency limits.

The target machine is an M4 MacBook Air with 16 GB unified memory and an 8-core GPU. Qwen 3.5 9B Q4_K_M remains the baseline for cleanup, filenames, categorization and enrichment. Kev would make bounded choices or scores; cleanup, filename generation, summaries and arbitrary named-entity extraction still need the generative model.

## Candidates and runtime

- Start with Kev 4B Q8. A [community GGUF](https://huggingface.co/espetro/kev-4b-gguf) is approximately 4.49 GB; this is the weight-file size, not a measured runtime footprint.
- Compare Kev 0.8B if a compatible conversion is available. Its smaller footprint may suit categorization, but accuracy must be measured independently.
- Exclude Kev 27B on this machine. Treat 9B as outside the initial experiment: it adds memory and loading cost without established benefit for these tasks.
- Verify the exact checkpoint, conversion, license, calibration values and file checksum before downloading. Prefer a maintained upstream conversion that includes the trained decision head. Pin the model and runtime revisions used in reports.
- The [Kev project](https://github.com/jaredpalmer/kev) is Apache-2.0 licensed and documents full-precision MLX hardware requirements. Those requirements do not establish the memory needs of a quantized GGUF.
- [llama.cpp decision-model support](https://github.com/ggml-org/llama.cpp/pull/29818) merged on 2026-10-02. Verify its availability in the source and packaged runtime before implementation. Loading a Qwen backbone alone is insufficient: the trained decision head and probability readout must be exercised.

## 1. Establish the comparison

- Run the existing Qwen categorization suite sequentially with isolated config/data and preserve its results as the baseline.
- Extend `eval/categorize/` with synthetic Dutch and English entries covering ambiguous work/side-project boundaries, mixed topics, short notes, negation, quoted statements, unfamiliar names and long entries. Define expected labels and their rationale before comparing models.
- Include paired inputs with reordered choices and equivalent question wording to check decision stability.
- Keep development fixtures separate from held-out acceptance fixtures. Define acceptable error and latency limits before inspecting held-out results; do not select a confidence threshold on those results.
- Write an evaluation workflow for decision models, including per-case semantic review and probability/calibration checks. Existing stage workflows remain applicable to generated cleanup, filenames and enrichment.

Use only fixtures under `eval/`. Set `CAPTAINS_LOG_CONFIG_PATH` to an isolated temporary config with a temporary data directory, bypass demo seeding, and never read personal recordings, logs or context. Run only one inference task at a time.

## 2. Prove hardware and runtime fit

- Build a CLI experiment through in-process libllama using the supported decision head/readout APIs. Compare fixed requests with Kev's reference implementation or published reference outputs; do not infer compatibility from a successful model load.
- Run Kev 4B Q8 and the smaller candidate sequentially on the target Mac. Record model load time, warm decision latency, peak process memory, system memory pressure, swap growth and machine responsiveness for short and long fixtures.
- Begin with bounded contexts appropriate to the fixtures. Reject oversized requests explicitly rather than silently truncating them; document supported input length and memory behavior.
- Release Whisper and Qwen before loading Kev. Include unload/reload overhead in an end-to-end pipeline comparison; a faster isolated category decision is not enough to justify another model.
- Stop the experiment if memory pressure or responsiveness deteriorates. Reject any setup that reproduces the previous 27B failure documented in [ADR-004](ADR-004-qwen3-6-27b-memory-limit.md).

No cloud inference, Ollama, Python inference service or separate model server belongs in the shipped pipeline. Any upstream server examples are compatibility references; CaptainsLog must retain its Swift CLI and in-process llama.cpp architecture.

## 3. Evaluate categorization and decide

- Compare each label against its fixture rationale. Report wrong categories, Dutch/English differences, ambiguous cases, choice-order sensitivity and whether confidence distinguishes errors from correct decisions.
- Measure repeat-run variation and calibrate any confidence policy on development fixtures only. Valid structured output and high confidence do not establish correctness.
- Require no regressions on existing category fixtures, acceptable held-out Dutch performance, responsive operation without sustained high memory pressure or materially increased swap, and a useful quality or end-to-end latency benefit over Qwen.
- Record the decision, exact model/runtime pins, semantic findings and remaining limits in an ADR. Keep Qwen as the default if Kev fails a gate or the integration cost outweighs the measured benefit.

## 4. Add optional product support after the gates pass

- Add decision-model selection, folder, revision and any confidence policy to `CaptainsLogConfig`, preserving existing configuration behavior. Expose the same options through CLI commands before Settings.
- Add verified model download/setup and runtime capability checks. An explicitly selected but unsupported model must produce an actionable error; define and document any low-confidence fallback without hiding extra inference cost.
- Add a shared core decision interface for CLI and app. Keep XML-style task instructions and preserve model-returned decisions; do not repair generated answers with replacements or regex transformations. Use the checkpoint's documented numeric probability readout, with validation for finite values and allowed labels.
- Preserve category manifests, resumability and stage ownership. Serialize inference, reuse Qwen once loaded for its stages, and schedule Kev to avoid holding both text models in memory. Measure the resulting model switches.
- Add deterministic tests for config migration, unsupported runtime/model errors, label validation, cancellation, model lifetime and any fallback behavior. Exercise the actual CLI with repository fixtures.

## 5. Evaluate summary checks separately

- Add synthetic source/summary pairs under `eval/` with supported claims, invented entities, changed numbers, reversed negation, missing uncertainty and fluent but unsupported statements. Include Dutch sources with English summaries.
- Use Kev to judge explicitly defined grounding questions. Measure missed unsupported claims and false alarms against human-reviewed labels, separately from category accuracy.
- Initially expose checks as a CLI evaluation report. Preserve earlier-stage files and the generated summary; do not silently rewrite content or automatically retry based on an unvalidated score. Omission detection is a separate rubric from factual grounding.
- Decide whether checks provide enough benefit to become an optional pipeline stage. Define review behavior and default-off configuration before adding app controls; reserve UI space so status elements do not shift surrounding layout.

## Completion checks

After runtime upgrades or implementation, run `swift build`, `swift run run-tests`, `filename-eval` as a quick LLM smoke check, and the full fixture pipeline. Run all stage evaluation suites sequentially and review semantic output under their workflows. Verify offline operation and model loading in the packaged app as well as the CLI, including the supported older configuration and Qwen-only path.

Update the changelog and notices with each implementation change. Move durable decisions and dated evidence into the relevant ADRs, then remove obsolete implementation guidance once durable decisions are preserved there. Track any remaining work in the main backlog.

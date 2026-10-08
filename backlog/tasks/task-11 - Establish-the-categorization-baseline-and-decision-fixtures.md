---
id: TASK-11
title: Evaluate Kev and integrate optional local decisions if justified
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-08 17:16'
labels:
  - kev
dependencies: []
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Determine whether Kev improves local categorization or summary-grounding checks enough to justify another model. This is one end-to-end task: establish evidence, make the adoption decision, then implement and verify only the capabilities whose gates pass. Qwen remains the default. A documented rejection can close the relevant integration phases without shipping Kev.

### Establish a fair baseline

Kev is being considered as an optional local model for bounded category choices. Before evaluating it, establish the current Qwen categorization baseline and a fair set of synthetic English and Dutch decision cases.

Include ambiguous work/side-project boundaries, mixed topics, short notes, negation, quoted statements, unfamiliar names and long entries. Define expected labels and their rationale before comparing models. Pair equivalent questions and reorder answer choices to test stability.

Keep development cases separate from held-out acceptance cases. Define acceptable error and latency limits before inspecting held-out output, and calibrate confidence only on development data. Review each wrong category and explain the semantic impact; a well-formed label or high probability is not proof of correctness. Run only one model task at a time with isolated data.

### Prove native runtime compatibility

A Kev model loading successfully does not prove that CaptainsLog can use its trained decision head. Establish exact checkpoint and llama.cpp runtime compatibility before attempting product integration.

Start with a compatible Kev 4B Q8 conversion and verify the checkpoint, conversion provenance, license, calibration information and checksum. Pin model and runtime revisions. Community weight-file sizes are download estimates, not measured runtime memory. Verify that the installed and packaged native runtime exposes the required decision head and numeric probability readout.

Build a small Swift CLI experiment using in-process libllama, then compare fixed requests with the model’s reference implementation or published reference outputs. Validate finite probabilities and allowed choices; loading only a Qwen backbone is insufficient. Keep Qwen as the production default and do not add a cloud, Python inference service, daemon or separate model server.

### Compare candidates on the target Mac

Compare compatible Kev 4B Q8 and Kev 0.8B candidates with the Qwen baseline on the M4 MacBook Air with 16 GB unified memory and an 8-core GPU. The purpose is to determine whether better bounded decisions justify another model’s memory and switching costs.

Run candidates sequentially on short and long synthetic English/Dutch cases. Record cold load time, warm decision latency, peak process memory, memory pressure, swap growth and responsiveness. Release Whisper and Qwen before loading Kev, and include unloading/reloading in end-to-end pipeline measurements.

Bound supported input length explicitly and reject oversized requests rather than silently truncating them. Stop trials if responsiveness or memory pressure deteriorates. Exclude 27B and keep 9B outside the initial experiment. Measure decision accuracy, repeat-run variation, choice-order sensitivity and calibration against predeclared acceptance limits.

### Decide whether to adopt Kev

Decide whether Kev provides enough measured benefit to adopt as an optional decision model. Use the completed compatibility and candidate comparisons, not model size, confidence or isolated speed claims alone.

Require no regressions on existing categorization cases, acceptable held-out Dutch performance, responsive operation without sustained memory pressure or materially increased swap, and useful quality or end-to-end latency benefit after model switching. Confidence policies must be calibrated on development cases only.

Record the adopted or rejected option in an architecture decision record, including exact model/runtime pins, fixture scope, concrete semantic findings, costs and remaining limits. Keep Qwen as the default if a gate fails or the integration cost outweighs the benefit. This phase records the decision; implementation must wait until the gates pass.

### Evaluate summary grounding with its own rubric

Evaluate whether Kev can identify unsupported summary claims independently of its categorization accuracy. Use synthetic source/summary pairs with human-reviewed labels, including Dutch sources with English summaries.

Include invented entities, changed numbers, reversed negation, missing uncertainty and fluent but unsupported statements, as well as correct claims. Report missed unsupported claims and false alarms separately. Omission detection is a different rubric from factual grounding and should not be folded into one unexplained score.

Expose results as a CLI evaluation report first. Preserve the generated summary and earlier-stage files; do not silently rewrite content or retry generation based on an unvalidated score. Decide whether the benefit justifies an optional pipeline stage, define default-off configuration and review behavior, and reserve stable UI space before adding app controls.

### Implement optional support only after passing the gates

Only after the adoption gates pass, expose Kev as an optional decision model while preserving the existing Qwen-only workflow. Add CLI and configuration support before Settings controls, with model selection, location, revision and any validated confidence policy.

Provide verified downloads and capability checks. An explicitly selected unsupported model must produce an actionable error. Define any low-confidence fallback openly, including its extra inference cost; do not silently repair model answers or hide retries.

Share decision code between CLI and app, validate finite probabilities and allowed labels, and preserve category manifests, resumability and earlier-stage files. Schedule model lifetimes sequentially so Qwen and Kev are not kept loaded together unnecessarily. Test configuration migration, cancellation, unsupported models/runtimes, model lifetime and fallback behavior with deterministic cases and actual fixture CLI runs.

### Verify any adopted integration

After optional Kev support is implemented, verify the integrated CLI and packaged app rather than relying on isolated decision experiments. Confirm the supported older configuration and unchanged Qwen-only path.

Run the build, full deterministic tests, a focused filename smoke check, all stage suites sequentially and the full synthetic audio pipeline. Review generated output for omissions, changed meaning and invented content. Measure model switching, cancellation and unsupported-runtime errors in the real command path.

Verify offline operation after downloads, correct model loading in the packaged app, expected configuration migration, notices and error behavior. Record exact versions and remaining limits. Passing structural checks or a category benchmark alone does not establish summary grounding or release readiness.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Synthetic English and Dutch cases have predeclared labels, development/held-out separation and quality/latency limits, with the Qwen baseline recorded.
- [ ] #2 The pinned Kev checkpoint, conversion, license and native decision-head/probability support are verified against reference outputs.
- [ ] #3 Compatible 4B Q8 and 0.8B candidates are compared on the 16 GB M4 Mac, including semantic accuracy, calibration, stability, model-switching time and memory pressure.
- [ ] #4 An architecture decision records adoption or rejection, concrete semantic findings, measured costs and remaining limits; failed gates prevent product integration.
- [ ] #5 Summary grounding is evaluated independently, with unsupported-claim misses, false alarms and omission limits reported; any optional stage has an explicit adoption decision.
- [ ] #6 If adopted, optional CLI/configuration and app support preserve Qwen-only behavior, resumability and sequential model lifetimes, with explicit downloads, capability errors and validated fallback policy.
- [ ] #7 If adopted, deterministic tests, sequential stage evaluations, a full synthetic audio pipeline and packaged-app offline/migration checks pass with reviewed semantic findings; rejected integration phases are explicitly recorded as inapplicable.
<!-- AC:END -->

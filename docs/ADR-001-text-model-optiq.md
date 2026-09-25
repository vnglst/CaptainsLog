# ADR-001: Switch Default Text Model to Qwen3.5-9B-OptiQ-4bit

> **[SUPERSEDED]** — This ADR evaluated MLX-format model quantizations when the project used `mlx-swift-lm` for inference. As of 2026-06-09, CaptainsLog has migrated from MLX to llama.cpp. The text model is now `bartowski/Qwen_Qwen3.5-9B-GGUF` (Q4_K_M quantization in GGUF format via llama-cli). The qualitative findings (OptiQ > uniform 4-bit for cleanup formatting) remain directionally valid but the specific model formats and framework no longer apply.

**Status**: ~~Accepted~~ Superseded

**Date**: 2026-04-21

**Deciders**: OpenCode (automated evaluation), Koen van Gilst (final approval)

---

## Context

CaptainsLog's text-processing pipeline (cleanup, filename generation, metadata enrichment) uses an MLX-quantized Qwen model loaded via `mlx-swift-lm`. The current default was `mlx-community/Qwen3.5-9B-MLX-4bit` (uniform 4-bit quantization, ~6 GB).

A new mixed-precision quantization method called **OptiQ** became available for the same model. OptiQ keeps sensitive layers at 8-bit and robust layers at 4-bit, averaging ~4.5 bits-per-weight at the same disk size. The question was whether this improved quantization meaningfully improves output quality for our specific pipeline tasks.

Additionally, a new model family (Google Gemma 4) was released and claimed to be supported by `mlx-swift-lm 3.31.3`. We wanted to evaluate whether switching architectures would yield benefits.

## Evaluation Method

We ran the existing skill-based evaluation suite against all candidate models:

- **Cleanup**: 1 test case (Dutch transcript with filler words, transcription errors, no paragraph structure)
- **Filename**: 8 test cases (varied topics, lengths, edge cases)
- **Enrich**: 4 test cases (work week, personal reflection, mixed topics, side project)

Each model's output was compared against expected ground truth using the project's `compare.swift` scripts. Comparisons focused on:

1. **Content preservation** — no facts added, removed, or altered
2. **Formatting adherence** — paragraph breaks, YAML validity, filename conventions
3. **Semantic drift** — subjective qualifiers, hallucinated framing, meaning changes

## Candidates Evaluated

### Candidate 1: `mlx-community/Qwen3.5-9B-MLX-4bit` (Baseline)

- Uniform 4-bit quantization
- ~6 GB disk
- Already the default

### Candidate 2: `mlx-community/Qwen3.5-9B-OptiQ-4bit` (Selected)

- Mixed-precision OptiQ (4.5 BPW average)
- ~6 GB disk (same as baseline)
- Same tokenizer and chat template as baseline (drop-in replacement)

### Candidate 3: `mlx-community/gemma-4-e4b-it-OptiQ-4bit` (Blocked)

- Google's Gemma 4 architecture
- ~6.3 GB disk
- Failed to load with shape mismatch in `mlx-swift-lm 3.31.3`
- Error: `Mismatched parameter model.per_layer_model_projection.weight. Actual [10752, 640], expected [10752, 2560]`

## Decision

**Switch the default text model to `mlx-community/Qwen3.5-9B-OptiQ-4bit`.**

Gemma 4 cannot be evaluated due to a framework-level loading bug. Between the two Qwen variants, OptiQ is superior on every evaluated dimension at zero disk-size cost.

## Results

### Cleanup (1 case)

| Criteria | Baseline (MLX-4bit) | OptiQ |
|----------|---------------------|-------|
| Paragraph breaks | ❌ **None** — single run-on line | ✅ Proper — 4 logical paragraphs |
| Content preservation | ✅ All facts | ✅ All facts |
| Readability | Poor | Good |

**Critical finding**: The baseline completely ignores the prompt instruction to add blank lines between logical sections. The output is a 2000+ character wall of text. OptiQ follows the formatting rule correctly. This alone justifies the switch.

### Enrich (4 cases)

| Case | Baseline Issues | OptiQ Issues |
|------|----------------|--------------|
| 01_work_week | Summary adds "productive", "successful"; changes "revealed"→"discussed" | Near-exact match |
| 02_personal_only | Missing 2 tags (`beach`, `food`) | Missing 1 tag (`beach`) |
| 03_mixed_topics | Perfect | Perfect |
| 04_side_project | Changes "author"→"speaker", "begins"→"initiates"; invents "system" framing | Changes "author"→"speaker" but keeps "begins"; less severe invention |

**Finding**: OptiQ produces summaries that stay closer to ground truth with fewer semantic alterations and better tag coverage.

### Filename (8 cases)

| Case | Baseline | OptiQ |
|------|----------|-------|
| Exact matches | 4/8 | 5/8 |
| Format validity | 8/8 | 8/8 |

**Finding**: OptiQ improves on one case where the baseline drops a meaningful qualifier ("new" in "deploying-new-authentication-system"). Both models fail identically on the two hardest cases, indicating those are prompt-level challenges rather than model weaknesses.

## Consequences

### Positive

- **Better cleanup formatting** — paragraph breaks actually work now
- **More faithful summaries** — fewer hallucinated qualifiers and framing changes
- **Better tag coverage** — captures more expected metadata
- **Same download size** — ~6 GB, no additional disk cost
- **Drop-in replacement** — same tokenizer, same chat template, no prompt changes
- **Frictionless future switching** — `--model` flag added to `cl pipeline` and `cl resume` for one-off experiments

### Negative

- **One-time re-download** — users who already have the old model will download ~6 GB again
- **Not a dramatic improvement everywhere** — some cases are identical between both models
- **Gemma 4 remains unevaluated** — if the loading bug is fixed later, we'd need to re-run this evaluation

### Neutral

- **Config key names unchanged internally** — still `qwenModelId` / `qwenModelFolder` in the struct to avoid breaking existing `config.json` files. User-facing labels updated to "Text model" / "Text model folder".

## Alternatives Considered

1. **Keep the baseline model** — Rejected. The formatting failure in cleanup is a critical functional regression.
2. **Switch to Gemma 4** — Blocked. Cannot load with current `mlx-swift-lm`. Would require waiting for a framework fix and re-evaluating.
3. **Rename config struct properties to `textModelId`** — Rejected. Would break existing `config.json` files and require migration logic. The internal names don't matter; user-facing labels are sufficient.

## Migration Path for Users

```bash
# Download once (~6 GB)
swift run cl warm --model mlx-community/Qwen3.5-9B-OptiQ-4bit

# Set as default (optional — already the new default)
swift run cl config set textModelId mlx-community/Qwen3.5-9B-OptiQ-4bit

# Try a different model for one run
swift run cl pipeline --input audio.m4a --model mlx-community/SomeOther-Model-4bit
```

## Related

- Evaluation reports (generated, not version-controlled): `eval/*/reports/2026-04-21_model-comparison.md`
- Consolidated report: `docs/model-evaluation-2026-04-21.md` (generated during evaluation)
- `mlx-swift-lm` release notes: Gemma 4 support claimed in 3.31.3 but OptiQ checkpoints trigger shape mismatch

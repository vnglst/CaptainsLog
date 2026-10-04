# ADR-004: Reject Qwen3.6 27B RAM 16GB MLX on 16 GB Macs

> **[SUPERSEDED]** — This ADR evaluated an MLX-format model when the project used `mlx-swift-lm`. As of 2026-06-09, CaptainsLog migrated to llama.cpp with GGUF-format models. The core finding (27B models are too large for 16GB Macs) remains valid regardless of framework.

**Status**: ~~Rejected~~ Superseded  
**Date**: 2026-05-16

## Context

CaptainsLog's text-processing pipeline (cleanup, filename generation, metadata enrichment) runs fully on-device via MLX. The app currently targets Apple Silicon laptops and desktops, including machines with 16 GB of unified memory.

We temporarily configured the text model override to use `baa-ai/Qwen3.6-27B-RAM-16GB-MLX` for cleanup and related text stages. The goal was to see whether a newer, larger model would improve output quality enough to justify the extra resource cost.

## Observation

On an M4 machine with 16 GB of unified memory, this model was too large to use safely in CaptainsLog.

Observed behavior:

- Model loading and/or inference pushed memory pressure high enough to freeze the system
- The machine became unresponsive during text-processing work
- This made the model unusable for normal cleanup, filename, and enrich runs

This failure happened before any quality gain could matter. A model that freezes the target machine is not a viable option for the app.

## Decision

**Reject `baa-ai/Qwen3.6-27B-RAM-16GB-MLX` for CaptainsLog on 16 GB Macs.**

Remove the config override and fall back to the default text model, `mlx-community/Qwen3.5-9B-OptiQ-4bit`.

The deciding factor is hardware fit, not benchmark quality. Even with sequential inference and no parallel model runs, a 27B checkpoint is too close to the memory ceiling for the app's target class of machines.

## Consequences

- `baa-ai/Qwen3.6-27B-RAM-16GB-MLX` should not be recommended as a default or suggested override for 16 GB systems
- The default text model remains `mlx-community/Qwen3.5-9B-OptiQ-4bit`
- Future text-model evaluations must treat machine responsiveness and memory headroom as first-class acceptance criteria, not just output quality
- Larger checkpoints may still be worth testing on machines with substantially more unified memory, but that would be a separate evaluation target

## Future Watch

- Re-evaluate only if a smaller quantized variant of Qwen 3.6 becomes available in MLX format with materially lower memory pressure
- Re-evaluate on higher-memory Apple Silicon hardware if there is reason to believe the quality gain justifies the latency and download cost
- Prefer candidates in the same operational envelope as the current default: safe on-device inference, no system freezes, and compatibility with `mlx-swift-lm`
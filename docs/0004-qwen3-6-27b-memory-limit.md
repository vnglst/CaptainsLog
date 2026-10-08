# ADR-004: Reject Qwen3.6 27B RAM 16GB MLX on 16 GB Macs

**Status**: Superseded (previously Rejected)
**Date**: 2026-05-16

## Context

The MLX text pipeline targeted Apple Silicon machines with 16 GB unified memory.
We tried `baa-ai/Qwen3.6-27B-RAM-16GB-MLX` to assess whether a larger model could
improve cleanup, filenames, and enrichment.

On a 16 GB M4, loading or inference caused memory pressure and system freezes.
This happened even with sequential inference. Responsiveness failed before any
output-quality gain could justify the cost.

## Decision

Reject this model for CaptainsLog on 16 GB Macs. Remove the override and restore
the then-default `mlx-community/Qwen3.5-9B-OptiQ-4bit`.

## Consequences

Model evaluations must consider machine responsiveness and memory headroom
alongside output quality. Do not recommend the rejected checkpoint for 16 GB
systems. Smaller variants or higher-memory hardware require separate evaluation;
this finding does not establish their behavior.

## Supersession

The project migrated from MLX to llama.cpp/GGUF on 2026-06-09. The specific MLX
checkpoint and fallback are historical; safe memory headroom remains a model
selection constraint. See [ADR-005](0005-use-libllama-c-api-for-text-inference.md)
for the subsequent inference boundary.

# ADR-001: Switch Default Text Model to Qwen3.5-9B-OptiQ-4bit

**Status**: Superseded
**Date**: 2026-04-21
**Deciders**: OpenCode (automated evaluation), Koen van Gilst (final approval)

## Context

The original MLX text pipeline used uniform 4-bit Qwen3.5-9B. We compared it
with mixed-precision OptiQ at approximately the same download size, using one
cleanup, four enrichment, and eight filename cases. Gemma 4 could not load
because of a framework parameter-shape mismatch.

## Decision

Switch the MLX default to `mlx-community/Qwen3.5-9B-OptiQ-4bit`. OptiQ followed
cleanup paragraph instructions that the baseline ignored, produced more faithful
summaries, and improved one filename without a larger download. Keep the existing
configuration property names to avoid a migration.

## Consequences

Existing users needed a one-time model download. Results were limited to the
small evaluated corpus; some cases were unchanged and Gemma remained unevaluated.

## Supersession

The project migrated from MLX to llama.cpp/GGUF on 2026-06-09. The MLX model
choice and migration commands are historical. The subsequent
[in-process libllama decision](0005-use-libllama-c-api-for-text-inference.md)
describes the shared app/CLI inference boundary.

[Detailed comparison and historical migration instructions](model-evaluation-2026-04-21.md).

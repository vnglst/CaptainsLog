# ADR-005: Use libllama C API for Text Inference

**Status**: Accepted
**Date**: 2026-06-12

## Context

The first llama.cpp migration used `llama-cli` through `/usr/bin/script` and parsed terminal output. That was fragile because `llama-cli` is an interactive UI, not an API: banners, prompt echoes, terminal wrapping, and control characters could leak into model output.

CaptainsLog needs reliable CLI-testable inference and a path to a self-contained app bundle.

## Decision

Use llama.cpp in-process through `libllama` and a small SwiftPM `CLlama` system-library target.

`LLM.loadModel` loads the GGUF model with `llama_model_load_from_file`. `LLM.generate` tokenizes, decodes, samples, and detokenizes through llama.cpp directly. No terminal output is parsed.

## Consequences

- Removes `llama-cli`, `/usr/bin/script`, and all TTY parsing from inference.
- CLI and SwiftUI use the same `CaptainsLogCore` inference path.
- Output shape must be controlled by prompts, not post-processing.
- Development currently depends on Homebrew llama.cpp headers/libs.
- Runtime packaging must bundle llama.cpp dylibs separately.
- Inference is serialized because llama.cpp model/context usage should not be treated as generally thread-safe.

## Local hybrid search

Reuse the in-process libllama runtime for multilingual-e5-small embeddings.
Keep Markdown logs canonical and the SQLite FTS5/sqlite-vec index disposable.
Return keyword and semantic matches as notes and excerpts; do not generate
answers through Qwen. Pin model/runtime artifacts and serialize native state.

[Search implementation details and integration limits](search-architecture.md).
[Testing workflow](testing.md) and [verification history](testing-verification.md)
cover checks; runtime packaging work is tracked in the [backlog](../backlog/tasks/).

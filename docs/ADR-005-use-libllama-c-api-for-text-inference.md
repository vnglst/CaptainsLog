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

## Verification

- `swift build`
- `swift run cl warm`
- `swift run run-tests`
- Full pipeline fixture: `eval/transcribe/audio/2025-01-14 side project.m4a`
- cleanup, filename, enrich evals

## Follow-up

Replace Homebrew build-time paths with a vendored or project-built llama.cpp runtime built for the app deployment target.

## Extension: local hybrid search

The completed search implementation uses the same in-process libllama boundary for `intfloat/multilingual-e5-small` embeddings. This avoids a second runtime, service, daemon or IPC. CLI and SwiftUI share `CaptainsLogCore` search code; queries retrieve notes and excerpts rather than generating answers through Qwen.

- Use the Q8_0 GGUF from `TwinSunsLLC/multilingual-e5-small-gguf`, revision `b6cac9615d4ecce28d7f22539b7322d695fc2886`, SHA-256 `e011debc1208e31bf7b6aebee2d9fc8bd2ca11694a77ed66ac9d0c9d0a877c93` (132,439,008 bytes). The upstream model is MIT-licensed, supports multilingual retrieval and returns 384-dimensional vectors. Pin and verify the converted artifact; download lazily on first search/index build.
- Mean-pool and L2-normalize embeddings, using E5 `query: ` and `passage: ` prefixes. Chunk with the model tokenizer at 384 tokens and 48-token overlap; bound title/metadata so the full embedding input fits its context. Version the chunking policy.
- Vendor and statically register sqlite-vec v0.1.9 (MIT/Apache-2.0) with SQLite. The amalgamation archive SHA-256 is `b87cdda12112657ba5ab8842f0088a4090982eaf41f22b2bd6d495b81765a8c9`. No user-installed SQLite extension is required.
- Keep canonical completed Markdown under `logs/`; `<dataDir>/.search/search.sqlite` is a disposable derived index. Store document fingerprints, chunks, FTS5 text and `vec0` cosine vectors. Rebuild when schema, model identity/dimension or chunker version changes.
- Reconcile added/changed/deleted notes incrementally. Update each document atomically and delete vector/FTS rows explicitly alongside chunk rows; virtual tables cannot rely on foreign-key cascading.
- Return BM25 keyword matches first, then cosine-ranked semantic matches, deduplicated to one best passage per entry. Highlight exact query terms; use relative top-k ranking without a user-facing similarity cutoff.
- Expose `cl search-index [--rebuild] [--data-dir <path>]` and `cl search <query> [--limit 10] [--data-dir <path>]`. The app debounces/cancels superseded queries, restores the timeline for an empty query, and reserves layout space for progress/errors.

SQLite/libllama state stays within serial execution boundaries. Search operates offline after model download; indexing must not block the main actor or mutate canonical notes. The converted GGUF and pre-1.0 sqlite-vec require pinned artifacts and explicit migration/recovery checks.

Verification uses deterministic fake embeddings plus the English/Dutch/German corpus in [eval/search](../eval/search/README.md). Review each query's expected top entries, false positives and excerpts; aggregate scores alone are insufficient. Real-model relevance, offline packaged-app search, interrupted download/indexing, corrupt model/index recovery, data-folder switching and edit/rename/Trash convergence remain integration checks. See [ADR-007](ADR-007-framework-free-test-coverage.md) for dated evidence and acceptance gaps.

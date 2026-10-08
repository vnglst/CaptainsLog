# ADR-019: Use a Disposable Local Hybrid Search Index

**Status**: Accepted
**Date**: 2026-10-08

## Context

Markdown entries are canonical. Search must retrieve relevant notes offline without a second inference service or generated answers. This record preserves the existing search decisions formerly held in a separate implementation document; it introduces no runtime change.

## Decision

Use in-process libllama for multilingual-e5-small Q8_0 embeddings and a disposable SQLite FTS5/sqlite-vec index. Mean-pool and L2-normalize 384-dimensional vectors, with E5 query/passage prefixes. Tokenize chunks at 384 tokens with 48-token overlap and bound metadata to fit model context.

Pin the embedding conversion at revision `b6cac9615d4ecce28d7f22539b7322d695fc2886`, SHA256 `e011debc1208e31bf7b6aebee2d9fc8bd2ca11694a77ed66ac9d0c9d0a877c93`. Vendor sqlite-vec v0.1.9; its source archive SHA256 is `b87cdda12112657ba5ab8842f0088a4090982eaf41f22b2bd6d495b81765a8c9`.

Keep the derived index under `.search/`. Rebuild when schema, model identity/dimensions or chunking version changes. Reconcile edits and deletions atomically, explicitly deleting vector and FTS rows. Return BM25 matches first, followed by cosine-ranked semantic matches, deduplicated per entry. Do not add a user-facing similarity cutoff or Qwen-generated answer.

Serialize native state, keep indexing off the main actor and preserve canonical notes. CLI and app share core search behavior; app queries debounce and cancel superseded requests.

## Consequences

Offline search requires an initial verified model download. The index can be rebuilt. Tests with fake embeddings cannot prove native relevance, packaged-app operation or corruption/download recovery; release tasks retain those checks. This elaborates ADR-005’s existing in-process boundary.

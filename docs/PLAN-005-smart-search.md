# PLAN-005: Local hybrid search

> **Status:** The CLI and app search described here are implemented. This document retains the architecture and original implementation checklist; its SwiftUI build steps are historical. Remaining product work is listed in [PLAN-004](PLAN-004-logs-implementation.md).

## Objective

Add keyword-first and semantic search over completed CaptainsLog entries while preserving
the app's local-only, single-process architecture. Exact words use SQLite FTS5/BM25;
multilingual E5 fills the remaining results with related passages. Both paths return
relevant passage snippets from the SwiftUI app and `cl`.

## Research decision

### Embedding model: `intfloat/multilingual-e5-small`

- MIT-licensed open weights.
- 118M parameters, 384-dimensional embeddings, and a 512-token input limit.
- Supports approximately 100 languages, including the English, Dutch, and German content
  already represented in this repository.
- Designed for retrieval. Stored chunks use the required `passage: ` prefix and user
  searches use `query: `.
- Run a Q8_0 GGUF through the libllama C API already used by CaptainsLog. The selected
  artifact is about 126 MiB and avoids adding ONNX Runtime, Python, Ollama, a daemon, or
  another inference abstraction.
- Pin the GGUF repository revision and expected SHA-256. The runtime artifact is a
  third-party format conversion of the upstream MIT model, so checksum verification is a
  release requirement rather than an optional hardening task.

Selected runtime artifact:

- Repository: `TwinSunsLLC/multilingual-e5-small-gguf`
- File: `multilingual-e5-small-q8_0.gguf`
- Quantization: Q8_0
- Revision: `b6cac9615d4ecce28d7f22539b7322d695fc2886`
- Size: 132,439,008 bytes
- SHA-256: `e011debc1208e31bf7b6aebee2d9fc8bd2ca11694a77ed66ac9d0c9d0a877c93`

Q8 is preferred over Q4 here: it is only about 11 MiB larger while the publisher reports
cosine output within 0.0001 of its full-precision reference.

### Vector database: SQLite plus `sqlite-vec`

- `sqlite-vec` is an MIT/Apache-2.0, dependency-free SQLite extension distributed as a
  single C amalgamation.
- Pin the stable `v0.1.9` amalgamation archive. Its published ZIP SHA-256 is
  `b87cdda12112657ba5ab8842f0088a4090982eaf41f22b2bd6d495b81765a8c9`.
- It supports fixed-size float vectors, cosine distance, and K-nearest-neighbour queries
  through a `vec0` virtual table.
- Vendor a pinned release of the amalgamated C source and statically register it with the
  app's SQLite connection. Do not rely on a Homebrew install or a dynamically loaded
  extension on the user's Mac.
- The database is a disposable derived index. Markdown under `logs/` remains the source
  of truth.

This is a better fit than Qdrant, Chroma, Weaviate, or LanceDB for this phase because it
does not introduce a server, sidecar process, second language runtime, or IPC. Plain
SQLite without `sqlite-vec` was also considered, but it would make CaptainsLog own the
vector-distance scan and storage validation that the extension already provides.

## Locked MVP behavior

- Search only fully processed Markdown files under `logs/personal`, `logs/professional`,
  and `logs/side-project`.
- Search runs entirely on-device and works offline after the embedding model has been
  downloaded once.
- Download the embedding model lazily on first search or explicit index build, not during
  first-run setup.
- Return entries, not raw chunks. Rank each entry by its best matching chunk and return at
  most one result per entry.
- Return BM25-ranked keyword matches first, then cosine-ranked semantic matches. Highlight
  exact query terms in the title and displayed passage.
- Show the best matching chunk as the result excerpt. Do not expose an arbitrary similarity
  cutoff; E5 scores are intended for relative top-k ranking.
- Rebuild automatically when the model identity, embedding dimension, chunking version, or
  index schema changes.
- Never use real user recordings or notes in tests or evaluation.

## Architecture

```text
logs/**/*.md
    -> SearchIndexer (read, fingerprint, tokenize, chunk)
    -> E5EmbeddingModel via libllama (`passage: ...`)
    -> .search/search.sqlite
         documents + chunks + vec_chunks(float[384], cosine)

query
    -> FTS5/BM25 exact passage matches
    -> E5EmbeddingModel via libllama (`query: ...`) for remaining slots
    -> sqlite-vec top-k related chunks
    -> deduplicate by document, keep best passage
    -> CLI rows or SwiftUI entry results
```

### Core types

Add these to `CaptainsLogCore` so the CLI and app share exactly one implementation:

- `EmbeddingModel`: protocol for embedding text, with a libllama-backed E5 implementation
  and deterministic test doubles.
- `E5EmbeddingModel`: model download, checksum verification, model loading, tokenization,
  mean-pool embedding extraction, and L2 normalization.
- `SearchChunker`: token-aware chunks with a versioned policy.
- `SearchStore`: SQLite connection, migrations, transactions, `sqlite-vec` registration,
  upserts, deletes, and KNN queries.
- `SearchIndexer`: reconciles canonical log files with the derived index.
- `SemanticSearch`: the small public facade used by CLI and UI.

Keep SQLite and libllama pointers contained inside actors or otherwise serial execution
contexts. Do not put search database state in SwiftUI state or `CaptainsLogConfig`.

### Index location and schema

Store the index at `<dataDir>/.search/search.sqlite`. It is safe to delete and recreate.

Suggested schema:

```sql
CREATE TABLE index_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE documents (
    id INTEGER PRIMARY KEY,
    path TEXT NOT NULL UNIQUE,
    stem TEXT NOT NULL,
    slug TEXT,
    display_name TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    indexed_at TEXT NOT NULL
);

CREATE TABLE chunks (
    id INTEGER PRIMARY KEY,
    document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL,
    text TEXT NOT NULL,
    UNIQUE(document_id, ordinal)
);

CREATE VIRTUAL TABLE vec_chunks USING vec0(
    chunk_id INTEGER PRIMARY KEY,
    embedding float[384] distance_metric=cosine
);

CREATE VIRTUAL TABLE chunk_fts USING fts5(
    chunk_id UNINDEXED,
    title,
    passage,
    tokenize = 'unicode61 remove_diacritics 2'
);
```

`index_metadata` records schema version, model repository/revision/file hash, embedding
dimension, and chunker version. Delete vector rows explicitly in the same transaction as
their `chunks` rows; do not assume SQLite foreign keys can cascade into a virtual table.

### Chunking policy

- Strip YAML delimiters but retain useful title, summary, tags, projects, and body text.
- Tokenize with the embedding model's own tokenizer.
- Build chunks of at most 384 model tokens with a 48-token overlap, leaving room below the
  model's 512-token limit for the `passage: ` prefix and metadata.
- Prefer paragraph boundaries when they fit; split oversized paragraphs by token count.
- Embed `passage: <display name>\n<metadata>\n<chunk text>`.
- Store clean chunk text without the E5 prefix so the UI can display it directly.

The chunk size and overlap are starting values, not permanent truth. Give the policy a
version and tune it only against the search evaluation set.

### Incremental synchronization

1. Enumerate completed entries using the same canonical pipeline listing logic as the app.
2. Hash the exact normalized indexing input with SHA-256.
3. Remove indexed documents whose canonical Markdown no longer exists.
4. Skip documents with the same content hash.
5. Re-chunk and re-embed new or changed documents in a transaction.
6. Commit each document atomically so interruption never leaves a partially updated entry.

Run reconciliation before each CLI search. In the app, reconcile when the search screen is
first opened and after the existing debounced directory watcher reports changes. Indexing
must run away from the main actor and expose progress/cancellation.

## User interfaces

### CLI first

Add commands before building the SwiftUI surface:

```bash
swift run cl search-index [--rebuild] [--data-dir <path>]
swift run cl search "what did I decide about local databases?" [--limit 10] [--data-dir <path>]
```

`search-index` reports model download/index progress and counts for added, updated,
unchanged, and removed documents. `search` performs an incremental sync, prints ranked
entry paths and excerpts, and exits non-zero on model/index failures.

### SwiftUI

- Add a stable search field to the Logs workspace header; its reserved geometry must obey the
  no-layout-shift rule.
- Debounce typing and cancel superseded query tasks.
- While the model downloads or the first index builds, show fixed-height progress in the
  results area.
- Search results reuse the entry-row visual language and show title, date, and the best
  matched excerpt. Selecting a result opens the existing entry detail view.
- An empty query restores the chronological entry timeline. Distinguish "no matches" from
  "index/model failed" and offer retry for the latter.
- Add deterministic design fixtures for downloading, indexing, results, no results, and
  failure states.

## Implementation milestones

### Milestone 1 — Embedding proof

- Pin and document the model artifact, revision, checksum, and upstream license.
- Add lazy download and checksum validation.
- Extend the existing libllama integration to create an embedding context with mean pooling.
- Verify vector dimension, normalization, determinism, query/passage prefixing, multilingual
  similarity, cancellation, and model cleanup in a small CLI/internal harness.

Exit criterion: the same text embedded twice is stable, and a small English/Dutch/German
smoke corpus retrieves the intended passage.

### Milestone 2 — Embedded database and indexer

- Vendor a pinned `sqlite-vec` amalgamation and license; statically link it with SQLite.
- Implement schema creation/migration and assert `vec_version()` at startup.
- Implement versioned chunking, transactional indexing, stale-row deletion, rebuild, and
  KNN lookup.
- Keep `.search/` out of source entry discovery and directory-watch feedback loops.

Exit criterion: create, edit, rename, and Trash operations all converge to the correct index
without touching canonical Markdown.

### Milestone 3 — CLI vertical slice

- Add `search-index` and `search` commands with useful progress and errors.
- Exercise them against temporary fixture data directories.
- Document setup and usage in the main README.

Exit criterion: semantic search is usable and diagnosable without launching SwiftUI.

### Milestone 4 — Search evaluation gate

- Add a synthetic `eval/search/` corpus with English, Dutch, and German entries.
- Include semantic paraphrase, cross-language, named-entity, unrelated-query, long-entry,
  and near-duplicate cases.
- Record expected top entries for each query and report ranking changes rather than hiding
  them behind one aggregate score.
- Add unit tests with a fake embedder for schema, grouping, sync, and failure behavior, plus
  an opt-in real-model integration suite.

Exit criterion: all must-match queries retrieve their expected entry in the top three, with
no critical cross-language regression accepted without review.

### Milestone 5 — SwiftUI integration

- Add observable search state to a focused search manager owned by `AppState`.
- Implement the fixed-layout search field, progress/error states, result list, cancellation,
  keyboard focus, and result navigation.
- Run the Logs fixture/capture loop and a packaged-app smoke test.

Exit criterion: searching never blocks recording or the main thread, entry changes appear
without manual rebuilds, and every state is keyboard and VoiceOver accessible.

## Verification

- `swift run run-tests`
- `bash scripts/test-coverage.sh`
- `swift build`
- `./scripts/build-app.sh`
- Run the synthetic search evaluation with the pinned real model.
- Launch the packaged app offline after the model has been cached.
- Verify clean install/first search, cancellation during download and indexing, corrupt
  model recovery, corrupt index recovery, data-directory switching, entry edit/rename/
  Trash, empty corpus, long entry, and queries in English, Dutch, and German.
- Confirm the final app bundle does not depend on Homebrew's SQLite extension or any service.

## Risks and deliberate limits

- The selected GGUF is a third-party conversion. Pinning and checksum verification reduce
  supply-chain and accidental-update risk; a future release could publish a project-owned,
  reproducibly converted artifact.
- `sqlite-vec` is still pre-1.0, so its pinned version and schema need explicit migration
  tests. Its small C surface and disposable index keep that risk contained.
- Keyword results intentionally form the first relevance tier. Semantic results broaden
  recall only after exact matches, so a weak token overlap cannot outrank a clear related
  passage within the semantic tier.
- This phase returns matching notes. It does not generate answers, summarize across notes,
  or send retrieved text into Qwen.

## Primary references

- [Multilingual E5 model card](https://huggingface.co/intfloat/multilingual-e5-small)
- [Selected Q8 GGUF artifact and conversion notes](https://huggingface.co/TwinSunsLLC/multilingual-e5-small-gguf)
- [llama.cpp embedding example](https://github.com/ggml-org/llama.cpp/discussions/7712)
- [sqlite-vec repository](https://github.com/asg017/sqlite-vec)
- [sqlite-vec installation and static-linking options](https://github.com/asg017/sqlite-vec/blob/main/site/getting-started/installation.md)
- [sqlite-vec KNN and cosine-distance queries](https://alexgarcia.xyz/sqlite-vec/features/knn.html)

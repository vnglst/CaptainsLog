---
id: TASK-28
title: Use a pinned project-built llama runtime in release builds
status: To Do
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-04 13:57'
labels:
  - distribution
dependencies: []
documentation:
  - docs/0005-use-libllama-c-api-for-text-inference.md
  - docs/0006-bundle-llama-runtime-in-app.md
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Replace Homebrew build-time runtime paths with a pinned project-built or vendored llama.cpp/ggml/libomp runtime targeting macOS 26.0; verify deployment targets and reject leaked Homebrew runtime paths in packaged builds. See [ADR-005](../../docs/0005-use-libllama-c-api-for-text-inference.md#follow-up) and [ADR-006](../../docs/0006-bundle-llama-runtime-in-app.md#follow-up).
<!-- SECTION:DESCRIPTION:END -->

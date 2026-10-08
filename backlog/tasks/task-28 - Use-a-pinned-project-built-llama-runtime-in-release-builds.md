---
id: TASK-28
title: Use the same pinned native runtime for development and release builds
status: Verify
assignee: []
created_date: '2026-10-04 13:10'
updated_date: '2026-10-09 05:23'
labels:
  - distribution
dependencies: []
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Local development and release builds currently resolve llama.cpp, GGML and libomp from mutable Homebrew installations. A 2026-10-07 header upgrade invalidated a precompiled Swift module during app/CLI packaging, demonstrating that the same checkout can build differently or fail after unrelated system updates.

Use the same pinned native libraries and matching headers for local development and release builds, targeting macOS 26.0. The owner permits verified prebuilt libraries and requires reproducibility. Record the compiler/toolchain and build configuration needed to reproduce compatible artifacts. ADR-005 and ADR-006 describe the current runtime integration; TASK-45 handled the immediate stale-header repair.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 llama.cpp, GGML and required native runtime dependencies are pinned to immutable source revisions or checksum-verified artifacts, with matching headers and libraries; verified prebuilt libraries are permitted.
- [x] #2 Local development and release builds use the same pinned native libraries. Documented clean builds succeed without Homebrew llama.cpp, GGML or libomp and ignore unrelated system versions of those libraries.
- [x] #3 The native toolchain, deployment target, architecture and build options are recorded; two clean builds with the same declared inputs produce matching unsigned runtime artifacts or document and test any unavoidable nondeterminism.
- [x] #4 The packaged app and CLI bundle the pinned runtime, target macOS 26.0, pass signature and fixture smoke checks, and contain no Homebrew runtime paths.
- [x] #5 Dependency upgrade instructions, licenses and automated checks prevent accidental fallback to system-installed native libraries.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Use a checksum-pinned upstream llama.cpp XCFramework for matching headers and runtime in every SwiftPM configuration. Adapt app packaging, remove Homebrew fallback, record artifact identity and reproduction/upgrade procedure, then verify clean builds, packaged linkage/signatures, deterministic checks and sequential fixture inference.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Owner selected this work for Next on 2026-10-07 after the release build reused a stale Homebrew llama header module. Scope is reproducible native-runtime builds; immediate header import repair is tracked separately in TASK-45.

Owner clarification on 2026-10-08: verified prebuilt libraries are acceptable; local development and release builds must use the same pinned libraries, with reproducibility required.

2026-10-08: Selected official b11512 XCFramework at source revision a11f57ba93797579a5d1855ee216a31f10242676. Independently checked upstream release SHA-256 3f6a7d0fecbf49781445bba900dc0a4a7e76303482765f5912a4a959d5fa2c38. Two separately downloaded archives verify and extract identical unsigned native code and headers. Runtime combines llama/GGML, enables Metal/Accelerate and embeds shaders; OpenMP is disabled. The prebuilt macOS slice supports 13.3+ (SDK26.4/linker1266.8), while app and CLI retain macOS26.0. Reproducibility is identical prebuilt inputs, not an unverified claim of byte-identical upstream compilation. Evaluation tooling records framework hashes and manifest identity; its 66 orchestration checks pass. Build and packaging verification are in progress.

2026-10-08 verification: swift build passed, swift run run-tests passed all 209 deterministic checks, and the compiled CLI launched with isolated configuration. Release app/CLI compiled and packaging completed with valid ad-hoc signatures, macOS26.0 executable targets, CPU and Metal backends, and no build-machine runtime paths. Both source and binary fallback gates rejected deliberately injected Homebrew paths. A separate full clean build with Homebrew excluded and failing brew/pkg-config sentinels is in progress. Upstream XCFramework includes mtmd; exact license blocks for its merged native helper dependencies are preserved with the runtime notices.

2026-10-09 verification: A second full clean build succeeded with Homebrew excluded from PATH, failing brew/pkg-config sentinels and native include/library environment cleared; neither sentinel was invoked. Original debug, independent clean debug and release framework copies have identical unsigned SHA-256 fe9a5c8a2693150cee4d765117999dae0f4e1d8b2e2adb95bff52e33268a7582. Current make build, make tests (209/209) and make tests-runtime passed. The packaged app and CLI have valid ad-hoc signatures, macOS26.0 executable targets, embedded CPU/Metal runtime, bundled project/native helper licenses and no Homebrew/build-machine runtime paths. Both debug UI harness and signed release app launched with isolated empty fixture data and remained alive until deliberately closed. System Ruby2.6 evaluation orchestration passed66 checks; release tooling checks and ADR validation passed.

2026-10-09 full audio evaluation: make evals-pipeline completed actual repository audio transcription, cleanup, category, filename and enrichment; all5 mechanical cases passed, followed by resume immutability and E5 search-index/readback assertions. Semantics: all main voice-log/iCloud/Whisper/local-model workflow details remain; transcription mistakes include vollendje, liefdelokaal and science/site project. Cleanup repairs the first two and retains science project. Category side_project and filename 2025-01-14-side-project-star-trek-voice-log match the intended topic. Enrichment retains the cleaned body and grounded entities; its summary omits optional notification/original-audio detail and calls the polished narrative summaries. Recording time20:20 is the evaluator-supplied pipeline time, distinct from the reference12:00/spoken half-eight. No paired baseline or upstream source-byte reproducibility claim is made. Signed packaged CLI filename smoke produced2025-01-15-deploying-oauth2-authentication.md from the authentication fixture; its topic is grounded and its date/format valid.

2026-10-09 filename suite: All eight cases generated through one Qwen model load. Seven passed mechanical validation; the side-project case followed the January14 date stated in its text/reference instead of the separately supplied January15, so make evals STAGE=filename exited2. Its topic matched the reference exactly. This quality limit is preserved without changing prompts, fixtures or validators. Semantic review of every case found grounded topics: multi-topic output also names the event pipeline; career output weakens the explicit management-versus-staff contrast; technical output retains SQS/SNS migration and circuit breakers; garden output names layout/vegetables/compost/fence/pond without repeating garden. No fabricated topic was found. Owner review remains required.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Development and release builds now share the checksum-pinned b11512 native framework and matching headers. Clean Homebrew-independent build, identical unsigned native hashes, 209 deterministic checks, package signatures/linkage and actual full audio pipeline/search checks passed. Signed release CLI filename smoke passed. Full filename suite generated eight outputs with seven mechanical passes and one supplied-date conflict; semantics and reproducibility limits are recorded for owner review.
<!-- SECTION:FINAL_SUMMARY:END -->

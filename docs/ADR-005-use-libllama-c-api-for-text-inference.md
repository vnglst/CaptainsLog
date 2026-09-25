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

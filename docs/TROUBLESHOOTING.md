# Troubleshooting

Find active files in the [source map](SOURCE-MAP.md). Reproduce processing problems with [repository fixture evaluations](EVALUATIONS.md) and isolated config/data before using the UI. Never use personal notes or recordings for debugging.

## Whisper / CoreML errors

The current [Transcriber.swift](../Sources/CaptainsLogCore/Transcriber.swift) explicitly uses `.cpuAndGPU` for both the audio encoder and text decoder. Advice to disable ANE in a default `WhisperKitConfig` describes older code. If `MILCompilerForANE` appears, identify the running bundle/revision with [local build identification](LOCAL-DEVELOPMENT.md#identify-and-roll-back) and compare its transcription configuration before changing compute settings.

A Metal assertion was recorded on the Dutch fixture in [ADR-007](0007-framework-free-test-coverage.md#dated-verification-evidence). A failed transcription is not a successful pipeline run, even if transcript-seeded downstream stages pass. Capture the failing fixture run's logs and model identity; do not substitute personal audio. Run compilation and inference separately, and never run model tasks concurrently.

## llama.cpp setup and runtime

Text inference uses the in-process libllama C API, not `llama-cli` or terminal-output parsing. Source builds require `brew install llama.cpp` and resolve llama/GGML headers through pkg-config; packaged builds bundle their runtime libraries. `Sources/CaptainsLogCore/LLM.swift` requests `n_gpu_layers = -1` (all available layers), not a fixed 41-layer setting.

The app downloads its Qwen model during setup. For source-build fixture checks, point the [evaluation runner](EVALUATIONS.md#isolation-and-models) at installed model files; it records the actual GGUF hash rather than assuming the label identifies the file. `cl warm` is a standalone inference smoke check; set an isolated `CAPTAINS_LOG_CONFIG_PATH` first. Do not run it concurrently with evaluations.

For a missing library/header, inspect `pkg-config --cflags --libs llama ggml` and `otool -L <path-to-cl>`. A missing `llama-cli` executable does not diagnose this app's C API integration. Check the bundled binary and `Contents/Frameworks` when a packaged app differs from a source build.

For slow inference or out-of-memory errors, first stop other inference/compilation and verify the actual model and runtime. The supported model is Qwen 3.5 9B Q4_K_M; arbitrary smaller models/quantizations are not established quality substitutes. Context allocation follows `LLM.plannedContextSize` and the request's token count, bounded by the model maximum. Generation exhaustion reports the allocated context; output-limit failures discard unfinished responses. Shorten a synthetic fixture only to isolate a size-related failure, preserving the original failing case and findings.

## URL cache warnings

A bare Swift executable can emit a URL-cache persistence warning. Check whether the requested download actually completed before treating the warning as a processing failure. Use the packaged development bundle for bundle-specific behavior; see [local installation and rollback](LOCAL-DEVELOPMENT.md).

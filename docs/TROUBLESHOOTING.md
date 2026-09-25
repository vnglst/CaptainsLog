# Troubleshooting

## ANE compilation error (MILCompilerForANE error)

If you encounter this error during transcription:
```
MILCompilerForANE error: failed to compile ANE model using ANEF
```

The Apple Neural Engine (ANE) failed to compile the Whisper model. This can happen with certain model versions or macOS configurations. **ANE is ~2-3x faster than CPU+GPU**, so the default keeps it enabled. If you need to disable ANE:

```swift
// In Sources/CaptainsLogCore/Transcriber.swift, replace:
let whisperConfig = WhisperKitConfig(modelFolder: folder)

// With:
let computeOptions = ModelComputeOptions(
    audioEncoderCompute: .cpuAndGPU,
    textDecoderCompute: .cpuAndGPU
)
let whisperConfig = WhisperKitConfig(
    modelFolder: folder,
    computeOptions: computeOptions
)
```

## URL cache warning (failed to write cached response)

If you see this warning when running the SwiftUI app:
```
ERROR: failed to write cached response to ~/Library/Caches/CaptainsLogApp. Falling back to old persistent store mechanism.
```

**This is harmless.** It can occur when launching the app as a bare Swift executable with `swift run`, rather than from the packaged `.app`. The `swift-transformers` library tries to persist URL cache to disk and falls back to its older persistent-store mechanism. Downloads still complete.

No fix is currently required. The packaged Homebrew app is installed as a proper `.app` bundle.

## llama.cpp model setup

The project uses **llama.cpp** for LLM inference with Metal GPU acceleration. The packaged app bundles the llama.cpp runtime and downloads the Qwen GGUF model when needed. The manual setup below is for source builds or a custom model folder.

### Setup Instructions

1. **Install llama.cpp** when building from source (if not already installed):
```bash
brew install llama.cpp
```

2. **Download the Qwen 3.5 9B 4-bit GGUF model:**

   Option A: Use Hugging Face CLI (recommended):
   ```bash
   pip install huggingface-hub
   huggingface-cli download bartowski/Qwen_Qwen3.5-9B-GGUF Qwen_Qwen3.5-9B-Q4_K_M.gguf --local-dir ./models/qwen
   ```

   Option B: Manual download from [Hugging Face model page](https://huggingface.co/bartowski/Qwen_Qwen3.5-9B-GGUF)

3. **Configure CaptainsLog to use the model:**
```bash
cl config set qwenModelFolder /absolute/path/to/models/qwen
```

4. **Test the setup:**
```bash
swift run cl warm
```

You should see output like:
```
Loading Qwen_Qwen3.5-9B-Q4_K_M.gguf...
Output: Hello! I'm happy to help with any questions or tasks you might have.
```

### Metal Acceleration

llama.cpp with Metal support is built-in via Homebrew. The `llama-cli` command automatically uses GPU acceleration when available on Apple Silicon. To verify:

```bash
llama-cli -h | grep -i metal
```

You should see Metal options available.

### Model Size Recommendations

- **Qwen 3.5 9B (Q4_K_M)**: ~5-6 GB, required model for this project

### Troubleshooting llama.cpp

**Issue: "llama-cli not found"**
```bash
# Verify installation
which llama-cli

# If not found, reinstall
brew reinstall llama.cpp
```

**Issue: Model inference is slow**
- Ensure Metal acceleration is available: `llama-cli -h | grep metal`
- Check GPU offload layers setting in LLM.swift (currently set to 41 layers)
- Try a more aggressive quantization (Q4_K_M instead of Q5_K_M)

**Issue: Out of memory**
- Use a quantized (smaller) model: Q4_K_M or Q3_K_M
- Shorten or split exceptionally long input. CaptainsLog sizes each llama.cpp context from the tokenized request, up to the model's native context length.

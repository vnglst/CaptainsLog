# Third-party notices

CaptainsLog includes or downloads third-party software, fonts, and model weights. The application’s source license, if any, is separate from these component licenses. Copies of the licenses for components bundled with the macOS app are placed in `Contents/Resources/ThirdPartyLicenses`.

## Bundled font

**Antonio variable font** — Copyright 2013 The Antonio Project Authors. Licensed under the SIL Open Font License 1.1. The license text is in `Sources/CaptainsLog/Resources/ThirdPartyLicenses/Antonio-OFL-1.1.txt` and is bundled with the app. [Upstream font project](https://github.com/googlefonts/antonioFont).

## Bundled software

| Component | License | Source |
| --- | --- | --- |
| sqlite-vec v0.1.9 | MIT or Apache-2.0 | [sqlite-vec](https://github.com/asg017/sqlite-vec) |
| llama.cpp / ggml runtime | MIT | [llama.cpp](https://github.com/ggml-org/llama.cpp) |
| LLVM OpenMP (`libomp`) runtime | Apache-2.0 with LLVM exception | [LLVM](https://github.com/llvm/llvm-project/tree/main/openmp) |
| Swift Argument Parser | Apache-2.0 | [swift-argument-parser](https://github.com/apple/swift-argument-parser) |
| WhisperKit / argmax-oss-swift | MIT | [argmax-oss-swift](https://github.com/argmaxinc/argmax-oss-swift) |
| Swift Transformers | Apache-2.0 | [swift-transformers](https://github.com/huggingface/swift-transformers) |
| Swift Hugging Face | Apache-2.0 | [swift-huggingface](https://github.com/huggingface/swift-huggingface) |
| SwiftNIO, Swift Crypto, Swift ASN.1, Swift Atomics, Swift Collections, Swift System, Swift Jinja | Apache-2.0 | See pinned revisions in [`Package.resolved`](Package.resolved) |
| llhttp parser bundled with SwiftNIO | MIT | [llhttp](https://github.com/nodejs/llhttp) |
| EventSource | MIT | [EventSource](https://github.com/mattt/EventSource) |
| yyjson | MIT | [yyjson](https://github.com/ibireme/yyjson) |

The app bundle includes the upstream `LICENSE` and `NOTICE` files available for resolved Swift packages and the bundled llama.cpp and OpenMP runtimes. `sqlite-vec` license texts are included in this repository under `Sources/CSQLiteVec/`.

## Models downloaded by the app

Model weights are downloaded to the user's Mac when needed; they are not included in the app archive.

| Model | Source and license information |
| --- | --- |
| Whisper Large-v2 | [OpenAI model files](https://huggingface.co/openai/whisper-large-v2), Apache-2.0 |
| Qwen 3.5 9B GGUF, Q4_K_M | [bartowski conversion](https://huggingface.co/bartowski/Qwen_Qwen3.5-9B-GGUF), Apache-2.0; derived from the [Qwen model family](https://github.com/QwenLM/Qwen3.5) |
| multilingual-e5-small GGUF, Q8_0 | [TwinSunsLLC conversion](https://huggingface.co/TwinSunsLLC/multilingual-e5-small-gguf), MIT; derived from [intfloat/multilingual-e5-small](https://huggingface.co/intfloat/multilingual-e5-small) |

The model repositories may update independently from CaptainsLog. Refer to those repositories for the exact model files, revisions, and current license terms.

## Evaluation and demo content

The demo and evaluation corpus includes unofficial synthetic examples using Star Trek characters and settings. Star Trek and related names remain the property of their respective rights holders. CaptainsLog is independent and is not affiliated with or endorsed by those rights holders.

Evaluation audio includes readings of excerpts associated with *World War Z* by Max Brooks and “Durin’s Folk” by J. R. R. Tolkien. Their underlying text remains the property of its respective rights holders. These are test fixtures, not CaptainsLog product content. The repository owner approved retaining the reviewed fixtures in this repository.

The TNG demo audio was generated locally from synthetic example text using macOS text-to-speech tools. It does not use a third-party voice recording.

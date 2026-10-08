# Third-party notices

CaptainsLog includes or downloads third-party software and model weights. CaptainsLog’s original source code is licensed under the [MIT license](LICENSE). Third-party components and content retain their own licenses and rights; the project license does not replace the terms below. Copies of the licenses for components bundled with the macOS app are placed in `Contents/Resources/ThirdPartyLicenses`.

## Bundled software

| Component | License | Source |
| --- | --- | --- |
| sqlite-vec v0.1.9 | MIT or Apache-2.0 | [sqlite-vec](https://github.com/asg017/sqlite-vec) |
| llama.cpp / ggml runtime | MIT | [llama.cpp](https://github.com/ggml-org/llama.cpp) |
| XCFramework mtmd helpers: stb_image, miniaudio, xxHash, SHA-1/SHA-256, subprocess.h | MIT / MIT No Attribution / BSD-2-Clause / public domain; exact notices bundled with the runtime | [Pinned upstream native helpers](https://github.com/ggml-org/llama.cpp/tree/a11f57ba93797579a5d1855ee216a31f10242676/vendor) |
| Swift Argument Parser | Apache-2.0 | [swift-argument-parser](https://github.com/apple/swift-argument-parser) |
| WhisperKit / argmax-oss-swift | MIT | [argmax-oss-swift](https://github.com/argmaxinc/argmax-oss-swift) |
| Swift Transformers | Apache-2.0 | [swift-transformers](https://github.com/huggingface/swift-transformers) |
| Swift Hugging Face | Apache-2.0 | [swift-huggingface](https://github.com/huggingface/swift-huggingface) |
| SwiftNIO, Swift Crypto, Swift ASN.1, Swift Atomics, Swift Collections, Swift System, Swift Jinja | Apache-2.0 | See pinned revisions in [`Package.resolved`](Package.resolved) |
| llhttp parser bundled with SwiftNIO | MIT | [llhttp](https://github.com/nodejs/llhttp) |
| EventSource | MIT | [EventSource](https://github.com/mattt/EventSource) |
| yyjson | MIT | [yyjson](https://github.com/ibireme/yyjson) |

The app bundle includes the upstream `LICENSE` and `NOTICE` files available for resolved Swift packages and the bundled llama.cpp/GGML runtime. `sqlite-vec` license texts are included in this repository under `Sources/CSQLiteVec/`.

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

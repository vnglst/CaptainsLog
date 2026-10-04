# ADR-003: Qwen3-ASR Evaluation and Reversion

**Status**: Superseded (reverted to Whisper Large-v2)  
**Date**: 2025-04-21

## Context

We evaluated Qwen3-ASR 1.7B 8-bit (via `speech-swift`'s `StreamingASR` with VAD segmentation) as a replacement for WhisperKit Large-v2. The hypothesis was that a newer multilingual ASR model would improve transcription quality for Dutch and mixed-language content. An earlier migration proposal is no longer present in the repository.

## Evaluation Method

We ran both models against the same 4 audio test cases with known ground truth transcriptions:

| Test case | Language | Duration |
|-----------|----------|----------|
| 2025-01-14 side project | Dutch (conversational) | ~4 min |
| alle-mensen-zijn-sterfelijk | Dutch (literature) | ~3 min |
| durins-volk | Dutch (fantasy names) | ~90 sec |
| world-war-z | English (narration) | ~3 min |

## Results

### Critical Errors (Qwen3-ASR)

- **Dropped sentences**: Missing "Het doek ging op", "Ze boog opnieuw", "Florence glimlachte", entire bracketed narrative paragraph (world-war-z)
- **Wrong names**: "Captain Jean-Luc Picard" → "John Duke Picard"; "Pff, Florence" → "Vloog Hans"; "Kwang Jing-shu" → "Kwang Ying Chu"
- **Nonsense words**: "bijgeluiden" → "pijgeliuider"; "draad kwijtraak" → "draadkuit raak"; "Kheled-zâram" → "Kilat saram"; "Khazad-dûm" → "Casadem"
- **Sentence jumbling**: In the long Dutch recording, sentences appeared out of order with duplicated/missing content
- **Missing speaker attributions**: "zei hij", "zei Régine", "zei Annie" all dropped

### Whisper Large-v2 Errors (for comparison)

- **Spelling/grammar**: "provincieszaal" (→ provinciezaal), "wijt en zeit" (→ wijd en zijd), "vlammertje" (→ vlammetje), "kammeren" (→ kammen)
- **False starts preserved**: "Je bent nog nog nooit zo goed gespeeld" (duplicate "nog")
- **Proper noun errors**: "Kuang Ying-choo" (→ Kwang Jing-shu), "Dürin" (→ Durin)
- **But**: No dropped sentences, no sentence jumbling, speaker attributions preserved, no nonsense words

## Decision

**Revert to Whisper Large-v2.**

Qwen3-ASR 1.7B 8-bit, despite being a newer model, produced measurably more critical errors on our test corpus. The errors were structural (dropped sentences, jumbled order) rather than cosmetic (spelling), making them harder to recover in downstream cleanup stages.

The 8-bit quantization may be a contributing factor — bf16 weights might reduce some nonsense-word errors. However, `speech-swift` hardcodes `QuantizedTextModel`, making bf16 usage non-trivial (requires upstream changes or a fork). Given the current performance gap, this investment is not justified.

## Consequences

- WhisperKit Large-v2 remains the transcription backend
- `speech-swift` dependency removed
- `eval/transcribe/reports/` contains detailed per-case comparison data for future model evaluations
- Future ASR evaluations must include all 4 test cases and compare against these ground truths

## Future Watch

- **bf16 Qwen3-ASR**: If `speech-swift` adds native bf16 support, re-evaluate with the same test suite
- **Voxtral Mini 4B**: Impressive streaming model, but no Swift/MLX port exists (only vLLM/Transformers/ExecuTorch-untested). Not viable for CaptainsLog
- **WhisperKit v3 / Distil-Whisper**: Track upstream for accuracy improvements without dependency changes

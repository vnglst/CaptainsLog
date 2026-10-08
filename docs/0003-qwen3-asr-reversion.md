# ADR-003: Qwen3-ASR Evaluation and Reversion

**Status**: Superseded (reverted to Whisper Large-v2)
**Date**: 2025-04-21

## Context

We evaluated Qwen3-ASR 1.7B 8-bit through `speech-swift` StreamingASR with VAD
segmentation against WhisperKit Large-v2 on four Dutch/English fixtures. The
goal was better multilingual transcription; an earlier migration proposal is
no longer present in the repository.

## Decision

Revert to Whisper Large-v2 and remove `speech-swift`.

Qwen dropped sentences and speaker attributions, jumbled order, and corrupted
names and words. Whisper had spelling and proper-noun errors but preserved
sentence order and content in this comparison. Structural losses were harder
to repair downstream than spelling errors.

Quantization might contribute, but that was not established. Native bf16 support
would require upstream changes or a fork because `speech-swift` hardcoded a
quantized text model; the observed quality gap did not justify that investment.

## Consequences

WhisperKit Large-v2 remains the transcription backend. Future replacements must
be compared against all four fixture ground truths, including omissions, order,
names, and speaker attributions. These observations establish the choice for the
tested versions and corpus, not a general ranking of model families.

## Recorded examples

The tested Qwen path dropped “Het doek ging op” and speaker attributions, changed Captain Jean-Luc Picard to John Duke Picard, and corrupted Khazad-dûm. Whisper still misspelled names and words. The comparison concerned the tested streaming/VAD and quantized implementation; it did not establish bf16 behavior or evaluate future backends.

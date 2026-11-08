# Transcription baseline · 2026-10-30

Fresh native Whisper Large-v2 run against the owner-reviewed corrected Dutch recording. Only transcription ran; no downstream generation was used. WER is 3.6575%: 33 substitutions, 2 deletions and 9 insertions across 1,203 reference words. Mechanical validation passes; the reference status is audio-reviewed.

The fresh transcript SHA-256 is identical to the preserved second-round raw output (0747560e67c239ad09c14f2eb856cbed970867e0c9eb49dc816315a128bccb0b). The expected reference is also unchanged. The complete earlier semantic review therefore remains applicable; the fresh alignment and closing output were checked again.

Meaning-changing differences remain: Vanmorgen→Voor morgen shifts the time; Keiko haalde→Kijk ho, haal de obscures the person and action; metingen beïnvloedt→meting hebben invloed damages the radiation/measurement relation; tijdelijk→duidelijk loses the temporary nature of the information gap; eerste weken→eerste week narrows the time period. Guinan, Geordi, Data and Worf also acquire incorrect spellings. Number formatting and compounds such as twaalf→12 and Klingon-schip→klingonschip affect WER without comparable semantic damage.

The corrected vrachtschip sentence is complete. The closing Dutch sentence is complete, but Whisper appends the ungrounded Korean sign-off “MBC 뉴스 김재경입니다”. This remains a transcription hallucination relative to the owner-approved reference and is retained in the raw baseline, not copied into expected text.

This establishes reproducibility for these recorded inputs and runtime, not a semantic quality pass. Earlier comparisons used different audio/reference versions and are not controlled model comparisons. Models, settings, hashes, revision and timing scopes are recorded in metadata.json; the prior review evidence is preserved under ../../review-2/.

# Transcription Report: world-war-z

**Model**: openai/whisper-large-v2  
**Date**: 2026-06-12

## Word Differences

| # | Expected | Got |
|---|----------|-----|
| 1 | thirty-five | 35 |
| 2 | fifty | 50000 |
| 3 | coast | coasts |
| 4 | Kwang | Kuang |
| 5 | Jingshu | Yingchoo |
| 6 | had | has |
| 7 | killed | skilled |

## Missing Words

- thousand

## Added Words

- older
- blankaudio

## Notes

- `fifty thousand` is transcribed as `50000` with `thousand` missing, preserving numeric meaning but changing form.
- `killed` to `skilled` changes meaning.
- The helper output showed a long alignment cascade around the Dachang passage; the listed items above are the meaningful differences rather than every shifted token.

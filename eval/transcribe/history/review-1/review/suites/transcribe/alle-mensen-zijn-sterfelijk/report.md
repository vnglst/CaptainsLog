# Semantic review — 2026-10-29

- Omissions / changed meaning: Je hebt nog nooit zo goed gespeeld becomes Je bent nog nooit zo goed gespeeld, making the sentence malformed. Hare becomes haren; the final self-reflection shifts from zou/niets to zal/niet. Several Régine spellings lose the accent, which the documented normalization preserves.
- Added or hallucinated content: Florence is repeated in the closing paragraph, and the raw output ends with the Korean fragment -네. Both are absent from the reference; the foreign tail is particularly suspicious.
- Improvements / regressions against baseline: no matched older native baseline. Large-v3 also produces haren and drops some words, but its differing omissions cannot settle the reading.
- Stage observations: 16 substitutions, 0 deletions, 2 insertions / 369 reference words = 4.88% provisional WER. Dialogue and narrative sequence remain recognizable. Punctuation changes are ignored.
- Judgment and remaining limits: review the grammatical substitutions and foreign tail against clips before changing the verbatim reference. Reference unchanged.

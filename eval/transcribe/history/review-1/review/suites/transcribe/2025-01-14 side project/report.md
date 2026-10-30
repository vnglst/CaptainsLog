# Semantic review — 2026-10-29

- Omissions / changed meaning: foldertje becomes vollendje, bijgeluiden becomes pijgeluiden and one side project becomes science project. The last change changes the subject label; the first two create malformed words. Other fillers and reordered clauses require listening before reference edits.
- Added or hallucinated content: output ends with [BLANK_AUDIO]. There are extra words around the bijgeluiden passage (al, maken). The bracketed marker is exposed in raw output and included by the declared tokenizer, rather than silently stripped.
- Improvements / regressions against baseline: no matched older native baseline. The independent Large-v3 run adds extensive repeated Star Trek developer claims and repeated Whisper clauses. It is a poor reference for those spans and is shown only as an unverified comparison.
- Stage observations: 8 substitutions, 0 deletions, 6 insertions / 485 reference words = 2.89% provisional WER. All audio segments and both raw transcripts are available in the local review app.
- Judgment and remaining limits: the main pipeline description is retained, but name/word corruption and the output marker need human review. Reference unchanged pending owner verification.

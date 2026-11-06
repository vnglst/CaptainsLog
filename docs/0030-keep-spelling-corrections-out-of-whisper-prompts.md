# ADR-030: Keep spelling corrections out of Whisper prompts

**Status**: Accepted

**Date**: 2026-11-06

1. **A name can be right while the story is wrong.** In one recording, Whisper spelled the doctor’s name correctly but dropped the emergency call at the end. Across four fixtures, it got 19 of 20 target name occurrences right, up from 2, while overall word error rate rose from 4.58% to 12.70%. WhisperKit treats the glossary as prior transcript text, so it can change the surrounding words too.
2. **Some saved corrections would silently stop helping.** Our list has about 30–50 names. WhisperKit keeps only the last 111 prompt tokens. Ten test names already used about 46 tokens, so a similarly composed list would likely lose names from the beginning.
3. **Whole passages can disappear from the transcript.** In the Enterprise test, WhisperKit skipped 30 seconds after it ran out of retries. The prompt moves the transcription marker past the first three tokens, where WhisperKit looks for it, so the timestamp rules are bypassed. Switching to Large-v3 in CaptainsLog would still use that same code.
4. **Users would wait longer even with the timestamp fix.** The diagnostic fix recovered the missing Enterprise passage, but decoding still took 46% longer on that recording. WhisperKit processes the glossary again for every audio window and retry.

**Decision:** Keep spelling corrections in LLM cleanup and leave them out of the Whisper prompt.

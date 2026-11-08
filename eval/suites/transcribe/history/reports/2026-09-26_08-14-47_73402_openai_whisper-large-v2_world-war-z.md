# Transcription Report: world-war-z

**Model**: openai_whisper-large-v2  
**Date**: 2026-09-26

## Word Differences

| # | Expected | Got |
|---|----------|-----|
| 1 | older New Dachang existed | older Dachang existed |
| 2 | “Harley-Davidsons killed more young Chinese” | “Harley-Davidson skilled more young Chinese” |
| 3 | choose to name their newly constructed hamlet | choose the name to name their newly constructed hamlet |
| 4 | (end of spoken passage) | `[BLANK_AUDIO]` |

## Missing Words

- New (in “older New Dachang”)
- killed

## Added Words

- the name to (a duplicated naming phrase)
- `[BLANK_AUDIO]`

## Notes

- “Skilled” changes the claim from Harley-Davidsons killing more young Chinese than the G.I.s to Harley-Davidsons somehow “skilling” them. This changes the passage's central comparison.
- Dropping “New” makes the narrator say they did not know an older Dachang existed, losing the distinction between Old and New Dachang established immediately before.
- “Choose the name to name” repeats the naming action and is not in the source.
- `[BLANK_AUDIO]` is an added non-spoken marker at the end.
- Population figures and the rest of the sequence are preserved. The Chinese name spelling is excluded as a proper-name spelling difference under the skill rules.

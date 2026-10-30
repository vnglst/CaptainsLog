# Transcription Report: 2025-01-14 side project

**Model**: openai_whisper-large-v2  
**Date**: 2026-09-26

## Word Differences

| # | Expected | Got |
|---|----------|-----|
| 1 | foldertje | vollendje |
| 2 | side-project | science project |
| 3 | Liefst een lokaal model | Een liefdelokaal model |
| 4 | side-project | site project |

## Missing Words

- foldertje
- liefst
- lokaal (merged into the malformed token “liefdelokaal”)

## Added Words

- vollendje
- science
- site
- liefdelokaal

## Notes

- “Science project” changes the entry topic from the speaker's side project to a science project. This incorrect phrase is carried into cleanup and the final summary.
- “Een liefdelokaal model” loses the speaker's preference for a local model and does not produce the intended Dutch phrase “liefst een lokaal model.”
- The folder word is badly misrecognized as “vollendje,” though the next clause still explains that recordings will be grouped in a folder.
- Most of the remaining Dutch content, including the Star Trek reference, names, and the proposed audio-to-text workflow, is present. Punctuation and small orthographic differences are omitted here.

The comparison helper suggested these alignments; I verified the actual expected and generated files directly. The helper does not handle the compound “side-project” consistently.

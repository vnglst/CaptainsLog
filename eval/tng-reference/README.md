# TNG recording scripts

Three fictional personal logs aboard the Enterprise: one English, one Dutch and
one German. Each has roughly 1,200 words, intended for about ten minutes of relaxed
reading with natural pauses. Actual duration depends on the speaker. The owner has supplied the Dutch recording; its canonical audio is now
[`../transcribe/audio/tng-nl01-vrije-dag-enterprise-corrected.m4a`](../transcribe/audio/tng-nl01-vrije-dag-enterprise-corrected.m4a).
English and German audio are still to be recorded.

| Script | Language | Topic |
|---|---|---|
| [A week aboard the Enterprise](tng-01-work-week-review.md) | English | A warp nacelle warning, a probe survey and an external repair |
| [Een vrije dag op de Enterprise](tng-nl01-vrije-dag-enterprise.md) | Dutch | The holodeck, Alexander and Molly, Ten Forward and upcoming duties |
| [Sensorstörung auf der Enterprise](tng-de01-sensorstoerung.md) | German | Conflicting sensor readings, a repair and unfinished checks |

The narrator is an unnamed crew member. The stories take place aboard the ship,
with watch duties, engineering work, exploration and time off among the crew.
They are invented recording material, not accounts of specific televised episodes.
The spoken language is conversational rather than a formal mission report.

Each file pairs its narration with a lightly cleaned version, example metadata
and an expected filename. Cleanup preserves the full narration rather than
summarizing it. Dates and times are fixed reference values. Expected wording is a
reference, not the only valid output; review generated text for missing details,
changed meaning and invented content. In particular, preserve the distinction
between completed repairs, planned checks and unresolved questions.

## Evaluation status

The Dutch recording is active in the transcription suite and available as a pending
memo in the isolated development demo. Its script remains unchanged; the separate
verbatim transcription reference incorporates the owner’s wording corrections and was accepted after two audio-review rounds on 2026-10-30. The original and intermediate rounds are preserved in `../transcribe/history/`. Do not use generated recognition output as ground truth.

Run `make evals STAGE=transcribe CASE=tng-nl01-vrije-dag-enterprise-corrected` for aligned
WER scoring, or `make evals-pipeline CASE=tng-nl01-vrije-dag-enterprise-corrected` for the
complete audio-to-log pipeline with resume and search checks. Full-pipeline
references accept personal or professional filing (the script declares both
personal and work categories) and preserve the narration, including “Dat was dus niet handig,” omitted
from the original polished example. Runtime date/time expectations follow the
pipeline's recording-name/current-date and audio-creation-time behavior, rather
than assuming the script's example date is the recording date.

English and German scripts stay outside active suites until their recordings and
reviewed verbatim references are supplied. Use only synthetic fixtures, never
personal recordings, and run inference sequentially with isolated config/data.

# TNG recording scripts

Three fictional personal logs aboard the Enterprise: one English, one Dutch and
one German. Each has roughly 1,200 words, intended for about ten minutes of relaxed
reading with natural pauses. Actual duration depends on the speaker. The owner
still needs to record the audio; the audio filenames in the scripts are intended
filenames, not existing recordings.

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

This folder is reference material, separate from the active evaluation suites.
Editing or recording these scripts does not add cases to the runner or verify
model quality. The active audio, input and expected-output files live under
`eval/{transcribe,cleanup,categorize,filename,enrich}`. Use `make evals-list` to
see those cases and the [evaluation workflow](../../README.md#fixture-evaluations)
to run them.

Before adding a recording to an active suite, pair it with reviewed expected
outputs. Use only synthetic fixtures, never personal recordings, and run model
checks sequentially with isolated config and data.

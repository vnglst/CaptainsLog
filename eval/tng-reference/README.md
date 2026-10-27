# TNG recording scripts

Three short, fictional recording scripts with a Star Trek theme: one English,
one Dutch and one German. Each takes roughly a minute to read aloud at a
comfortable pace. The owner still needs to record the audio; the audio filenames
in the scripts are intended filenames, not existing recordings.

| Script | Language | Topic |
|---|---|---|
| [Work week review](tng-01-work-week-review.md) | English | A migration fix, a progress presentation and code reviews |
| [Weekend en werkplanning](tng-nl01-weekend-werkplanning.md) | Dutch | Family weekend, a home voice assistant and the coming workweek |
| [Fehlersuche im LCARS-Cluster](tng-de01-lcars-cluster-debugging.md) | German | A configuration typo, a fix and follow-up work |

The scripts use everyday spoken language, with Star Trek names woven into a
fictional present-day setting. Each file pairs its narration with a cleaned-up
version, example metadata and an expected filename. The dates and times are fixed
reference values. Expected wording is a reference, not the only valid output;
review generated text for missing details, changed meaning and invented content.

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

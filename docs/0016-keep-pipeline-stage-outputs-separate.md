# Keep pipeline stage outputs separate

**Status**: Accepted

## Decision Outcome

Pipeline stages write to their own directories and never mutate earlier-stage output.

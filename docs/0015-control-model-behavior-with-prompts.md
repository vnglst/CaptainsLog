# Control model behavior with prompts

**Status**: Accepted

## Decision Outcome

Prompts control model behavior. Do not post-process LLM output with regex, replacements, or other transformations. Structure prompts with clear XML-style tags such as `<instructions>`, `<context>`, and `<transcript>`.

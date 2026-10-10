# ADR-026: Keep owner-controlled tasks and immutable architecture records

**Status**: Accepted
**Date**: 2026-10-10
**Supersedes**: [ADR-020](0020-keep-documentation-in-adrs-and-self-contained-backlog-tasks.md)

## Context

ADR-020 permits agent-authored findings in tasks and does not fully state record immutability.

## Decision

Keep docs exclusively for numbered ADRs and backlog tasks self-contained, managed through the Backlog.md CLI. Task content and creation remain owner-controlled; agents report findings in chat or PRs. Existing ADRs are immutable, including dates and statuses. Changes require a new numbered record linking to the superseded ADR. New ADR content remains owner-supplied unless the owner explicitly grants an exception. Keep current commands in README and existing script/skill instructions.

## Consequences

Original decisions remain readable as history. New ADRs stay within 300 words, or 500 for essential rationale. This batch uses the owner’s one-time writing exception; it does not change the standing ownership rule.

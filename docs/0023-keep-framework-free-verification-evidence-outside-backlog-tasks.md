# ADR-023: Keep framework-free verification evidence outside backlog tasks

**Status**: Accepted
**Date**: 2026-10-10
**Supersedes**: [ADR-007](0007-framework-free-test-coverage.md)

## Context

ADR-007 names retired script commands and permits agent-authored verification results in tasks.

## Decision

Retain the framework-free run-tests executable, LLVM coverage and the 80% deterministic-logic coverage floor. Use Make as the command entry point. Run model evaluations sequentially with isolated configuration and repository fixtures; review semantic output separately. Report dated evidence and limitations in chat or PRs. Backlog content remains owner-supplied.

## Consequences

Coverage and structural passes do not establish model quality. Current commands and integration boundaries live in the [README](../README.md#testing).

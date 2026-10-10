# ADR-025: Reserve synthetic demo data for presentation

**Status**: Accepted
**Date**: 2026-10-10
**Supersedes**: [ADR-013](0013-isolated-tng-demo-data.md)

## Context

ADR-013 describes demonstration material as testing data, which conflicts with fixture isolation rules.

## Decision

Retain the isolated, persistent TNG demo copy, the term “Logs” and third-party notices. Use demo material for demonstrations and videos. Tests, evaluations and reproductions use repository eval fixtures with isolated configuration and data, bypassing demo seeding. Never use personal recordings or notes.

## Consequences

Presentation content does not become an evaluation input. Current demo launch instructions live in the [README](../README.md#build).

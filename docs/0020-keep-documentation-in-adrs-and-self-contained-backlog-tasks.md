# ADR-020: Keep Documentation in ADRs and Self-Contained Backlog Tasks

**Status**: Accepted
**Date**: 2026-10-08

## Context

Separate plans, operating guides and evaluation histories duplicated backlog scope and left tasks dependent on files the owner could not read in the Backlog app. Aggressive task shortening removed the explanation of what work meant.

## Decision

Keep `docs/` exclusively for numbered architecture decision records. Keep task records in the existing Backlog.md backlog, using its CLI for changes. Do not create separate plan, report or workflow documents under `docs/`.

Tasks explain the problem, intended change, acceptance checks, relevant findings and limits in complete sentences without links to other files or file-reference fields. Use the space clarity requires. Record dated implementation and evaluation results in the relevant task, explicitly distinguishing historical evidence from fresh verification. Preserve owner-controlled statuses and task creation.

ADRs preserve durable decisions, rationale and consequences. Keep them focused, generally within 300 words and at most 500 when essential rationale needs more room. Preserve historical decision dates and statuses; create a superseding record when a decision changes.

Root usage instructions and existing script/skill documentation may describe their commands. Synthetic data belongs under evaluation/demo directories, including the retained inactive TNG reference corpus; it is not architecture documentation or an automatically active quality gate.

## Consequences

The owner can understand tasks in one application. Document migration requires updating inbound links and retaining meaningful scope and limits, rather than moving every old session log verbatim. Runtime behavior, active fixtures and existing decisions remain unchanged.

# ADR-024: Separate release publication from development checks

**Status**: Accepted
**Date**: 2026-10-10
**Supersedes**: [ADR-010](0010-tag-driven-homebrew-releases.md)

## Context

ADR-010 describes automatic build, test and model checks that release preparation and publication no longer run.

## Decision

Retain tag-driven publication, matching VERSION and dated changelog validation, default-branch membership, archive checksums and synchronized casks using the scoped tap token. Prepare releases through Make using Conventional Commit version inference and atomic commit/tag publication. Preparation runs Git, version and changelog checks only. Tag CI builds release products, verifies packaging and publishes. Development tests and model evaluations run explicitly before release when relevant.

## Consequences

Release preparation remains lightweight. A successful publication does not prove test or semantic evaluation success. Current checks and commands live in the [release procedure](../README.md#changelog-and-releases).

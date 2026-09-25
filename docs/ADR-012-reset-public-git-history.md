# ADR-012: Publish With a Fresh Git History and Retain a Backup

**Status**: Accepted  
**Date**: 2026-09-25

## Context

Before publishing the project publicly, the project owner wanted to review the repository and avoid exposing its accumulated development history. They chose to replace the repository history with a single initial commit while retaining a local backup.

## Decision

Delete the repository’s `.git` metadata, create a new initial commit from the reviewed working tree, and force-push that history to the existing GitHub repository. Keep the prior repository backup in the sibling `CaptainsLogBackup` folder.

## Consequences

- The public repository presents a fresh history beginning with the new initial commit.
- Existing commit identifiers and branch history are no longer available from the remote.
- The backup preserves the prior history for local reference or recovery.
- Rewriting a public repository’s history can invalidate existing clones and references.

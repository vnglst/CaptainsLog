# ADR-013: Use Isolated Synthetic Data for the TNG Demo

**Status**: Accepted  
**Date**: 2026-09-25

## Context

The app needs realistic content for testing and recording videos without reading or changing a user's personal notes. The project owner chose a Star Trek: The Next Generation theme for this demonstration and preferred the in-app term “Logs” over “Field notes.”

## Decision

In development mode, seed a writable demo copy under `tmp/demo-runtime/` from synthetic notes and locally synthesized audio in `demo/`. Keep that data isolated from the user's configured notes folder. Use “Logs” for the journal concept in the app and demo materials. Include appropriate third-party notices and make clear that the project is unofficial and unaffiliated.

## Consequences

- Testing and video recording can use coherent, realistic content without relying on personal data.
- Demo writes stay in the repository-local runtime directory.
- The TNG theme is a fan-created presentation choice and must retain the project's notices.
- The demo copy persists between launches until it is reset or moved aside.

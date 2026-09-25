# PLAN-004: Logs interface status

## Current state

The app uses the Logs workspace in `Sources/CaptainsLogApp`. The interface includes the entry timeline, selected-entry detail, search, recording dock and input selection, processing/recovery actions, onboarding, and Settings. Internal Swift type names may still contain historical `FieldNotes` names.

The debug app launch supports deterministic TNG demo data through `CAPTAINSLOG_UI_FIXTURE`; see `Sources/CaptainsLog/DesignFixtures.swift`. These fixtures are useful for repeatable visual work without touching a user's configured data folder.

## Remaining work

- Audio playback and seek controls for saved recordings.
- Collections or projects navigation after their data model and empty states are defined.
- Complete the native visual and interaction acceptance pass, including clean onboarding, keyboard and VoiceOver behavior, reduced motion, and layout stability.
- Run the final packaged-app smoke checks on a clean macOS account or machine.

## Design references

The references in [`design/logs/DESIGN-SYSTEM.md`](../design/logs/DESIGN-SYSTEM.md) are conceptual, not current screenshots. Some images contain illustrative paths, entry counts, device names, and version text. They should not be treated as live product state or published as current screenshots without review.

The design iteration loop remains useful for future visual changes: exercise a deterministic fixture, build and launch the native app, try the interactions, capture the state, inspect it against the design system, then run the relevant automated checks. Keep fixtures isolated from real user data.

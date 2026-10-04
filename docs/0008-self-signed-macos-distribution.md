# ADR-008: Distribute macOS Builds Without Developer ID Notarization

**Status**: Accepted  
**Date**: 2026-09-25

## Context

CaptainsLog is distributed outside the Mac App Store. A Developer ID certificate and notarization would require a paid Apple developer membership, which the project owner has chosen not to purchase. macOS Gatekeeper can warn about or block an unnotarized download carrying quarantine metadata.

## Decision

Build the app with ad-hoc signing and distribute it without notarization. The Homebrew cask removes quarantine metadata from the installed app bundle so that first launch does not show the Gatekeeper prompt. Document the signing and trust implications alongside installation instructions.

## Consequences

- Users can install through Homebrew without paying for an Apple Developer ID.
- Users must trust the project and its release artifacts; macOS does not verify a Developer ID signature or notarization ticket.
- The cask’s quarantine removal is an intentional part of the install flow.
- A future decision to obtain Developer ID signing would require revisiting this distribution path.

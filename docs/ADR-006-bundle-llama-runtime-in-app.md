# ADR-006: Bundle llama.cpp Runtime Libraries in the App

**Status**: Accepted  
**Date**: 2026-06-12

## Context

The app must run on a user's Apple Silicon Mac without requiring Homebrew or a separate llama.cpp install.

After switching to `libllama`, the app binary links against llama.cpp, ggml, and libomp dylibs. If those paths point at `/opt/homebrew`, the app is not self-contained.

## Decision

`scripts/build-app.sh` copies the required runtime dylibs into `CaptainsLog.app/Contents/Frameworks` and rewrites install names to `@rpath`.

Bundled dylibs:

- `libllama.0.dylib`
- `libggml.0.dylib`
- `libggml-base.0.dylib`
- `libomp.dylib`

The script strips extended attributes and ad-hoc signs the bundle after `install_name_tool` rewrites.

## Consequences

- End users do not need Homebrew at runtime.
- App bundle size increases.
- Build machine still needs Homebrew llama.cpp for now.
- Current Homebrew HEAD dylibs warn about a newer deployment target than macOS 26.0; release builds should use project-built dylibs.

## Verification

- `scripts/build-app.sh`
- `otool -L` confirms llama/ggml/libomp resolve via `@rpath` inside the app bundle.
- `codesign --verify --deep --strict dist/CaptainsLog.app`

## Follow-up

Build llama.cpp/ggml/libomp for CaptainsLog with `MACOSX_DEPLOYMENT_TARGET=26.0` and fail packaging if `/opt/homebrew` llama paths remain in the bundle.

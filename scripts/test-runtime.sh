#!/bin/bash
# Verify clean extraction reproducibility of the declared prebuilt runtime input.
set -euo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
URL="$(sed -n 's/.*url: "\(https:.*xcframework.zip\)".*/\1/p' Package.swift)"
SHA="$(sed -n 's/.*checksum: "\([a-f0-9]*\)".*/\1/p' Package.swift)"
test -n "$URL"
test "${#SHA}" -eq 64
if grep -Eq 'pkgConfig:.*"(llama|ggml)"|\.brew.*(llama\.cpp|ggml|libomp)|/opt/homebrew|/usr/local' Package.swift; then
    echo 'System-installed native runtime fallback detected in Package.swift.' >&2
    exit 1
fi
for run in first second; do
    curl --fail --location --silent --show-error "$URL" -o "$TMP/$run.zip"
    echo "$SHA  $TMP/$run.zip" | shasum -a 256 -c -
    mkdir "$TMP/$run"
    ditto -x -k "$TMP/$run.zip" "$TMP/$run"
    framework="$TMP/$run/build-apple/llama.xcframework/macos-arm64_x86_64/llama.framework"
    test -f "$framework/Headers/llama.h"
    test -f "$framework/Headers/ggml.h"
    lipo -verify_arch arm64 "$framework/llama"
    codesign --remove-signature "$framework/llama" 2>/dev/null || true
done
# Includes matching public headers and unsigned universal native code; excludes dSYMs.
diff -rq "$TMP/first/build-apple/llama.xcframework/macos-arm64_x86_64/llama.framework/Versions/A" \
    "$TMP/second/build-apple/llama.xcframework/macos-arm64_x86_64/llama.framework/Versions/A"
printf 'Two independent verified extractions produce identical unsigned native artifacts.\n'
